"""迎宾院布局 layout.json 读写：照文件原来的排法写回（顶层一个键一行，列表里一件一行），改几处 git diff 也只是那几行"""
import json


def compact(v):
    return json.dumps(v, ensure_ascii=False, separators=(", ", ": "))


def dumps(d):
    out = ["{"]
    keys = list(d.keys())
    for i, k in enumerate(keys):
        v = d[k]
        tail = "," if i < len(keys) - 1 else ""
        if isinstance(v, list) and any(isinstance(e, (list, dict)) for e in v):
            out.append(' %s: [' % json.dumps(k, ensure_ascii=False))
            for j, e in enumerate(v):
                out.append("  " + compact(e) + ("," if j < len(v) - 1 else ""))
            out.append(" ]" + tail)
        else:
            out.append(" %s: %s%s" % (json.dumps(k, ensure_ascii=False), compact(v), tail))
    out.append("}")
    return "\n".join(out) + "\n"


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save(path, d):
    with open(path, "w", encoding="utf-8") as f:
        f.write(dumps(d))
