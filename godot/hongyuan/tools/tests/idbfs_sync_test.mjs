// node --test godot/hongyuan/tools/tests/idbfs_sync_test.mjs
// Exercises the actual export replacement in a vm, without a browser database.
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdtempSync, linkSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import test from 'node:test';
import vm from 'node:vm';

const tools = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const original = readFileSync(new URL('./fixtures/godot_4_7_2_idbfs.js', import.meta.url), 'utf8');
function patch(input) {
  return spawnSync('python3', ['-c',
    'import sys;sys.path.insert(0,sys.argv[1]);from patch_web_idbfs import patch_source;sys.stdout.write(patch_source(sys.stdin.read()))',
    tools], {input, encoding: 'utf8'});
}
const patched = patch(original);
assert.equal(patched.status, 0, patched.stderr);

function runtime(overrides = {}) {
  const logs = [], errors = [], calls = [], queued = [];
  let active = 0, maximum = 0, revision = 1, persisted = 0;
  const FS = {
    syncfs(populate, callback) {
      active++;
      maximum = Math.max(maximum, active);
      calls.push({populate, revision});
      queued.push({callback, revision});
    },
    stat() {return {mode: 0o100644, mtime: new Date(0)};},
    lookupPath() {return {node: {contents: new Uint8Array([1, 2, 3])}};},
    isDir: mode => (mode & 0o170000) === 0o040000,
    isFile: mode => (mode & 0o170000) === 0o100000,
    mount() {}, mkdirTree() {}, unmount() {},
    ...overrides,
  };
  const context = {
    FS, MEMFS: {getFileDataAsTypedArray: node => node.contents},
    GodotRuntime: {print: value => logs.push(value), error: value => errors.push(value)},
  };
  vm.runInNewContext(patched.stdout, context, {filename: 'patched-godot-idbfs.js'});
  return {
    ...context, logs, errors, calls, queued,
    mutate(value) {revision = value;},
    get persisted() {return persisted;},
    get maximum() {return maximum;},
    finish(error = null) {
      const job = queued.shift();
      assert.ok(job, 'a real sync pass must be pending');
      active--;
      if (!error) persisted = job.revision;
      job.callback(error);
      return job.callback;
    },
  };
}
const turn = () => Promise.resolve();
const entries = r => r.errors.filter(s => s.startsWith('HONGYUAN_IDBFS_ENTRY '))
  .map(s => JSON.parse(s.slice('HONGYUAN_IDBFS_ENTRY '.length)));

test('one request starts one pass and resolves only after the callback', async () => {
  const r = runtime();
  let settled = false;
  const pending = r.GodotFS.sync();
  pending.then(() => {settled = true;});
  assert.equal(r.calls.length, 1);
  await turn();
  assert.equal(settled, false);
  r.finish();
  assert.equal(await pending, null);
  assert.equal(r.GodotFS._syncing, false);
  assert.equal(r.GodotFS._sync_promise, null);
  const records = r.logs.map(s => JSON.parse(s.slice('HONGYUAN_IDBFS_SYNC '.length)));
  assert.deepEqual(records.map(v => [v.phase, v.sequence]), [['start', 1], ['end', 1]]);
  assert.ok(records[1].elapsed_ms >= 0);
});

test('busy requests coalesce, share one completion promise and persist newer changes', async () => {
  const r = runtime();
  const first = r.GodotFS.sync();
  r.mutate(2);
  assert.equal(r.GodotFS.sync(), first);
  assert.equal(r.GodotFS.sync(), first);
  assert.equal(r.calls.length, 1);
  r.finish();
  assert.equal(r.persisted, 1);
  await turn();
  assert.equal(r.calls.length, 2);
  assert.equal(r.GodotFS._syncing, true);
  r.finish();
  assert.equal(await first, null);
  assert.equal(r.persisted, 2);
  assert.equal(r.maximum, 1);
});

