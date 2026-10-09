"""PCK 打包结束后，为本机试玩包签名并留下校验记录。"""
from pathlib import Path
import subprocess, json, hashlib, datetime

root = Path(__file__).resolve().parents[1]
delivery = root / '交付/完整村庄-1006'
app = delivery / '本地试玩包/裳泓村.app'
subprocess.run(['codesign', '--force', '--sign', '-', '--timestamp=none', str(app)], check=True)
result = subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)], capture_output=True, text=True)
record = {'at': datetime.datetime.now().astimezone().isoformat(), 'kind': '仅本机 ad-hoc 签名；没有开发者证书、公证或发布', 'passed': result.returncode == 0, 'output': result.stdout + result.stderr, 'files': []}
for rel in ['Contents/MacOS/裳泓村', 'Contents/Resources/Godot', 'Contents/Resources/裳泓村.pck']:
    f = app / rel
    record['files'].append({'path': rel, 'bytes': f.stat().st_size, 'sha256': hashlib.sha256(f.read_bytes()).hexdigest()})
(delivery / '本地包签名校验.json').write_text(json.dumps(record, ensure_ascii=False, indent=2))
print(json.dumps({'passed': record['passed'], 'files': len(record['files'])}, ensure_ascii=False))
raise SystemExit(result.returncode)
