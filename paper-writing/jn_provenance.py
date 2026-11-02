"""jn_provenance.py -- who first wrote each word of the JN manuscript? Read-only.

    python -I jn_provenance.py <ref> <outdir> [--rescan]

Each word is attributed to the earliest commit in which it appeared in the same five-word context
(so moves and renames do not matter; an edited word and only that word goes to its editor).
That commit's class decides the label:
  AI commit (Co-Authored-By: Claude)                  -> ai_commit, unless the user typed those words first
  Overleaf sync / local commit without trailer         -> ai_pasted if the words were born in an assistant
                                                          message or tool call before that commit, else human
  first snapshot                                      -> pre_record
"AI-born" = the five words were written by the assistant before they appeared in anything it had been given.
"""
import collections, glob, json, os, re, subprocess, sys
from datetime import datetime
from pathlib import Path

REPO = r'C:\Users\aditya\Documents\projects\Closedloop_edit'
PROJ = r'C:\Users\aditya\.claude\projects'
HUB = r'C:\Users\aditya\Documents\projects\brain_paper'
REF, OUT = sys.argv[1], Path(sys.argv[2])
RESCAN = '--rescan' in sys.argv
N = 5
INF = float('inf')
TARGETS = ['main.tex', 'introduction.tex', 'results.tex', 'discussion.tex', 'methods.tex', 'supplementary.tex']

COMMENT = re.compile(r'(?<!\\)%.*')
COMMAND = re.compile(r'\\[a-zA-Z]+\*?')
TOK = re.compile(r"[a-z0-9]+(?:[.'/\-][a-z0-9]+)*")
TRAILER = re.compile(r'Co-Authored-By:\s*Claude', re.I)
REMINDER = re.compile(r'<system-reminder>.*?</system-reminder>', re.S)


def git(*a):
    return subprocess.run(['git', '-C', REPO, *a], capture_output=True).stdout.decode('utf-8', 'replace')


def blank(rx, text):
    return rx.sub(lambda m: ' ' * len(m.group()), text)


def prep(text, strip_comments=True):
    text = blank(COMMENT, text) if strip_comments else text.replace('%', ' ')
    return blank(COMMAND, text).lower()


def toks(text):
    return TOK.findall(prep(text, False))


def shingles(words):
    return [tuple(words[i:i + N]) for i in range(len(words) - N + 1)]


# ---------------------------------------------------------------- history index
log = git('log', '--date-order', '--reverse', '--format=%H%x00%an%x00%ct%x00%s%x00%B%x01', REF)
commits = []
for rec in log.split('\x01'):
    p = rec.strip('\n').split('\x00')
    if len(p) >= 5:
        commits.append(dict(h=p[0], an=p[1], ts=int(p[2]), s=p[3], msg=p[4]))
print(len(commits), 'commits', flush=True)


# Overleaf commits whose text is AI-written on evidence the transcripts no longer hold.
# 2efa96b adds methods_rewrite.tex, whose header says "full rewrite ... Paste into Overleaf and edit from there".
PASTED_AI = {'2efa96b'}


def cclass(i, c):
    if i == 0:
        return 'first'
    if c['h'][:7] in PASTED_AI or TRAILER.search(c['msg']):
        return 'AI'
    if c['an'] == 'Aditya Deole' or c['s'].startswith(('Updates from Overleaf', 'Initial Overleaf')):
        return 'OL'
    return 'LOCAL'


first, seen = {}, set()
for i, c in enumerate(commits):
    c['cls'] = cclass(i, c)
    for line in git('ls-tree', '-r', c['h']).splitlines():
        meta, _, path = line.partition('\t')
        if not path.endswith('.tex'):
            continue
        blob = meta.split()[2]
        if blob in seen:
            continue
        seen.add(blob)
        raw = git('cat-file', 'blob', blob)
        for text in (prep(raw, True), prep(raw, False)):
            for sh in shingles(TOK.findall(text)):
                first.setdefault(sh, i)
print(len(first), 'shingles over history', flush=True)

