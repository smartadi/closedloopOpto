import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1])
OUT = Path(sys.argv[2])
FILES = ["main.tex", "introduction.tex", "results.tex", "discussion.tex", "methods.tex",
         "supplementary.tex", "stat_tables.tex"]
CITE = re.compile(r"\\cite[a-z]*\*?(?:\[[^\]]*\])*\{([^}]*)\}")

bib = (ROOT / "refs.bib").read_text(encoding="utf-8")


def bibinfo(key):
    m = re.search(r"@(\w+)\s*\{\s*" + re.escape(key) + r"\s*,(.*?)(?=\n@|\Z)", bib, re.S)
    if not m:
        return "NOT IN BIB"
    body = m.group(2)

    def f(name):
        mm = re.search(r"\b" + name + r"\s*=\s*[{\"](.*?)[}\"]\s*,?\s*(?:\n|\s[a-zA-Z]+\s*=)", body, re.S | re.I)
        return re.sub(r"[{}]", "", re.sub(r"\s+", " ", mm.group(1))).strip() if mm else ""
    auth = f("author").split(" and ")[0]
    venue = f("journal") or f("booktitle") or f("howpublished") or f("publisher")
    return f"{auth} et al., {f('year')}. {f('title')}. {venue}"


uses = {}
for fn in FILES:
    p = ROOT / fn
    if not p.exists():
        continue
    text = p.read_text(encoding="utf-8")
    text = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("%"))
    # sentences: split on line breaks and on ". " boundaries
    for line in text.splitlines():
        for sent in re.split(r"(?<=[.!?])\s+(?=[A-Z\\])", line):
            for m in CITE.finditer(sent):
                for k in [k.strip() for k in m.group(1).split(",") if k.strip()]:
                    clean = CITE.sub("[cite]", sent).strip()
                    uses.setdefault(k, []).append((fn, clean[:400]))

order = []
for fn in FILES:  # order of first appearance by file
    for k, v in uses.items():
        if v[0][0] == fn and k not in order:
            order.append(k)
with OUT.open("w", encoding="utf-8") as o:
    o.write(f"{len(uses)} keys\n\n")
    for k in order:
        o.write(f"## {k}\n{bibinfo(k)}\n")
        seen = set()
        for fn, s in uses[k]:
            if (fn, s) in seen:
                continue
            seen.add((fn, s))
            o.write(f"- [{fn}] {s}\n")
        o.write("\n")
print(len(uses), "keys written")
