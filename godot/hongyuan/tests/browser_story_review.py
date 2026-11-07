"""Normal-entry love-story playthrough using only browser input.

Checkpoint reads select gestures; this script never writes saves, calls Godot
methods, changes clocks, presses a skip button or enters a developer checkpoint.
Run with the existing Playwright venv. A fresh evidence/profile directory is
required, so reruns cannot quietly reuse a completed story.
"""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re
import time

ROOT = Path(__file__).resolve().parent
DEFAULT_REPO = ROOT.parents[2]
SUPPORTED = {'desk_intro', 'group_chat', 'drive', 'pandas', 'call', 'desk_chat',
             'care', 'balance', 'fishing', 'onsen', 'registration', 'ringtoss',
             'offer', 'photo', 'finale', 'seat'}
PANDA_FEET = [(62, 350), (180, 350), (298, 350), (62, 452), (180, 452), (298, 452)]


def load_story(repo):
    base = repo / 'godot/hongyuan'
    order = json.loads((base / 'chapter_order.json').read_text())['chapters']
    steps, originals = {}, {}
    for chapter in order:
        path = base / f'chapters/{chapter}.json'
        raw = path.read_text()
        originals[chapter] = {'sha256': hashlib.sha256(raw.encode()).hexdigest(), 'document': json.loads(raw)}
        for step in originals[chapter]['document']['steps']:
            steps[f'{chapter}/{step["id"]}'] = step
    copy = json.loads((base / 'copy.json').read_text())
    return steps, originals, copy


def scene_at(step, beat):
    scene = dict(step.get('scene', {}))
    beats = scene.get('beats', [])
    for update in beats[:beat + 1]:
        scene.update(update)
    return scene, beats[beat] if 0 <= beat < len(beats) else {}


def validate_source(steps):
    games = Counter()
    for step_id, step in steps.items():
        for index, beat in enumerate(step.get('scene', {}).get('beats', [])):
            if 'game' in beat:
                games[beat['game']] += 1
                if beat['game'] not in SUPPORTED:
                    raise RuntimeError(f'Unhandled game {step_id}:{index}: {beat["game"]}')
            if 'go' in beat:
                scene, _ = scene_at(step, index)
                if not any(h['id'] == beat['go'] for h in scene.get('hotspots', [])):
                    raise RuntimeError(f'Missing hotspot {step_id}:{index}: {beat["go"]}')
    return games