# ---------------------------------------------------------------- target text
target, T = {}, set()
head_hash = git('rev-parse', REF).strip()
for f in TARGETS:
    raw = git('show', f'{REF}:{f}')
    if not raw:
        print('missing at target:', f)
        continue
    clean = prep(raw, True)
    ms = list(TOK.finditer(clean))
    words = [m.group() for m in ms]
    target[f] = dict(raw=raw, ms=ms, words=words)
    T.update(shingles(words))
print(len(T), 'shingles in target', flush=True)

# ---------------------------------------------------------------- transcripts (cached)
cache = OUT / 'transcript_index.json'
if cache.exists() and not RESCAN:
    idx = json.loads(cache.read_text(encoding='utf-8'))
else:
    byfirst = collections.defaultdict(set)
    for sh in T:
        byfirst[sh[0]].add(sh)
    idx = {'ai': {}, 'input': {}, 'user': {}, 'files': 0, 'tmin': INF, 'tmax': 0}

    def note(kind, text, ts):
        if not text or len(text) > 1_000_000:
            return
        w = TOK.findall(prep(text, False))
        d = idx[kind]
        for i in range(len(w) - N + 1):
            s = byfirst.get(w[i])
            if s:
                sh = tuple(w[i:i + N])
                if sh in s:
                    k = ' '.join(sh)
                    if ts < d.get(k, INF):
                        d[k] = ts

    files = glob.glob(os.path.join(PROJ, '*brain-paper*', '**', '*.jsonl'), recursive=True)
    files += glob.glob(os.path.join(PROJ, 'C--Users-aditya-Documents', '*.jsonl'))
    files += glob.glob(os.path.join(PROJ, 'C--Users-aditya-Documents-projects', '*.jsonl'))
    print(len(files), 'transcript files', flush=True)
    for fn, path in enumerate(files):
        with open(path, encoding='utf-8', errors='replace') as fh:
            for line in fh:
                if '"timestamp"' not in line:
                    continue
                try:
                    e = json.loads(line)
                except json.JSONDecodeError:
                    continue
                msg, tstr = e.get('message'), e.get('timestamp')
                if not isinstance(msg, dict) or not tstr or e.get('isCompactSummary') or e.get('isMeta'):
                    continue
                ts = datetime.fromisoformat(tstr.replace('Z', '+00:00')).timestamp()
                idx['tmin'], idx['tmax'] = min(idx['tmin'], ts), max(idx['tmax'], ts)
                cont = msg.get('content')
                blocks = [{'type': 'text', 'text': cont}] if isinstance(cont, str) else (cont or [])
                for b in blocks:
                    if not isinstance(b, dict):
                        continue
                    ty = b.get('type')
                    if e.get('type') == 'assistant':
                        if ty == 'text':
                            note('ai', b.get('text'), ts)
                        elif ty == 'tool_use':
                            for k, v in (b.get('input') or {}).items():
                                if isinstance(v, str) and k != 'old_string':
                                    note('ai', v, ts)
                    elif e.get('type') == 'user':
                        if ty == 'text':
                            txt = b.get('text') or ''
                            note('input', txt, ts)
                            note('user', REMINDER.sub(' ', txt), ts)
                        elif ty == 'tool_result':
                            c2 = b.get('content')
                            if isinstance(c2, str):
                                note('input', c2, ts)
                            elif isinstance(c2, list):
                                for b2 in c2:
                                    if isinstance(b2, dict) and b2.get('type') == 'text':
                                        note('input', b2.get('text'), ts)
        idx['files'] += 1
        if fn % 10 == 0:
            print('  scanned', fn, flush=True)
    OUT.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(idx), encoding='utf-8')
fmt = lambda t: datetime.fromtimestamp(t).strftime('%Y-%m-%d')
print('transcripts cover', fmt(idx['tmin']), 'to', fmt(idx['tmax']), '|', idx['files'], 'files |',
      len(idx['ai']), 'target shingles in AI output,', len(idx['user']), 'in typed user text', flush=True)


def born(sh):
    k = ' '.join(sh)
    a = idx['ai'].get(k, INF)
    return a if a < INF and a <= idx['input'].get(k, INF) else INF


def typed_first(sh, by):
    k = ' '.join(sh)
    u = idx['user'].get(k, INF)
    return u < by and u <= idx['ai'].get(k, INF)


