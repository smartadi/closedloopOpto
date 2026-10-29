"""nc_wordcount.py -- Nature Comms word budget for a manuscript draft.

    python paper-writing/nc_wordcount.py ../Closedloop_nc

Counts words the way Nature Comms limits them: the main text is Introduction + Results + Discussion,
without the abstract, Methods, references or figure legends. Figure and table environments are removed
from the running text and counted separately as legends (limit 350 words each). Comments, citations,
labels and refs are dropped; inline math counts as one word. Targets come from
nature.com/ncomms/submit/article (checked 2026-10-29): title <= 15 words, abstract <= 200, main text
~5,000, Methods typically < 3,000, <= 10 display items, ~70 references.
"""
import re
import sys
from pathlib import Path

BS = '\\'


def clean(t):
    t = re.sub(r'(?<!\\)%.*', '', t)
    t = re.sub(re.escape(BS) + r'(cite[a-z]*|ref|eqref|label|includegraphics)(\[[^\]]*\])?\{[^}]*\}', ' ', t)
    t = re.sub(r'\$[^$]*\$', ' MATH ', t)
    t = re.sub(re.escape(BS) + r'begin\{(equation|align|algorithm)\*?\}.*?' + re.escape(BS) + r'end\{\1\*?\}', ' ', t, flags=re.S)
    t = re.sub(re.escape(BS) + r'[a-zA-Z]+\*?', ' ', t)
    t = re.sub(r'[{}~\\\[\]]', ' ', t)
    return len([w for w in t.split() if re.search(r'[A-Za-z0-9]', w)])


def split_floats(t):
    floats = re.findall(re.escape(BS) + r'begin\{(figure|table)\*?\}(.*?)' + re.escape(BS) + r'end\{\1\*?\}', t, flags=re.S)
    body = re.sub(re.escape(BS) + r'begin\{(figure|table)\*?\}.*?' + re.escape(BS) + r'end\{\1\*?\}', ' ', t, flags=re.S)
    return body, floats


def sections(body, level='subsection'):
    parts = re.split(re.escape(BS) + level + r'\*?\{([^}]*)\}', body)
    out = [('(before first heading)', parts[0])]
    out += [(parts[i], parts[i + 1]) for i in range(1, len(parts), 2)]
    return out


def main():
    root = Path(sys.argv[1])
    rd = lambda n: (root / n).read_text(encoding='utf-8')
    main_tex = rd('main.tex')
    title = re.search(re.escape(BS) + r'title\{(.*)\}', main_tex).group(1)
    abstract = re.search(re.escape(BS) + r'begin\{abstract\}(.*?)' + re.escape(BS) + r'end\{abstract\}', main_tex, re.S).group(1)
    print(f'{"Title":46s} {clean(title):6d}   target <= 15')
    print(f'{"Abstract":46s} {clean(abstract):6d}   target <= 200')
    total = 0
    legends = []
    for n in ['introduction.tex', 'results.tex', 'discussion.tex']:
        body, floats = split_floats(rd(n))
        legends += [(n, f) for f in floats]
        w = clean(body)
        total += w
        print(f'{n:46s} {w:6d}')
        if n == 'results.tex':
            for h, s in sections(body):
                if clean(s):
                    print(f'   {h[:62]:62s} {clean(s):5d}')
    print(f'{"MAIN TEXT (intro + results + discussion)":46s} {total:6d}   target ~5,000')
    mbody, mfloats = split_floats(rd('methods.tex'))
    print(f'{"Methods (text)":46s} {clean(mbody):6d}   target typically < 3,000')
    for h, s in sections(mbody):
        if clean(s):
            print(f'   {h[:62]:62s} {clean(s):5d}')
    print('Legends (limit 350 each):')
    for n, (kind, f) in legends + [('methods.tex', x) for x in mfloats]:
        lab = re.search(re.escape(BS) + r'label\{([^}]*)\}', f)
        cap = f.split(BS + 'caption', 1)
        w = clean(cap[1]) if len(cap) > 1 else 0
        flag = '  OVER' if w > 350 else ''
        print(f'   {kind:6s} {(lab.group(1) if lab else "?"):28s} {w:5d}{flag}')
    sbody, sfloats = split_floats(rd('supplementary.tex'))
    print(f'{"Supplementary text outside floats":46s} {clean(sbody):6d}')
    print(f'Main display items: {sum(1 for _, (k, _f) in legends)} in Results/Discussion + {len(mfloats)} in Methods (limit 10)')


if __name__ == '__main__':
    main()
