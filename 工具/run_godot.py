#!/usr/bin/env python3
"""工程内隔离启动：不给子进程提供HOME，Godot数据路径退回本工作目录。"""
from pathlib import Path
import os,sys,subprocess
root=Path(__file__).resolve().parents[1]
env=os.environ.copy();env.pop("HOME",None);env["__GODOT_SHELL_ENV_SET"]="1"
env["TMPDIR"]=str(root/"运行数据"/"临时")
Path(env["TMPDIR"]).mkdir(parents=True,exist_ok=True)
(root/"godot"/"运行数据").mkdir(parents=True,exist_ok=True)
os.chdir(root/"godot")
command=["/Applications/Godot.app/Contents/MacOS/Godot","--path",str(root/"godot"),"--log-file",str(root/"交付/完整村庄-1006/引擎运行.log")]+sys.argv[1:]
raise SystemExit(subprocess.call(command,env=env))
