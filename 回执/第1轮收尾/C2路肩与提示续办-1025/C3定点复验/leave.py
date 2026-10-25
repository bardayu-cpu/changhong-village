from pathlib import Path
import subprocess
q=Path(__file__).resolve().parent
cmd=['/Applications/Godot.app/Contents/MacOS/Godot','--path',str(q/'工程冻结'),'--script',str(q/'leave_candidate.gd'),'--','--ayu-save='+str(q/'life-play.json'),'--core-save='+str(q/'core-play'),'--ayu-hour=13','--ayu-month=7','--ayu-weather=clear']
with (q/'candidate-play.log').open('w') as f:raise SystemExit(subprocess.call(cmd,stdout=f,stderr=subprocess.STDOUT))
