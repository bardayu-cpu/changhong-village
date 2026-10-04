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


def mirror_x(d):
    """整块左右翻（10/4 方案 C：停车场翻成路西车位东）：地面、家具、口、走的范围、牌子、出生点一起翻，
    画布宽 W：x → W - x，矩形左右对调；牌子、圆柱、树、点的 x 都是正中，照翻"""
    W = d["size"][0]

    def fx(v):
        return W - v

    def walk(o, key=None):
        if isinstance(o, dict):
            out = {}
            for k, v in o.items():
                if k == "rect" and isinstance(v, list) and len(v) == 4:
                    out[k] = [fx(v[2]), v[1], fx(v[0]), v[3]]
                elif k == "x" and isinstance(v, (int, float)):
                    out[k] = fx(v)
                elif k == "x0" and "x1" in o:
                    out[k] = fx(o["x1"])
                elif k == "x1" and "x0" in o:
                    out[k] = fx(o["x0"])
                elif k in ("pts",) and isinstance(v, list):
                    out[k] = [[fx(p[0]), p[1]] for p in v]
                elif k in ("spawn", "from_court", "from_lake", "arrive") and isinstance(v, list) and len(v) == 2:
                    out[k] = [fx(v[0]), v[1]]
                elif k == "walk":
                    out[k] = [[[fx(p[0]), p[1]] for p in poly] for poly in v]
                else:
                    out[k] = walk(v, k)
            return out
        if isinstance(o, list):
            return [walk(e) for e in o]
        return o

    return walk(d)
