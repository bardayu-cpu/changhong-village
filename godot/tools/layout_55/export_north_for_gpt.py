#!/usr/bin/env python3
"""老名字：北边那块。现在是 export_block_for_gpt.py north 的别名（排法 C 以后北边要重导）。用法同 export_block_for_gpt.py，不用写 north。"""
import os
import subprocess
import sys

sys.exit(subprocess.call([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "export_block_for_gpt.py"), "north"] + sys.argv[1:]))
