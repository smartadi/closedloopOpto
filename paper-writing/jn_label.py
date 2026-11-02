"""jn_label.py -- wrap AI-written sentences of the JN manuscript in \\ai{...}, in a COPY. Read-only for the repo.

    python -I jn_label.py <ref> <prov_dir> <out_dir> [--base <ref>] [--thresh 0.5]

A sentence is wrapped when at least `thresh` of its words trace back to AI and it did not change since --base
(lines changed since the last sync were edited on Overleaf by Nick or Aditya, so they count as human).
Stripping every wrapper must give back the input byte for byte; the script stops if it does not.
"""
import collections, csv, difflib, json, re, subprocess, sys
from pathlib import Path

REPO = r'C:\Users\aditya\Documents\projects\Closedloop_edit'
REF, PROV, OUT = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
BASE = sys.argv[sys.argv.index('--base') + 1] if '--base' in sys.argv else None
THRESH = float(sys.argv[sys.argv.index('--thresh') + 1]) if '--thresh' in sys.argv else 0.5
TARGETS = ['main.tex', 'introduction.tex', 'results.tex', 'discussion.tex', 'methods.tex', 'supplementary.tex']
AI = {'ai_commit', 'ai_pasted'}
OPEN = '\\ai{'

SKIP_ENV = {'equation', 'equation*', 'align', 'align*', 'gather', 'gather*', 'multline', 'multline*', 'tabular', 'tabular*',
            'tabularx', 'algorithm', 'algorithmic', 'tikzpicture', 'overpic', 'cases', 'split', 'array', 'thebibliography',
            'displaymath', 'verbatim', 'longtable'}
NONPROSE = re.compile(r'\\(begin|end|label|includegraphics|centering|input|include|newcommand|renewcommand|def|usepackage|'
                      r'bibliography|bibliographystyle|clearpage|newpage|setcounter|renewenvironment|vspace|hspace|FloatBarrier|'
                      r'captionsetup|maketitle|linenumbers|nolinenumbers|appendix|noindent\s*$)\b')
PREFIX = re.compile(r'\\caption(\[[^\]]*\])?\{|\\small\{|\\footnotesize\{|\\subsubsection\*?\{|\\subsection\*?\{|\\section\*?\{|\\item\s+|\\small\s+|\\noindent\s+')
TAIL = re.compile(r'(\s*\\\\(\[[^\]]*\])?\s*)$')
ABBR = re.compile(r'(?:\b(?:Fig|Figs|Eq|Eqs|Ref|Refs|Table|Tables|Supp|Suppl|al|e\.g|i\.e|vs|cf|ca|approx|resp|No|Sec|Dr|Prof|Mr|Ms|St|Jr|Inc|Ltd|et)|\b[A-Z])\.$')


def git(*a):
    return subprocess.run(['git', '-C', REPO, *a], capture_output=True).stdout.decode('utf-8', 'replace')


def balance(s):
    """(ok, cut): ok if braces are balanced; cut = index where depth first goes negative, or None."""
    d, i = 0, 0
    while i < len(s):
        ch = s[i]
        if ch == '\\':
            i += 2
            continue
        if ch == '{':
            d += 1
        elif ch == '}':
            d -= 1
            if d < 0:
                return False, i
        i += 1
    return d == 0, None


def dollars(s):
    return len(re.findall(r'(?<!\\)\$', s))


def split_sentences(body):
    """Character spans of the sentences in one line; a split must leave braces and math balanced."""
    spans, start = [], 0
    for m in re.finditer(r'(?<=[.?!])(\s+)(?=[A-Z\\$(])', body):
        head = body[start:m.start()]
        if ABBR.search(head) or not balance(head)[0] or dollars(head) % 2:
            continue
        spans.append((start, m.start()))
        start = m.end()
    spans.append((start, len(body)))
    return spans


def strip_ai(text):
    out, i = [], 0
    while True:
        j = text.find(OPEN, i)
        if j < 0:
            out.append(text[i:])
            return ''.join(out)
        out.append(text[i:j])
        k, d = j + len(OPEN), 1
        start = k
        while d:
            ch = text[k]
            if ch == '\\':
                k += 2
                continue
            d += ch == '{'
            d -= ch == '}'
            k += 1
        out.append(strip_ai(text[start:k - 1]))
        i = k