# ---------------------------------------------------------------- word and line labels
report = {}
units = []
contrib = collections.Counter()
for f, d in target.items():
    w = d['words']
    if len(w) < N:
        continue
    sh = shingles(w)
    labels = []
    for i in range(len(w)):
        cover = [sh[s] for s in range(max(0, i - N + 1), min(i, len(sh) - 1) + 1)]
        ci = min(first.get(x, len(commits) - 1) for x in cover)
        top = [x for x in cover if first.get(x, len(commits) - 1) == ci]
        c = commits[ci]
        if c['cls'] == 'AI':
            lab = 'dictated' if any(typed_first(x, c['ts']) for x in top) else 'ai_commit'
        elif any(born(x) < c['ts'] for x in top):
            lab = 'ai_pasted'
        else:
            lab = {'OL': 'overleaf_human', 'LOCAL': 'local_no_trailer', 'first': 'pre_record'}[c['cls']]
        labels.append((lab, ci))
    d['labels'] = labels
    assert len(prep(d['raw'], True)) == len(d['raw']), f
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f'words_{f}.json').write_text(json.dumps(dict(
        starts=[m.start() for m in d['ms']], labels=[l for l, _ in labels],
        commits=[commits[ci]['h'][:7] for _, ci in labels], dates=[fmt(commits[ci]['ts']) for _, ci in labels])), encoding='utf-8')
    report[f] = collections.Counter(l for l, _ in labels)
    for l, ci in labels:
        if l in ('overleaf_human', 'local_no_trailer', 'pre_record', 'dictated'):
            contrib[(ci, l)] += 1
    # per line
    starts = [m.start() for m in d['ms']]
    lines, pos = d['raw'].split('\n'), 0
    j = 0
    for ln, line in enumerate(lines, 1):
        end = pos + len(line)
        cnt = collections.Counter()
        cis = []
        while j < len(starts) and starts[j] < end:
            if starts[j] >= pos:
                cnt[labels[j][0]] += 1
                cis.append(labels[j][1])
            j += 1
        if sum(cnt.values()):
            units.append(dict(file=f, line=ln, n=sum(cnt.values()), counts=dict(cnt), first_commit=commits[min(cis)]['h'][:7],
                              first_date=fmt(commits[min(cis)]['ts']), last_commit=commits[max(cis)]['h'][:7],
                              last_date=fmt(commits[max(cis)]['ts']), text=line))
        pos = end + 1

ORDER = ['ai_commit', 'ai_pasted', 'overleaf_human', 'dictated', 'local_no_trailer', 'pre_record']
print(f'\n== target {REF} {head_hash[:7]}: words by origin')
print(f'{"file":20s}{"total":>7s}' + ''.join(f'{o:>17s}' for o in ORDER))
tot = collections.Counter()
for f, c in report.items():
    n = sum(c.values())
    tot.update(c)
    print(f'{f:20s}{n:7d}' + ''.join(f'{c[o]:17d}' for o in ORDER))
n = sum(tot.values())
print(f'{"ALL":20s}{n:7d}' + ''.join(f'{tot[o]:17d}' for o in ORDER))
print(f'{"share":27s}' + ''.join(f'{100 * tot[o] / n:16.1f}%' for o in ORDER))

print('\n== non-AI commits contributing the most words to the target')
for (ci, lab), k in contrib.most_common(22):
    c = commits[ci]
    print(f'  {k:5d} {lab:17s} {c["h"][:7]} {fmt(c["ts"])} {c["an"][:12]:12s} {c["s"][:58]}')

AI = ('ai_commit', 'ai_pasted')
bins = collections.Counter()
for u in units:
    a = sum(u['counts'].get(k, 0) for k in AI) / u['n']
    u['ai_share'] = round(a, 3)
    bins['>=0.9' if a >= .9 else '0.5-0.9' if a >= .5 else '0.1-0.5' if a >= .1 else '<0.1'] += 1
print('\n== lines by AI share of words:', dict(bins), 'of', len(units))
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'provenance_units.json').write_text(json.dumps(dict(ref=REF, head=head_hash, units=units), indent=0), encoding='utf-8')
print('saved', OUT / 'provenance_units.json')