class Review:
    def __init__(self, page, context, out, steps, copy, destination, deadline, stall_seconds):
        self.page, self.context, self.out = page, context, out
        self.steps, self.copy, self.destination = steps, copy, destination
        self.started = time.monotonic()
        self.deadline, self.stall_seconds = deadline, stall_seconds
        self.events = (out / 'events.jsonl').open('x', encoding='utf-8', buffering=1)
        self.tags, self.visited, self.game_visits = set(), set(), set()
        self.errors, self.requests = [], []
        self.last_progress, self.progress_at = None, time.monotonic()
        self.next_action = 0.0
        self.last_chapter = None
        self.held = False
        self.world_selected = False
        self.world_ready = None
        self.world_routes = []
        self.village_requested = False
        self.return_requested = False
        self.refresh_requested = False
        self.balance_start = None
        self.balance_end = None
        self.status = 'running'
        self.screenshot_count = 0
        self.last_save = {}
        page.on('console', self.console)
        page.on('pageerror', lambda error: self.log('pageerror', str(error), error=True))
        page.on('request', self.request)
        page.on('requestfailed', lambda req: self.log('requestfailed', {'url': req.url, 'failure': req.failure}, error=True))

    def log(self, kind, value, error=False):
        event = {'seconds': round(time.monotonic() - self.started, 3), 'kind': kind, 'value': value}
        self.events.write(json.dumps(event, ensure_ascii=False) + '\n')
        if error:
            self.errors.append(event)
            print('REVIEW_ERROR', kind, str(value)[:350], flush=True)

    def console(self, message):
        text = message.text
        if message.type in ('error', 'warning') or any(s in text for s in ('CONTENT_', 'IDBFS', 'WORLD_READY')):
            self.log('console_' + message.type, text,
                     error=message.type == 'error' or 'Failed to save IDB' in text or 'SCRIPT ERROR' in text)
        if text.startswith('WORLD_READY '):
            self.world_ready = text
            self.world_routes.append(text)

    def request(self, request):
        if '/content/' in request.url:
            self.requests.append(request.url)
            self.log('content_request', request.url)

    def read_save(self):
        # Read-only observation. Do not replace this with a test save or game API.
        return self.page.evaluate("JSON.parse(localStorage.getItem('hongyuan_save.json') || '{}')")

    def storage(self, label):
        result = self.page.evaluate("""async () => {
            try {return {estimate: await navigator.storage?.estimate(),
                         persisted: await navigator.storage?.persisted()};}
            catch (error) {return {error: String(error), name: error.name};}
        }""")
        self.log('storage_estimate', {'at': label, 'value': result})

    @staticmethod
    def point(x, y):
        scale = 390 / 360
        return x * scale, y * scale + (844 - 640 * scale) / 2

    def tap(self, x, y, cooldown=0.65):
        self.release()
        self.log('input_tap', [round(x, 2), round(y, 2)])
        self.page.touchscreen.tap(*self.point(x, y))
        self.next_action = time.monotonic() + cooldown

    def hold(self, x, y):
        if self.held:
            return
        self.page.mouse.move(*self.point(x, y))
        self.page.mouse.down()
        self.held = True
        self.log('input_hold_start', [x, y])

    def release(self):
        if self.held:
            self.page.mouse.up()
            self.held = False
            self.log('input_hold_end', None)

    def hold_for(self, x, y, milliseconds):
        self.hold(x, y)
        self.page.wait_for_timeout(milliseconds)
        self.release()
        self.next_action = time.monotonic() + 0.3

    def drag(self, start, end, milliseconds=450):
        self.release()
        self.log('input_drag', {'from': start, 'to': end, 'milliseconds': milliseconds})
        self.page.mouse.move(*self.point(*start))
        self.page.mouse.down()
        for i in range(1, 13):
            point = [start[j] + (end[j] - start[j]) * i / 12 for j in (0, 1)]
            self.page.mouse.move(*self.point(*point))
            self.page.wait_for_timeout(milliseconds / 12)
        self.page.mouse.up()
        self.next_action = time.monotonic() + 0.35

    def shot(self, tag, state):
        if tag in self.tags:
            return
        self.tags.add(tag)
        self.screenshot_count += 1
        slug = re.sub(r'[^a-zA-Z0-9_.-]+', '_', tag)
        name = f'{self.screenshot_count:03d}_{slug}'
        self.page.screenshot(path=str(self.out / (name + '.png')), timeout=60000)
        (self.out / (name + '.json')).write_text(json.dumps(state, ensure_ascii=False, indent=2))
        self.log('screenshot', {'tag': tag, 'file': name + '.png'})
        print('REVIEW_PHASE', tag, f'{time.monotonic() - self.started:.1f}s', flush=True)

    def text_for(self, beat, game):
        if 'lines' in beat:
            lines = beat['lines']
            index = int(game.get('li', 0))
            return self.copy.get(str(lines[index].get('say', '')), '') if index < len(lines) else ''
        return self.copy.get(str(beat.get('say', beat.get('narrate', ''))), '')

    def game_action(self, step_id, beat_index, name, beat, snap, g):
        phase = g.get('phase', 'intro')
        t = float(g.get('t', 0))
        if name == 'desk_intro':
            if t > 0.8: self.tap(180, 585)
        elif name in ('group_chat', 'desk_chat'):
            text = self.text_for(beat, g)
            if t > 1.0 and g.get('reveal', 0) >= len(text): self.tap(180, 585)
        elif name == 'drive':
            if phase == 'ready': self.tap(180, 582)
            elif phase == 'drive':
                lane = int(g.get('lane', 1))
                occupied = {int(c['lane']) for c in g.get('traffic', []) if 340 < c['y'] < 540}
                if lane in occupied:
                    choices = [j for j in (lane - 1, lane + 1) if 0 <= j <= 2 and j not in occupied]
                    if choices:
                        dx = 70 if choices[0] > lane else -70
                        self.drag((180, 500), (180 + dx, 500), 160)
            elif phase == 'park' and float(g.get('bay_y', -999)) > 220:
                self.hold(180, 500)
        elif name == 'pandas':
            if phase != 'active': return
            feet = snap.get('feet', [0, 0])
            if not g.get('bamboo_held'):
                if math.dist(feet, (216, 532)) <= 42: self.tap(216, 506)
                elif not snap.get('moving'): self.tap(180, 520, 0.9)
            else:
                hungry = int(g.get('hungry', -1))
                if hungry < 0: return
                target = PANDA_FEET[hungry]
                approach = (target[0] + (-32 if hungry % 3 == 2 else 32), target[1] + 38)
                if math.dist(feet, approach) <= 42:
                    self.tap(target[0] + (-40 if hungry % 3 == 2 else 40), target[1] - 26)
                elif not snap.get('moving'):
                    self.tap(target[0], target[1] - 25, 0.9)
        elif name == 'call':
            if phase == 'ring': self.tap(180, 400)
            elif phase == 'talk': self.hold(24, 200)
            elif phase == 'reply' and t > 0.9: self.tap(180, 585)
        elif name == 'care':
            if phase == 'care': self.drag((180, 562), (180, 390))
        elif name == 'balance':
            if self.balance_start is None:
                self.balance_start = time.monotonic()
                self.log('balance_real_time_start', {'game_t': t})
            if phase == 'active':
                levels = g.get('levels', [0, 0, 0])
                index = max(range(3), key=lambda i: levels[i])
                if max(levels) > 0.50 or int(g.get('touches', 0)) < 3:
                    self.tap(180, 373 + index * 74, 1.0)
        elif name == 'fishing':
            if phase == 'aim': self.hold_for(180, 580, 700)
            elif phase == 'bite': self.tap(180, 560, 0.2)
        elif name == 'onsen':
            if phase == 'join':
                # This game expands its 360x640 water scene to the full viewport.
                scale = (844 / (390 / 360)) / 640
                self.tap(180 + (176 - 180) * scale, 320 + (422 - 320) * scale)
            elif phase == 'talk' and t > 0.9 and g.get('reveal', 0) >= len(self.text_for(beat, g)):
                self.tap(180, 585)
        elif name == 'registration':
            if phase == 'stamp': self.hold_for(190, 229, 1250)
            elif phase == 'handover' and g.get('handed'): self.tap(180, 575)
            elif phase == 'photo' and t > 0.8: self.tap(180, 575)
            elif phase == 'memory' and t > 1.0: self.tap(180, 585)
        elif name == 'ringtoss':
            if phase == 'aim':
                pegs = beat.get('pegs', [[180, 300]])
                target = pegs[int(g.get('turn', 0)) % len(pegs)]
                self.tap(*target)
        elif name == 'offer':
            if phase == 'list':
                self.tap((464 + 257 / 2) * 360 / 841, -80 + (836 + 221 / 2) * 360 / 841)
            elif phase == 'letter':
                # A deliberate swipe reveals the bottom; the button is 10 px
                # above the document's bottom margin after maximal scroll.
                if not self.tags.intersection({step_id + '_offer_scrolled'}):
                    self.drag((180, 430), (180, 205), 700)
                    self.page.wait_for_timeout(350)
                    self.shot(step_id + '_offer_scrolled', self.read_save())
                self.tap(181, 440)
        elif name == 'photo':
            if phase == 'ready': self.tap(196, 438)
        elif name == 'finale':
            if phase == 'read' and t > 1.3: self.tap(180, 585)
            elif phase == 'name':
                if g.get('name') != 'FriendR5':
                    self.tap(180, 495)
                    self.page.keyboard.press('ControlOrMeta+A')
                    self.page.keyboard.type('FriendR5', delay=110)
                    self.log('input_keyboard', 'FriendR5')
                    self.next_action = time.monotonic() + 0.7
                else: self.tap(180, 584)
            elif phase in ('written', 'ready_send', 'read_received') and t > 0.7:
                self.tap(180, 584)
            elif phase == 'seal': self.hold_for(180, 337, 1250)
            elif phase == 'receive': self.drag((70, 280), (250, 280), 900)
            elif phase == 'look':
                if int(g.get('look', -1)) != 6: self.tap(217, 424)
                else: self.tap(180, 584)
            elif phase == 'welcome' and t > 1.5: self.tap(180, 584)
        elif name == 'seat':
            if phase == 'pick': self.tap(283, 391)
        else:
            raise RuntimeError(f'No normal-input action implemented for {name}')

    def run(self):
        self.storage('cold_start')
        while time.monotonic() < self.deadline:
            self.page.wait_for_timeout(220)
            state = self.read_save()
            self.last_save = state
            step_id = state.get('stepId', '')
            if not step_id:
                if time.monotonic() - self.started > 120: raise RuntimeError('No checkpoint after 120 seconds of cold loading')
                continue
            if self.world_selected:
                self.release()
                if self.world_ready:
                    self.page.wait_for_timeout(2000)
                    self.shot('destination_' + self.destination, state)
                    self.storage('destination_' + self.destination)
                    if self.destination == 'wedding' and not self.village_requested:
                        self.page.touchscreen.tap(342, 74)
                        self.page.wait_for_function("()=>JSON.parse(localStorage.getItem('hongyuan_save.json')||'{}').weddingLocation?.area==='banquet'",timeout=45000)
                        self.page.wait_for_timeout(1500)
                        self.shot('destination_banquet', self.read_save())
                        self.log('input_world_navigation', {'button': '去村子入住', 'viewport_point': [265, 74]})
                        self.world_ready = None
                        self.village_requested = True
                        self.destination = 'village'
                        self.page.touchscreen.tap(265, 74)
                        self.progress_at = time.monotonic()
                        continue
                    if self.destination == 'village' and not self.return_requested:
                        self.return_requested = True
                        self.world_ready = None
                        self.destination = 'wedding_return'
                        self.page.touchscreen.tap(338, 213)
                        self.page.wait_for_timeout(1000)
                        self.page.touchscreen.tap(330, 74)
                        self.progress_at = time.monotonic()
                        continue
                    if self.destination == 'wedding_return' and not self.refresh_requested:
                        self.refresh_requested = True
                        self.world_ready = None
                        self.destination = 'wedding_reload'
                        self.page.reload(wait_until='domcontentloaded',timeout=120000)
                        self.progress_at = time.monotonic()
                        continue
                    self.status = 'normal_story_both_destinations_roundtrip_and_reload' if self.refresh_requested else 'normal_story_and_destination_reached'
                    return
                if time.monotonic() - self.progress_at > 900: raise RuntimeError('Destination did not report WORLD_READY after 900 seconds')
                continue
            if step_id not in self.steps: raise RuntimeError('Unknown checkpoint step: ' + step_id)
            self.visited.add(step_id)
            chapter = step_id.split('/')[0]
            if chapter != self.last_chapter:
                self.storage(chapter)
                self.last_chapter = chapter
            step = self.steps[step_id]
            snap = state.get('sceneSnapshot', {})
            beat_index = int(snap.get('beat', state.get('sceneBeat', 0)))
            scene, beat = scene_at(step, beat_index)
            mode = snap.get('mode', step.get('type', ''))
            if not mode:
                if time.monotonic() - self.progress_at > self.stall_seconds: raise RuntimeError('Scene checkpoint remained uninitialized')
                continue
            g = snap.get('game', {})
            name = beat.get('game', '') if mode == 'game' else ''
            phase = str(g.get('phase', 'intro')) if name else ''
            tag = f'{step_id}_{beat_index:02d}_{mode}'
            if name:
                self.game_visits.add((step_id, beat_index, name))
                tag += '_' + name + '_' + phase
                for key in ('li', 'read_index', 'turn'):
                    if key in g: tag += f'_{key}{int(g[key])}'
                if name == 'pandas': tag += f'_fed{len(g.get("fed", []))}_held{int(bool(g.get("bamboo_held")))}'
                if name == 'care': tag += f'_cleared{len(g.get("cleared", []))}'
            if not (name == 'call' and phase == 'talk') and not (name == 'drive' and phase == 'park'):
                self.release()
            if self.balance_start is not None and self.balance_end is None and name != 'balance':
                self.balance_end = time.monotonic()
                self.log('balance_real_time_end', {'wall_seconds': self.balance_end - self.balance_start})
            progress = (tag, tuple(round(float(v), 1) for v in snap.get('feet', [])),
                        int(g.get('reveal', snap.get('reveal', 0))), int(g.get('typed', 0)),
                        int(g.get('scroll', 0)), g.get('name'), g.get('look'))
            if progress != self.last_progress:
                self.last_progress = progress
                self.progress_at = time.monotonic()
            self.shot(tag, state)
            text = self.text_for(beat, g)
            if text and g.get('reveal', snap.get('reveal', 0)) >= len(text): self.shot(tag + '_text_full', state)
            if time.monotonic() - self.progress_at > self.stall_seconds:
                raise RuntimeError(f'No gameplay progress for {self.stall_seconds}s at {tag}')
            if time.monotonic() < self.next_action: continue
            t = float(snap.get('t', 0))
            if mode in ('say', 'card'):
                if t > (0.9 if mode == 'card' else 1.0): self.tap(180, 585)
            elif mode == 'material':
                if t >= 2.3: self.tap(180, 585)
            elif mode == 'goal':
                if t > 1.2: self.tap(180, 514)
            elif mode == 'button': self.tap(180, 493)
            elif mode == 'go':
                if snap.get('moving'): continue
                hotspot = next((h for h in scene.get('hotspots', []) if h['id'] == beat.get('go')), None)
                if hotspot is None: raise RuntimeError(f'No hotspot config for {tag}')
                x, y = hotspot['at']
                # Upper-half drags operate the camera. A ground tap immediately
                # below y320 still falls within a near seat's real 40px hit zone.
                if 282 <= y < 321: y = 321
                if y < 282:
                    if 'iconAt' not in hotspot: raise RuntimeError(f'Hotspot needs a visible icon gesture: {tag}')
                    x, y = hotspot['iconAt']
                self.tap(x, y, 1.0)
            elif mode == 'game': self.game_action(step_id, beat_index, name, beat, snap, g)
            elif mode == 'choice':
                missing = [key for key, value in self.steps.items() if value['type'] != 'terminal' and key not in self.visited]
                if missing: raise RuntimeError('Reached choices without visiting: ' + ', '.join(missing))
                if snap.get('result', {}).get('name') != 'FriendR5': raise RuntimeError('Guest name did not survive finale')
                self.log('normal_story_complete', {'steps': len(self.visited), 'result': snap.get('result'), 'to': beat.get('to')})
                if self.destination == 'none':
                    self.status = 'normal_story_reached_both_choices'; return
                self.tap(180, 554 if self.destination == 'wedding' else 606)
                self.world_selected = True
                self.progress_at = time.monotonic()
            elif mode == 'terminal':
                self.status = 'normal_terminal_reached'; return
            elif mode in ('auto', 'wait', 'transition', 'narration', 'dialogue', 'phone', 'chat'):
                pass
            else: raise RuntimeError(f'Unhandled mode {mode} at {tag}')
        raise RuntimeError('Overall playthrough deadline exceeded')

    def finish(self, exception=None):
        self.release()
        if exception:
            self.status = 'blocked'
            self.log('blocked', str(exception), error=True)
            try: self.shot('BLOCKED', self.last_save)
            except Exception as screenshot_error: self.log('screenshot_error', str(screenshot_error))
        report = {'status': self.status, 'method': 'fresh isolated Chrome context; normal entry; real gestures only; read-only localStorage observations',
                  'viewport': [390, 844], 'wall_seconds': round(time.monotonic() - self.started, 2),
                  'visited_steps': sorted(self.visited), 'game_visits': sorted(self.game_visits),
                  'screenshots': self.screenshot_count, 'content_requests': self.requests,
                  'errors': self.errors, 'world_ready': self.world_ready, 'world_routes': self.world_routes,
                  'balance_wall_seconds': None if self.balance_end is None else round(self.balance_end - self.balance_start, 2),
                  'final_checkpoint': self.last_save}
        (self.out / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
        self.events.close()
        print('REVIEW_DONE', self.status, 'steps=', len(self.visited), 'screenshots=', self.screenshot_count,
              'errors=', len(self.errors), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url')
    parser.add_argument('--repo', type=Path, default=DEFAULT_REPO)
    parser.add_argument('--out', type=Path, default=Path.cwd() / 'browser-story-review')
    parser.add_argument('--destination', choices=['none', 'wedding', 'village'], default='wedding')
    parser.add_argument('--max-minutes', type=float, default=35)
    parser.add_argument('--stall-seconds', type=float, default=90)
    parser.add_argument('--validate-source', action='store_true')
    args = parser.parse_args()
    steps, originals, copy = load_story(args.repo)
    games = validate_source(steps)
    if args.validate_source:
        print(json.dumps({'steps': len(steps), 'games': games}, ensure_ascii=False)); return
    if not args.url: parser.error('--url is required to run; never invent a candidate URL')
    args.out.mkdir(parents=True, exist_ok=False)
    (args.out / 'source-chapters.json').write_text(json.dumps(originals, ensure_ascii=False, indent=2))
    (args.out / 'method.txt').write_text('No save writes, seeds, developer entry, skip controls, game method calls or time acceleration.\nASCII FriendR5 uses real key events; mobile Chinese IME is not tested by this run.\n')
    from playwright.sync_api import sync_playwright
    failure = None
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(channel='chrome', headless=True, timeout=90000,
            args=['--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
        context = browser.new_context(viewport={'width': 390, 'height': 844}, has_touch=True, is_mobile=True)
        page = context.new_page()
        page.set_default_timeout(60000)
        review = Review(page, context, args.out, steps, copy, args.destination,
                        time.monotonic() + args.max_minutes * 60, args.stall_seconds)
        try:
            page.goto(args.url, wait_until='domcontentloaded', timeout=120000)
            review.run()
        except Exception as error:
            failure = error
        finally:
            review.finish(failure)
            context.close()
            browser.close()
    raise SystemExit(1 if failure else 0)


if __name__ == '__main__': main()
