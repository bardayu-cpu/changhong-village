"""Read-only frozen-file server plus isolated local input evidence sink."""
import argparse,hashlib,json,mimetypes,re,threading
from pathlib import Path
from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
from urllib.parse import urlsplit,unquote
parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8897);parser.add_argument('--frozen',type=Path,default=Path(__file__).resolve().parents[1]/'h-delivery-b6415d7');args=parser.parse_args()
root=Path(__file__).resolve().parent; evidence=root/'events';evidence.mkdir(exist_ok=True);lock=threading.Lock()
checks={}
for line in (args.frozen/'SHA256SUMS.web.txt').read_text().splitlines():
 digest,name=line.split('  ',1);checks[name]=digest
 assert hashlib.sha256((args.frozen/'web'/name).read_bytes()).hexdigest()==digest,name
(root/'verified-files.json').write_text(json.dumps(checks,indent=2)+'\n')
class Handler(BaseHTTPRequestHandler):
 def do_GET(self):
  path=unquote(urlsplit(self.path).path)
  if path.startswith('/web/') and path[5:] in checks:p=args.frozen/'web'/path[5:]
  elif path in ['/','/probe.html']:p=root/'probe.html'
  elif path=='/probe.js':p=root/'probe.js'
  else:self.send_error(404);return
  data=p.read_bytes();self.send_response(200);self.send_header('Content-Type',mimetypes.guess_type(str(p))[0] or 'application/octet-stream');self.send_header('Content-Length',str(len(data)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(data)
 def do_POST(self):
  name=unquote(urlsplit(self.path).path).removeprefix('/evidence/')
  if not self.path.startswith('/evidence/') or not re.fullmatch(r'[a-z0-9_-]{1,60}',name):self.send_error(400);return
  size=int(self.headers.get('Content-Length','0'))
  if size>100000:self.send_error(413);return
  value=json.loads(self.rfile.read(size))
  with lock:
   with (evidence/(name+'.jsonl')).open('a') as f:f.write(json.dumps(value,ensure_ascii=False)+'\n')
  self.send_response(204);self.end_headers()
 def log_message(self,fmt,*vals):
  if self.command!='POST':super().log_message(fmt,*vals)
print('Verified frozen b6415d7 files. Serving localhost port',args.port,flush=True)
ThreadingHTTPServer(('127.0.0.1',args.port),Handler).serve_forever()