test('a change during the second pass queues a third without overlapping transactions', async () => {
  const r = runtime();
  const pending = r.GodotFS.sync();
  r.mutate(2); r.GodotFS.sync(); r.finish();
  await turn();
  r.mutate(3); r.GodotFS.sync(); r.finish();
  await turn();
  assert.equal(r.calls.length, 3);
  r.finish(); await pending;
  assert.equal(r.persisted, 3);
  assert.equal(r.maximum, 1);
});

test('ErrnoError without message is logged fully and not silently retried', async () => {
  const r = runtime();
  const error = {name: 'ErrnoError', errno: 44, toString: () => 'ErrnoError errno=44'};
  const pending = r.GodotFS.sync();
  r.finish(error);
  assert.equal(await pending, error);
  assert.equal(r.calls.length, 1);
  assert.equal(r.GodotFS._syncing, false);
  const details = JSON.parse(r.errors[0].slice('Failed to save IDB file system: '.length));
  assert.equal(details.name, 'ErrnoError');
  assert.equal(details.errno, 44);
  assert.equal(details.message, null);
  assert.equal(details.string, 'ErrnoError errno=44');
  const retry = r.GodotFS.sync(); r.finish();
  assert.equal(await retry, null);
  assert.equal(r.calls.length, 2);
});

test('a later dirty pass runs after failure but does not erase the first failure', async () => {
  const r = runtime();
  const error = new Error('transaction failed');
  const pending = r.GodotFS.sync();
  r.mutate(2); r.GodotFS.sync(); r.finish(error);
  await turn();
  r.finish();
  assert.equal(await pending, error);
  assert.equal(r.persisted, 2);
  assert.equal(r.maximum, 1);
});

test('synchronous callback does not leave a stale promise or busy flag', async () => {
  const r = runtime({syncfs(_populate, callback) {callback(null);}});
  assert.equal(await r.GodotFS.sync(), null);
  assert.equal(r.GodotFS._sync_promise, null);
  assert.equal(r.GodotFS._syncing, false);
  assert.equal(await r.GodotFS.sync(), null);
  assert.equal(r.GodotFS._sync_sequence, 2);
});

test('synchronous exception is reported and leaves the coordinator reusable', async () => {
  const error = new Error('storage unavailable');
  const r = runtime({syncfs() {throw error;}});
  assert.equal(await r.GodotFS.sync(), error);
  assert.equal(r.GodotFS._syncing, false);
  r.FS.syncfs = (_populate, callback) => callback(null);
  assert.equal(await r.GodotFS.sync(), null);
});

test('reentrant dirty calls with synchronous callbacks never recurse into FS', async () => {
  let fs, depth = 0, maximum = 0, count = 0;
  const r = runtime({syncfs(_populate, callback) {
    depth++; maximum = Math.max(maximum, depth); count++;
    if (count < 4) fs.sync();
    callback(null); depth--;
  }});
  fs = r.GodotFS;
  assert.equal(await fs.sync(), null);
  assert.equal(count, 4);
  assert.equal(maximum, 1);
});

test('duplicate callbacks cannot resolve a batch before its queued pass finishes', async () => {
  const r = runtime();
  const pending = r.GodotFS.sync();
  r.GodotFS.sync();
  const callback = r.finish();
  callback(null);
  await turn();
  assert.equal(r.calls.length, 2);
  assert.equal(r.GodotFS._syncing, true);
  r.finish(); await pending;
});

test('event and hostile error details remain serializable without message assumptions', () => {
  const r = runtime();
  const event = {target: {error: {name: 'QuotaExceededError', message: 'disk quota'}}};
  const details = r.GodotFS._hy_error_details(event);
  assert.equal(details.target_name, 'QuotaExceededError');
  assert.equal(details.target_message, 'disk quota');
  const hostile = {get target() {throw new Error('getter');}, toString() {throw new Error('string');}};
  assert.equal(r.GodotFS._hy_error_details(hostile).target_name, '[unreadable]');
  assert.equal(r.GodotFS._hy_error_details(hostile).string, '[unprintable error]');
});

