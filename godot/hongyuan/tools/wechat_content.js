// The exporter writes this build's manifest next to this bridge.
import './hongyuan-content-config'
const config = GameGlobal.hongyuanContentConfig
let initialized = false

function loadSubpackage(name) {
    return new Promise((resolve, reject) => wx.loadSubpackage({name, success: resolve, fail: reject}))
}
function readFile(path) {
    return new Promise((resolve, reject) => wx.getFileSystemManager().readFile({
        filePath: path, success: res => resolve(res.data), fail: reject
    }))
}
function download(file) {
    return new Promise((resolve, reject) => {
        if (!initialized) {
            wx.cloud.init({env: config.environment, traceUser: false})
            initialized = true
        }
        wx.cloud.downloadFile({
            fileID: config.prefix + file,
            success: res => {
                if (res.tempFilePath && (!res.statusCode || res.statusCode === 200)) resolve(res.tempFilePath)
                else reject(new Error('Cloud download returned ' + res.statusCode))
            },
            fail: reject
        })
    })
}

const loaded = new Set()
const pending = {}
async function mountInput(group, item, callback) {
    const entry = item < 0 ? config.local[group] : (config.remote[group] || [])[item]
    if (!entry) throw new Error('Unknown Hongyuan pack ' + group + '/' + item)
    const id = group + '-' + item
    const target = '/hongyuan-' + id + '.pck'
    if (!loaded.has(id)) {
        if (!pending[id]) pending[id] = (async () => {
            let buffer
            if (entry.path) {
                await loadSubpackage(group)
                // Use the same packaged-file reader as the Godot template.
                const engine = GameGlobal.GODOTSDK.engine
                const preload = await engine.preloadFile('/' + entry.path)
                const files = engine.preloader.preloadedFiles
                const i = files.findIndex(file => file.path === '/' + entry.path)
                buffer = i < 0 ? preload && preload.buffer : files.splice(i, 1)[0].buffer
            } else {
                buffer = await readFile(await download(entry.file))
            }
            if (!buffer || buffer.byteLength !== entry.bytes) throw new Error('Incomplete Hongyuan pack ' + id)
            GameGlobal.GODOTSDK.copy_to_fs(target, buffer)
            loaded.add(id)
        })().finally(() => { delete pending[id] })
        await pending[id]
    }
    callback(target)
}

GameGlobal.hongyuanContent = {
    count: group => (config.remote[group] || []).length,
    local: group => !!config.local[group],
    fetch(group, item, callback) {
        const isCloud = item >= 0
        const attempt = () => {
            wx.showLoading({title: '正在加载资源', mask: true})
            mountInput(group, item, path => {
                wx.hideLoading()
                callback(path)
            }).catch(error => {
                wx.hideLoading()
                console.error('[hongyuan] pack fetch failed', group, item, error)
                wx.showModal({
                    title: '资源加载失败',
                    content: isCloud ? '请检查网络后重试。' : '分包没有加载完成，请重试。',
                    showCancel: false,
                    confirmText: '重试',
                    success: attempt,
                    fail: () => callback('')
                })
            })
        }
        attempt()
    }
}
