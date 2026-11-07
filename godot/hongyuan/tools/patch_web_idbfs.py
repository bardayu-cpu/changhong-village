"""Patch the verified Godot 4.7.2 Web FS sync implementation on fresh exports.

This is deliberately version-pinned. It does not alter cache locations, contents,
quotas or pack layout. A dirty request schedules one more serial pass; it is not a
guarantee that IndexedDB has enough space or that files cannot change mid-scan.
"""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import tempfile

PATCH_ID = 'hongyuan-idbfs-serial-dirty-v1'
GODOT_FS_SHA256 = 'be6475bf104a5105c6519406881188b781f30c6f500c80180b34e021dd53cabc'
FS_START = 'var GodotFS={'
FS_END = ';var GodotOS='
SYNC_OLD = 'sync:function(){if(GodotFS._syncing){GodotRuntime.error("Already syncing!");return Promise.resolve()}GodotFS._syncing=true;return new Promise(function(resolve,reject){FS.syncfs(false,function(error){if(error){GodotRuntime.error(`Failed to save IDB file system: ${error.message}`)}GodotFS._syncing=false;resolve(error)})})}'
LOAD_OLD = 'loadLocalEntry:(path,callback)=>{var stat,node;try{var lookup=FS.lookupPath(path);node=lookup.node;stat=FS.stat(path)}catch(e){return callback(e)}if(FS.isDir(stat.mode)){return callback(null,{timestamp:stat.mtime,mode:stat.mode})}else if(FS.isFile(stat.mode)){node.contents=MEMFS.getFileDataAsTypedArray(node);return callback(null,{timestamp:stat.mtime,mode:stat.mode,contents:node.contents})}else{return callback(new Error("node type not supported"))}},'
STORE_OLD = 'storeRemoteEntry:(store,path,entry,callback)=>{try{var req=store.put(entry,path)}catch(e){callback(e);return}req.onsuccess=event=>callback();req.onerror=e=>{callback(e.target.error);e.preventDefault()}},'

HELPERS = r'''_hy_patch:"hongyuan-idbfs-serial-dirty-v1",
_sync_dirty:false,_sync_promise:null,_sync_sequence:0,
_hy_error_details:function(error){
    function read(keys){
        try{
            let value=error;
            for(const key of keys){if(value==null)return null;value=value[key]}
            if(value==null)return null;
            return ["string","number","boolean"].includes(typeof value)?value:String(value);
        }catch(_){return "[unreadable]"}
    }
    let full;
    try{full=String(error)}catch(_){full="[unprintable error]"}
    return {name:read(["name"]),message:read(["message"]),errno:read(["errno"]),
        string:full,target_name:read(["target","error","name"]),
        target_message:read(["target","error","message"])};
},
_hy_idb_error:function(operation,path,bytes,error){
    GodotRuntime.error("HONGYUAN_IDBFS_ENTRY "+JSON.stringify({operation:operation,
        path:path,bytes:bytes==null?null:bytes,error:GodotFS._hy_error_details(error)}));
},'''

SYNC_NEW = r'''sync:function(){
    const fs=GodotFS;
    if(fs._syncing){
        fs._sync_dirty=true;
        return fs._sync_promise;
    }
    fs._syncing=true;
    fs._sync_dirty=false;
    let finishBatch;
    const pending=new Promise(function(resolve){finishBatch=resolve});
    fs._sync_promise=pending;
    let firstError=null;
    function flush(){
        // Requests before this pass are covered by its fresh local scan.
        fs._sync_dirty=false;
        const sequence=++fs._sync_sequence;
        const started=Date.now();
        GodotRuntime.print("HONGYUAN_IDBFS_SYNC "+JSON.stringify({phase:"start",
            sequence:sequence,time:started}));
        let completed=false;
        function done(error){
            if(completed)return;
            completed=true;
            if(error){
                if(firstError===null)firstError=error;
                GodotRuntime.error("Failed to save IDB file system: "+
                    JSON.stringify(fs._hy_error_details(error)));
            }
            GodotRuntime.print("HONGYUAN_IDBFS_SYNC "+JSON.stringify({phase:"end",
                sequence:sequence,time:Date.now(),elapsed_ms:Date.now()-started,
                dirty:fs._sync_dirty,error:error?fs._hy_error_details(error):null}));
            if(fs._sync_dirty){
                // No overlapping transactions, and no recursive stack growth
                // when FS invokes its callback synchronously.
                Promise.resolve().then(flush);
            }else{
                fs._syncing=false;
                fs._sync_promise=null;
                finishBatch(firstError);
            }
        }
        try{FS.syncfs(false,done)}catch(error){done(error)}
    }
    flush();
    return pending;
}'''

