from pathlib import Path
import hashlib,json
A=Path(__file__).resolve().parents[1]/'assets'
files={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(A.iterdir()) if p.suffix in ['.png','.nav','.wav'] and 'approved_mask' not in p.name and 'candidate' not in p.name}
(A/'manifest.json').write_text(json.dumps({'version':4,'files':files},ensure_ascii=False,indent=2)+'\n')
print('Manifest:',len(files),'files',sum(x['bytes'] for x in files.values()),'bytes')
