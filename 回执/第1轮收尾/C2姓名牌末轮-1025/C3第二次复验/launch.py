from pathlib import Path
import subprocess
q=Path(__file__).resolve().parent
cmd=['/Applications/Godot.app/Contents/MacOS/Godot','--path',str(q/'工程冻结'),'--script',str(q/'label_final.gd'),'--','--ayu-save='+str(q/'life.json'),'--core-save='+str(q/'core'),'--qa-out='+str(q/'frames'),'--ayu-hour=13','--ayu-month=10','--ayu-weather=clear']
with (q/'engine.log').open('w') as f:raise SystemExit(subprocess.call(cmd,stdout=f,stderr=subprocess.STDOUT))
