"""Generate the love-story background music loops (algorithmic, no samples).

Each chapter gets a short seamless loop: soft pad chords + music-box melody
+ light bass, in a key/tempo matching the chapter mood. Output is mono OGG
(~48 kbps) under hongyuan/assets/bgm/. Rerun after changing MOODS:
    python3 godot/hongyuan/tools/make_bgm.py
"""
from pathlib import Path
import subprocess
import tempfile
import wave
import numpy as np

SR = 32000
OUT = Path(__file__).resolve().parents[1] / 'assets/bgm'
rng = np.random.default_rng(7)

# chord = semitone offsets of root from key; melody picks from pentatonic
MOODS = {
    'prologue': dict(key=62, bpm=66, prog=[0, 7, 9, 5], bright=0.35, notes_per_bar=3),
    'shanghai': dict(key=64, bpm=104, prog=[0, 9, 5, 7], bright=0.6, notes_per_bar=8),
    'chengdu':  dict(key=67, bpm=96, prog=[0, 5, 9, 7], bright=0.7, notes_per_bar=6),
    'call':     dict(key=60, bpm=72, prog=[9, 5, 0, 7], bright=0.4, notes_per_bar=4),
    'shizuoka': dict(key=65, bpm=70, prog=[0, 4, 9, 5], bright=0.45, notes_per_bar=4),
    'hainan':   dict(key=69, bpm=100, prog=[0, 7, 9, 5], bright=0.65, notes_per_bar=6),
    'hongkong': dict(key=63, bpm=88, prog=[5, 7, 0, 9], bright=0.5, notes_per_bar=5),
    'finale':   dict(key=62, bpm=76, prog=[0, 5, 7, 0, 9, 5, 7, 7], bright=0.5, notes_per_bar=4),
}
PENTA = [0, 2, 4, 7, 9, 12, 14, 16]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env(n, a, r):
    e = np.ones(n)
    a, r = min(a, n), min(r, n)
    e[:a] = np.linspace(0, 1, a)
    e[n - r:] *= np.linspace(1, 0, r)
    return e


def tone(f, n, kind):
    t = np.arange(n) / SR
    if kind == 'pad':
        s = sum(np.sin(2 * np.pi * f * d * t) for d in (0.997, 1.0, 1.003)) / 3
        s += 0.25 * np.sin(2 * np.pi * 2 * f * t)
        return s * env(n, int(0.4 * SR), int(0.6 * SR))
    if kind == 'bell':
        s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2.01 * f * t) + 0.12 * np.sin(2 * np.pi * 3.98 * f * t)
        return s * np.exp(-t * 3.2) * env(n, 60, int(0.05 * SR))
    s = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * 2 * f * t)
    return s * np.exp(-t * 1.6) * env(n, 200, int(0.1 * SR))


def render(m):
    beat = 60.0 / m['bpm']
    bar = int(4 * beat * SR)
    prog = m['prog'] * (2 if len(m['prog']) == 4 else 1)
    total = bar * len(prog)
    out = np.zeros(total + SR * 3)
    last = 2
    for i, c in enumerate(prog):
        root = m['key'] + c
        third = 3 if c in (9, 2, 4) else 4
        start = i * bar
        for iv in (0, third, 7):
            out[start:start + bar + SR] += 0.10 * tone(hz(root - 12 + iv), bar + SR, 'pad')
        out[start:start + bar] += 0.16 * tone(hz(root - 24), bar, 'bass')
        h = bar - bar // 2
        out[start + bar // 2:start + bar] += 0.10 * tone(hz(root - 24 + 7), h, "bass")
        step = bar // m['notes_per_bar']
        for k in range(m['notes_per_bar']):
            if rng.random() < 0.18 and k:
                continue
            last = int(np.clip(last + rng.choice([-2, -1, -1, 0, 1, 1, 2]), 0, len(PENTA) - 1))
            note = m['key'] + 12 + PENTA[last] + (c if c in (0, 5, 7) and k == 0 else 0)
            n = min(int(SR * 1.2), total + SR * 3 - (start + k * step))
            out[start + k * step:start + k * step + n] += (0.10 + 0.08 * m['bright']) * tone(hz(note), n, 'bell')
    # wrap the tail into the head so the loop is seamless
    out[:SR * 3] += out[total:total + SR * 3]
    out = out[:total]
    # gentle low-pass + normalize
    k = np.ones(3) / 3
    out = np.convolve(out, k, mode='same')
    out = out / (np.abs(out).max() + 1e-9) * 0.7
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, m in MOODS.items():
            pcm = (render(m) * 32767).astype(np.int16)
            wav = Path(tmp) / (name + '.wav')
            with wave.open(str(wav), 'wb') as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(SR)
                w.writeframes(pcm.tobytes())
            dst = OUT / ('bgm_%s.ogg' % name)
            subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(wav), '-c:a', 'libvorbis', '-q:a', '1', str(dst)], check=True)
            print(dst.name, len(pcm) / SR, 's', dst.stat().st_size // 1024, 'KB')


if __name__ == '__main__':
    main()