OUT.mkdir(parents=True, exist_ok=True)
rows, totals = [], collections.Counter()
for f in TARGETS:
    raw = git('show', f'{REF}:{f}')
    W = json.loads((PROV / f'words_{f}.json').read_text(encoding='utf-8'))
    starts, labs, cms, dts = W['starts'], W['labels'], W['commits'], W['dates']
    changed = set()
    if BASE:
        old = git('show', f'{BASE}:{f}').split('\n')
        new = raw.split('\n')
        for tag, a1, a2, b1, b2 in difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes():
            if tag != 'equal':
                changed.update(range(b1, b2))
    lines = raw.split('\n')
    pos, wi, envs, in_abs = 0, 0, [], f != 'main.tex'  # main.tex: prose starts at the abstract
    display = False
    out_lines = []
    for ln, line in enumerate(lines):
        line_start, line_end = pos, pos + len(line)
        pos = line_end + 1
        while wi < len(starts) and starts[wi] < line_start:
            wi += 1

        def row(status, share=None, n=0, text=None, cm='', dt=''):
            rows.append(dict(file=f, line=ln + 1, status=status, ai_share='' if share is None else f'{share:.2f}', words=n,
                             first_commit=cm, first_date=dt, text=(text if text is not None else line).strip()))
            totals[status] += 1

        code = re.sub(r'(?<!\\)%.*', '', line)
        strip = code.strip()
        for m in re.finditer(r'\\(begin|end)\{([^}]*)\}', code):
            if m.group(2) == 'abstract' and f == 'main.tex' and m.group(1) == 'begin':
                in_abs = True
            if m.group(1) == 'begin':
                envs.append(m.group(2))
            elif envs and m.group(2) in envs:
                envs.reverse()
                envs.remove(m.group(2))
                envs.reverse()
        if '\\[' in code and '\\]' not in code:
            display = True
            out_lines.append(line)
            continue
        if display:
            display = '\\]' not in code
            out_lines.append(line)
            continue
        if not strip or not in_abs or any(e in SKIP_ENV for e in envs) or re.fullmatch(r'\\[\[\]].*', strip):
            out_lines.append(line)
            continue
        if NONPROSE.match(strip):
            out_lines.append(line)
            continue
        indent = line[:len(line) - len(line.lstrip())]
        body = code.strip()
        trailing_comment = line[len(code):]
        trail_ws = code[len(code.rstrip()):]
        pre = ''
        while True:
            m = PREFIX.match(body)
            if not m:
                break
            pre += m.group()
            body = body[m.end():]
        post = ''
        m = TAIL.search(body)
        if m:
            post = m.group(1)
            body = body[:m.start()]
        ok, cut = balance(body)
        if not ok and cut is None and body.startswith('\\textbf{'):  # bold legend title that runs over lines
            pre += '\\textbf{'
            body = body[len('\\textbf{'):]
            ok, cut = balance(body)
        if not ok and cut is not None:
            body, post = body[:cut], body[cut:] + post
            ok, cut = balance(body)
            m = TAIL.search(body)
            if m:
                post = m.group(1) + post
                body = body[:m.start()]
        body_stripped = body.rstrip()
        post = body[len(body_stripped):] + post
        body = body_stripped
        if not body or not re.search(r'[A-Za-z]{2,}', body):
            out_lines.append(line)
            continue
        if changed and ln in changed:
            row('human_changed_since_sync')
            out_lines.append(line)
            continue
        if not ok or dollars(body) % 2:
            row('skipped_unbalanced')
            out_lines.append(line)
            continue
        body_off = line_start + len(indent) + len(pre)
        parts, flags = [], []
        for a, b in split_sentences(body):
            idx = [k for k in range(wi, len(starts)) if body_off + a <= starts[k] < body_off + b] if wi < len(starts) else []
            n = len(idx)
            share = sum(labs[k] in AI for k in idx) / n if n else 0
            is_ai = n >= 1 and share >= THRESH
            parts.append((a, b))
            flags.append(is_ai)
            cm = cms[min(idx, key=lambda k: dts[k])] if idx else ''
            dt = min(dts[k] for k in idx) if idx else ''
            row('ai' if is_ai else 'human', share, n, body[a:b], cm, dt)
        new_body, i = '', 0
        while i < len(parts):
            if flags[i]:
                j = i
                while j + 1 < len(parts) and flags[j + 1]:
                    j += 1
                a, b = parts[i][0], parts[j][1]
                new_body += OPEN + body[a:b] + '}'
                gap_end = parts[j + 1][0] if j + 1 < len(parts) else len(body)
                new_body += body[b:gap_end]
                i = j + 1
            else:
                a, b = parts[i]
                gap_end = parts[i + 1][0] if i + 1 < len(parts) else len(body)
                new_body += body[a:gap_end]
                i += 1
        out_lines.append(indent + pre + new_body + post + trail_ws + trailing_comment)
    labelled = '\n'.join(out_lines)
    if strip_ai(labelled) != raw:
        raise SystemExit(f'ROUND TRIP FAILED: {f}')
    (OUT / f).write_text(labelled, encoding='utf-8', newline='')
    print(f'{f:20s} wrapped {labelled.count(OPEN):4d} spans; round trip exact', flush=True)

with open(OUT / 'labels.tsv', 'w', encoding='utf-8', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=['file', 'line', 'status', 'ai_share', 'words', 'first_commit', 'first_date', 'text'], delimiter='\t')
    w.writeheader()
    w.writerows(rows)
print('sentences by status:', dict(totals))
for s in ('ai', 'human'):
    pool = [r for r in rows if r['status'] == s]
    print(f'{s}: {len(pool)} sentences ({sum(r["words"] >= 4 for r in pool)} of 4+ words), {sum(r["words"] for r in pool)} words')
    print('   by file:', dict(collections.Counter(r['file'] for r in pool if r['words'] >= 4)))
print('near the threshold (0.4-0.6):', sum(1 for r in rows if r['ai_share'] and 0.4 <= float(r['ai_share']) < 0.6))
print('skipped:', [(r['file'], r['line']) for r in rows if r['status'] == 'skipped_unbalanced'][:30])