test('missing local entry reports path and errno without reading or logging file contents', () => {
  const error = {name: 'ErrnoError', errno: 44};
  const r = runtime({lookupPath() {throw error;}});
  let received;
  r.IDBFS.loadLocalEntry('/userfs/hongyuan_save.json.tmp', e => {received = e;});
  assert.equal(received, error);
  assert.deepEqual(entries(r)[0], {operation: 'loadLocalEntry', path: '/userfs/hongyuan_save.json.tmp',
    bytes: null, error: {name: 'ErrnoError', message: null, errno: 44, string: '[object Object]',
      target_name: null, target_message: null}});
});

test('remote put synchronous and asynchronous failures report length but not contents', () => {
  const r = runtime(), error = new Error('quota');
  const content = new TextEncoder().encode('PRIVATE CONTENT MUST NOT BE LOGGED');
  let received;
  r.IDBFS.storeRemoteEntry({put() {throw error;}}, '/userfs/cache.pck', {contents: content}, e => {received = e;});
  assert.equal(received, error);
  assert.equal(entries(r)[0].bytes, content.byteLength);
  const request = {};
  let prevented = false;
  r.IDBFS.storeRemoteEntry({put() {return request;}}, '/userfs/cache.pck', {contents: content}, e => {received = e;});
  request.onerror({target: {error}, preventDefault() {prevented = true;}});
  assert.equal(received, error);
  assert.equal(prevented, true);
  assert.equal(entries(r).length, 2);
  assert.equal(r.errors.join('\n').includes('PRIVATE CONTENT'), false);
});

test('successful local load and remote put preserve callbacks and payload', () => {
  const r = runtime();
  let loaded, sent = false;
  r.IDBFS.loadLocalEntry('/userfs/cache.pck', (error, entry) => {assert.equal(error, null); loaded = entry;});
  assert.deepEqual(Array.from(loaded.contents), [1, 2, 3]);
  const request = {};
  r.IDBFS.storeRemoteEntry({put(entry, path) {
    assert.equal(entry, loaded); assert.equal(path, '/userfs/cache.pck'); return request;
  }}, '/userfs/cache.pck', loaded, error => {assert.equal(error, undefined); sent = true;});
  request.onsuccess({});
  assert.equal(sent, true);
  assert.equal(r.errors.length, 0);
});

test('initial unavailable IndexedDB reports errno too and keeps nonpersistent behavior', async () => {
  const r = runtime(), error = {name: 'ErrnoError', errno: 28};
  const pending = r.GodotFS.init(['/userfs']);
  assert.equal(r.calls[0].populate, true);
  r.finish(error);
  assert.equal(await pending, error);
  assert.equal(r.GodotFS.is_persistent(), 0);
  assert.ok(r.logs[0].includes('"errno":28'));
});

test('unsupported engine, changed IDBFS functions, duplicate or repeated patch fail closed', () => {
  for (const source of [original.replace('ENOENT:44', 'ENOENT:45'),
    original.replace('var lookup=FS.lookupPath(path)', 'var lookup=FS.lookupPath(path,true)'),
    original + original, patched.stdout]) {
    const result = patch(source);
    assert.notEqual(result.status, 0);
    assert.equal(result.stdout, '');
  }
});

test('file patch replaces only its directory entry and dry-run does not change bytes', () => {
  const dir = mkdtempSync(join(tmpdir(), 'hongyuan-idbfs-test-'));
  try {
    const current = join(dir, 'index.js'), immutable = join(dir, 'immutable.js');
    writeFileSync(current, original); linkSync(current, immutable);
    const dry = spawnSync('python3', [join(tools, 'patch_web_idbfs.py'), current, '--dry-run'], {encoding: 'utf8'});
    assert.equal(dry.status, 0, dry.stderr);
    assert.equal(readFileSync(current, 'utf8'), original);
    const applied = spawnSync('python3', [join(tools, 'patch_web_idbfs.py'), current], {encoding: 'utf8'});
    assert.equal(applied.status, 0, applied.stderr);
    assert.equal(readFileSync(current, 'utf8'), patched.stdout);
    assert.equal(readFileSync(immutable, 'utf8'), original);
    assert.equal(JSON.parse(applied.stdout).patch, 'hongyuan-idbfs-serial-dirty-v1');
  } finally {rmSync(dir, {recursive: true, force: true});}
});
