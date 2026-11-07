// Pure transfer bridge: story-owned UI handles retry and return-to-desk.
import './hongyuan-content-config'
import {sha256} from './hongyuan-content-sha256'
const config = GameGlobal.hongyuanContentConfig
const loaded = new Set(), pending = {}, statuses = {}
let initialized = false
const fs = () => wx.getFileSystemManager()
const readFile = path => new Promise((resolve,reject) => fs().readFile({filePath:path,success:r=>resolve(r.data),fail:reject}))
const writeFile = (path,data) => new Promise((resolve,reject) => fs().writeFile({filePath:path,data,success:resolve,fail:reject}))
function download(entry, id) {
    return new Promise((resolve,reject) => {
        if (!initialized) { wx.cloud.init({env:config.environment,traceUser:false}); initialized=true }
        let settled=false, task
        const finish=(error,path) => {
            if(settled)return
            settled=true; clearTimeout(timer)
            if(error)reject(error);else resolve(path)
        }
        const timer=setTimeout(()=>{if(task && task.abort)task.abort();finish(new Error('download timeout'))},85000)
        task=wx.cloud.downloadFile({fileID:config.prefix+entry.file,
            success:r=>r.tempFilePath && (!r.statusCode || r.statusCode===200)?finish(null,r.tempFilePath):finish(new Error('download status '+r.statusCode)),
            fail:e=>finish(e)})
        if(task && task.onProgressUpdate)task.onProgressUpdate(r=>{
            statuses[id]={state:'download',received:r.totalBytesWritten||0,total:entry.bytes}
        })
    })
}
async function mountInput(group,item) {
    const entry=item<0?config.local[group]:(config.remote[group]||[])[item]
    if(!entry)throw new Error('unknown chapter '+group)
    const id=group+'-'+item, target='/hongyuan-'+id+'.pck'
    if(loaded.has(id))return target
    if(!pending[id])pending[id]=(async()=>{
        statuses[id]={state:'download',received:0,total:entry.bytes}
        let buffer
        if(entry.path){
            await new Promise((resolve,reject)=>wx.loadSubpackage({name:group,success:resolve,fail:reject}))
            const engine=GameGlobal.GODOTSDK.engine
            const preload=await engine.preloadFile('/'+entry.path)
            const files=engine.preloader.preloadedFiles
            const i=files.findIndex(file=>file.path==='/'+entry.path)
            buffer=i<0?preload&&preload.buffer:files.splice(i,1)[0].buffer
        }else{
            const cache=wx.env.USER_DATA_PATH+'/hy-'+entry.sha256+'.pck'
            try{buffer=await readFile(cache)}catch(_){buffer=null}
            if(!buffer || buffer.byteLength!==entry.bytes || sha256(buffer)!==entry.sha256){
                buffer=await readFile(await download(entry,id))
                if(buffer.byteLength!==entry.bytes || sha256(buffer)!==entry.sha256)throw new Error('chapter integrity mismatch')
                // A full persistent store must not stop an otherwise valid chapter.
                try{await writeFile(cache,buffer)}catch(_){statuses[id].cacheUnavailable=true}
            }
        }
        if(!buffer || buffer.byteLength!==entry.bytes)throw new Error('incomplete chapter')
        GameGlobal.GODOTSDK.copy_to_fs(target,buffer)
        loaded.add(id)
        statuses[id]={state:'ready',received:entry.bytes,total:entry.bytes}
    })().finally(()=>{delete pending[id]})
    await pending[id]
    return target
}
GameGlobal.hongyuanContent={
    count:group=>(config.remote[group]||[]).length,
    local:group=>!!config.local[group],
    status:(group,item)=>JSON.stringify(statuses[group+'-'+item]||{state:'download',received:0,total:0}),
    editGuestName(value, maxLength, callback) {
        let draft = value
        const input = result => { if (typeof result.value === 'string') draft = result.value }
        const complete = (result = {}) => {
            input(result)
            wx.offKeyboardInput(input)
            wx.offKeyboardConfirm(input)
            wx.offKeyboardComplete(complete)
            callback(draft)
        }
        wx.onKeyboardInput(input)
        wx.onKeyboardConfirm(input)
        wx.onKeyboardComplete(complete)
        wx.showKeyboard({
            defaultValue: value, maxLength, multiple: false, confirmHold: false, confirmType: 'done',
            fail: error => {
                console.error('[hongyuan] name keyboard failed', error)
                complete()
            }
        })
    },
    fetch(group,item,callback){
        let timer
        const timeout=new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('chapter timeout')),85000)})
        Promise.race([mountInput(group,item),timeout]).then(callback).catch(error=>{
            statuses[group+'-'+item]={state:'error',error:String(error)}
            callback('')
        }).finally(()=>clearTimeout(timer))
    }
}
