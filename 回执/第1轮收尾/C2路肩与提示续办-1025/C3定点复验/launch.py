from pathlib import Path
import subprocess,json,time
q=Path(__file__).resolve().parent
cmd=['/Applications/Godot.app/Contents/MacOS/Godot','--path',str(q/'工程冻结'),'--script',str(q/'narrow.gd'),'--','--ayu-save='+str(q/'life-final.json'),'--core-save='+str(q/'core-final'),'--qa-out='+str(q/'实际引擎'),'--ayu-hour=13','--ayu-month=7','--ayu-weather=clear']
with (q/'engine-final.log').open('w') as f:
 t=time.time();p=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=120)
(q/'运行-final.json').write_text(json.dumps({'exit':p.returncode,'elapsed':time.time()-t}))
