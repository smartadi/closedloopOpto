"""nc_style.py -- convert manuscript LaTeX from the JNeurosci draft's conventions to Nature Comms style.

Run it on the Nature Comms draft (projects/Closedloop_nc). It is idempotent, so it can be re-run after
any file is regenerated or copied over from the JNeurosci draft. The main case is stat_tables.tex, which
paper_stats_tex.m always writes in JNeurosci style:

    python paper-writing/nc_style.py ../Closedloop_nc            # dry run: counts per rule and file
    python paper-writing/nc_style.py ../Closedloop_nc --apply    # rewrite the files in place

Rules (Nature Comms / Nature figure guide, checked 2026-10-29):
  1. Figure refs -> "Fig.~\\ref{..}a" / "Figs.~", lowercase panel letters; labels defined in
     supplementary.tex become "Supplementary Fig.".
  2. Table refs to tables defined in supplementary.tex or stat_tables.tex -> "Supplementary Table".
  3. Caption panel tokens \\textbf{A:} -> \\textbf{a}, and \\textbf{B} -> \\textbf{b} (results, supplementary).
  4. Equation refs -> "equation~\\eqref{..}" (Nature: refer to equations as "equation (1)").
  5. "Materials and Methods" -> "Methods".
Plain-text panel letters ("panel H", "(as in F)") are NOT converted; the dry run lists them for hand edits.
Files are CRLF; line endings are preserved.
"""
import re
import sys
from pathlib import Path

BS = '\\'
FILES = ['introduction.tex', 'results.tex', 'discussion.tex', 'methods.tex',
         'supplementary.tex', 'stat_tables.tex', 'main.tex']
CAPTION_FILES = {'results.tex', 'supplementary.tex'}

LET = r'[A-Z](?![A-Za-z])'
RANGE = LET + r'(?:(?:--|–|-)' + LET + r')?'
PANELS = RANGE + r'(?:(?:,\s?|\s(?:and|or)\s|,\s(?:and|or)\s)' + RANGE + r')*'
REF = re.escape(BS + 'ref{')

fig_word = re.compile(r'(?P<pre>Supplementary\s+)?(?P<word>Figures|Figure|Figs\.|Fig\.)~' + REF
                      + r'(?P<lab>fig:[^}]+)\}(?P<suf>' + PANELS + r')?')
bare_fig = re.compile(r'(?P<head>' + REF + r'fig:[^}]+\})(?P<suf>' + PANELS + r')')
tab_word = re.compile(r'(?P<pre>Supplementary\s+)?(?P<word>Tables|Table)~' + REF + r'(?P<lab>tab:[^}]+)\}')
cap_tok = re.compile(re.escape(BS + 'textbf{') + r'(?P<tok>[A-Z](?:(?:--|,\s?)[A-Z])*)(?P<colon>:?)\}')
eq_ref = re.compile(r'(?P<word>Eqs\.|Eq\.|Equations|Equation)~' + re.escape(BS) + r'(?:eq)?ref\{(?P<lab>eq:[^}]+)\}')
mam = re.compile(r'Materials and Methods')
leftover = re.compile(r'(panels?~?\s' + LET + r'|\(as in ' + LET + r'\)|\bin ' + LET + r'(?=[,.;)]))')


def labels(root, names, kind):
    out = set()
    for n in names:
        p = root / n
        if p.exists():
            out |= set(re.findall(re.escape(BS + 'label{') + '(' + kind + r':[^}]+)\}', p.read_text(encoding='utf-8')))
    return out


def convert(text, fname, supp_fig, supp_tab, counts):
    def bump(rule, n=1):
        counts[rule] = counts.get(rule, 0) + n

    def f_fig(m):
        plural = m.group('word') in ('Figures', 'Figs.')
        word = 'Figs.' if plural else 'Fig.'
        pre = 'Supplementary ' if (m.group('pre') or m.group('lab') in supp_fig) else ''
        suf = (m.group('suf') or '').lower()
        new = pre + word + '~' + BS + 'ref{' + m.group('lab') + '}' + suf
        if new != m.group(0):
            bump('1 figure refs')
        return new

    def f_bare(m):
        new = m.group('head') + m.group('suf').lower()
        if new != m.group(0):
            bump('1b list refs')
        return new

    def f_tab(m):
        if m.group('pre') or m.group('lab') not in supp_tab:
            return m.group(0)
        bump('2 supp table refs')
        return 'Supplementary ' + m.group('word') + '~' + BS + 'ref{' + m.group('lab') + '}'

    def f_cap(m):
        bump('3 caption panel letters')
        return BS + 'textbf{' + m.group('tok').lower() + '}' + (',' if m.group('colon') else '')

    def f_eq(m):
        w = m.group('word')
        word = {'Eqs.': 'equations', 'Eq.': 'equation', 'Equations': 'Equations', 'Equation': 'Equation'}[w]
        new = word + '~' + BS + 'eqref{' + m.group('lab') + '}'
        if new != m.group(0):
            bump('4 equation refs')
        return new

    def f_mam(m):
        bump('5 Materials and Methods')
        return 'Methods'

    out = []
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith('%'):
            out.append(line)
            continue
        line = fig_word.sub(f_fig, line)
        line = bare_fig.sub(f_bare, line)
        line = tab_word.sub(f_tab, line)
        if fname in CAPTION_FILES:
            line = cap_tok.sub(f_cap, line)
        line = eq_ref.sub(f_eq, line)
        line = mam.sub(f_mam, line)
        out.append(line)
    return ''.join(out)


def main():
    root = Path(sys.argv[1])
    apply = '--apply' in sys.argv
    supp_fig = labels(root, ['supplementary.tex'], 'fig')
    supp_tab = labels(root, ['supplementary.tex', 'stat_tables.tex'], 'tab')
    print('supplementary figures:', sorted(supp_fig))
    print('supplementary tables :', sorted(supp_tab))
    for n in FILES:
        p = root / n
        if not p.exists():
            continue
        with open(p, encoding='utf-8', newline='') as fh:
            text = fh.read()
        counts = {}
        new = convert(text, n, supp_fig, supp_tab, counts)
        left = [(i + 1, l.strip()[:110]) for i, l in enumerate(new.splitlines())
                if not l.lstrip().startswith('%') and leftover.search(l)]
        print(f'{n:20s} {counts if counts else "no change"}')
        for i, l in left:
            print(f'    plain panel letter, line {i}: {l}')
        if apply and new != text:
            with open(p, 'w', encoding='utf-8', newline='') as fh:
                fh.write(new)
    print('APPLIED' if apply else 'dry run (add --apply to write)')


if __name__ == '__main__':
    main()