LOAD_NEW = r'''loadLocalEntry:(path,callback)=>{
    var stat,node;
    function failed(error){GodotFS._hy_idb_error("loadLocalEntry",path,null,error);return callback(error)}
    try{var lookup=FS.lookupPath(path);node=lookup.node;stat=FS.stat(path)}catch(e){return failed(e)}
    if(FS.isDir(stat.mode)){return callback(null,{timestamp:stat.mtime,mode:stat.mode})}
    else if(FS.isFile(stat.mode)){
        node.contents=MEMFS.getFileDataAsTypedArray(node);
        return callback(null,{timestamp:stat.mtime,mode:stat.mode,contents:node.contents});
    }else{return failed(new Error("node type not supported"))}
},'''

STORE_NEW = r'''storeRemoteEntry:(store,path,entry,callback)=>{
    function failed(error){
        const content=entry.contents;
        const bytes=content==null?null:(content.byteLength==null?content.length:content.byteLength);
        GodotFS._hy_idb_error("storeRemoteEntry",path,bytes,error);
        callback(error);
    }
    try{var req=store.put(entry,path)}catch(e){failed(e);return}
    req.onsuccess=event=>callback();
    req.onerror=e=>{failed(e.target.error);e.preventDefault()};
},'''


def patch_source(source: str) -> str:
    """Fail closed before replacement if any verified engine fragment differs."""
    if PATCH_ID in source:
        raise ValueError('IDBFS patch is already present; export into a new directory')
    if source.count(FS_START) != 1 or source.count(FS_END) != 1:
        raise ValueError('Unsupported Godot Web runtime: GodotFS boundaries changed')
    start = source.index(FS_START)
    end = source.index(FS_END, start) + 1
    fs = source[start:end]
    actual = sha256(fs.encode()).hexdigest()
    if actual != GODOT_FS_SHA256:
        raise ValueError(f'Unsupported GodotFS implementation: expected {GODOT_FS_SHA256}, got {actual}')
    required = [SYNC_OLD, LOAD_OLD, STORE_OLD,
                'GodotRuntime.print(`IndexedDB not available: ${err.message}`)']
    for fragment in required:
        if source.count(fragment) != 1:
            raise ValueError('Unsupported Godot 4.7.2 IDBFS fragment; refusing partial patch')
    source = source.replace(FS_START, FS_START + HELPERS, 1)
    source = source.replace(SYNC_OLD, SYNC_NEW, 1)
    source = source.replace(LOAD_OLD, LOAD_NEW, 1)
    source = source.replace(STORE_OLD, STORE_NEW, 1)
    return source.replace('GodotRuntime.print(`IndexedDB not available: ${err.message}`)',
                          'GodotRuntime.print("IndexedDB not available: "+JSON.stringify(GodotFS._hy_error_details(err)))', 1)


def patch_export(engine: Path, *, dry_run: bool = False) -> dict:
    before = engine.read_bytes()
    after = patch_source(before.decode('utf-8')).encode('utf-8')
    report = {'patch': PATCH_ID, 'verified_godot_fs_sha256': GODOT_FS_SHA256,
              'engine_before_sha256': sha256(before).hexdigest(),
              'engine_after_sha256': sha256(after).hexdigest()}
    if not dry_run:
        # Replace this export's directory entry, never mutate another frozen
        # export that happens to share an immutable hard-linked engine file.
        with tempfile.NamedTemporaryFile(dir=engine.parent, prefix='.idbfs-', delete=False) as tmp:
            staging = Path(tmp.name)
            tmp.write(after)
        try:
            staging.chmod(engine.stat().st_mode & 0o777)
            staging.replace(engine)
        finally:
            staging.unlink(missing_ok=True)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('engine', type=Path)
    parser.add_argument('--dry-run', action='store_true', help='Verify exact runtime and report hashes without writing')
    args = parser.parse_args()
    print(json.dumps(patch_export(args.engine, dry_run=args.dry_run), indent=2))
