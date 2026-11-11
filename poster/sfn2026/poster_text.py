"""poster_text.py -- sentences Aditya rewrote, swapped in by exact match (SfN poster, from v8, 2026-11-11).

    python poster/sfn2026/poster_text.py <in.pptx> <out.pptx>

Run after carry_edits.py. Each entry replaces one whole paragraph whose text equals OLD; the script stops if
OLD is not found exactly once (so it never edits a sentence that has changed since). The paragraph keeps the
formatting of its first run. Only his words go here; suggested rewordings stay in chat until he picks one.
"""
import copy
import sys

from pptx import Presentation
from pptx.oxml.ns import qn
from pptx.util import Emu, Inches, Pt

from poster_resize import measure

SWAPS = [
    # box 7, third bullet. Aditya 2026-11-11: "change this sentence(One explanation: opsin and indicator
    # kinetics and loop delay limit the controllable frequencies.) to: frequency composition limits
    # stabilizability of a state due to system limits owing to opsin kinetics."
    ('box 7 bullets',
     'One explanation: opsin and indicator kinetics and loop delay limit the controllable frequencies.',
     'Frequency composition limits stabilizability of a state due to system limits owing to opsin kinetics.'),
]

# Typos and punctuation in his sentences, fixed inside one run so bold words stay bold. Aditya 2026-11-11,
# after the independent review: "also add your recommended changes". (shape, old, new): old must occur
# exactly once in the shape, inside a single run.
FIXES = [
    ('conclusions', 'control', 'controls'),                       # "a controller that control local ..."
    ('conclusions', 'model informed', 'model-informed'),
    ('box 6 heading', 'error.', 'error'),                         # the only heading ending in a period
    ('box 6 bullets', 'explains a the most', 'explains the most'),
    ('box 6 bullets', 'in proportion to other states', 'in proportion to other states.'),
]

# The Introduction, Aditya's own text (2026-11-11, "new intro:"), one bullet per paragraph, verbatim. The last
# bullet is the old last paragraph word for word, so it stays as it was (bold); the others replace the first
# three paragraphs in their style (not bold). At 29 pt it ran 18 lines and column 1 no longer fit at 48 in,
# so (his pick, 2026-11-11: "A: Intro 26 pt") its type is INTRO_PT with line spacing and the space between
# paragraphs scaled by the same ratio, so it reads like the other boxes, only smaller (15 lines). The frame
# grows to the text in poster_resize.py, and column 1 refits in poster_box2_48.py.
INTRO_PT = 26.0
INTRO = [
    'Mesoscale cortical activity is coordinated across areas (spirals, travelling waves) and tracks ongoing '
    'behavior: locomotion, whisking, grooming and eye movements can be decoded from widefield activity.',
    'Testing whether these dynamics cause perception and behavior requires perturbing them, but most '
    'perturbations are open loop. A fixed light pulse adds to ongoing, state-dependent activity, so the actual '
    'change in activity varies across trials and brain states.',
    'Closed-loop feedback instead controls activity to a chosen target despite ongoing fluctuations, making '
    'activity, not light, the experimental variable.',
    'Closed-loop stimulation is also used clinically (responsive neurostimulation for epilepsy, adaptive DBS for '
    'Parkinson’s), so knowing when feedback can and cannot regulate cortical activity matters for therapy '
    'design.',
    'Whether feedback can control mesoscale activity, and what limits it, is not known.',
    'We used real-time imaging and optogenetics to control activity at a cortical site at a target level, and '
    'analyzed the conditions under which it succeeds.',
]


def set_intro(shape):
    """Replace the Introduction's paragraphs with INTRO. New paragraphs copy the old second paragraph (bullet,
    indent, space before, one plain run); the first keeps the old first paragraph's settings (no space before)."""
    ps = shape.text_frame.paragraphs
    if ps[-1].text != INTRO[-1]:
        raise SystemExit(f'introduction: last paragraph reads {ps[-1].text!r}, not his last bullet')
    first, plain, last = ps[0]._p, ps[1]._p, ps[-1]._p
    made = []
    for j, text in enumerate(INTRO[:-1]):
        p = copy.deepcopy(plain)
        if j == 0:
            p.remove(p.pPr)
            p.insert(0, copy.deepcopy(first.pPr))
        runs = p.findall(qn('a:r'))
        for r in runs[1:]:
            p.remove(r)
        runs[0].find(qn('a:t')).text = text
        made.append(p)
    for p in ps[:-1]:
        p._p.getparent().remove(p._p)
    for p in made:
        last.addprevious(p)
    sizes = {r.font.size.pt for p in shape.text_frame.paragraphs for r in p.runs}
    if len(sizes) != 1:
        raise SystemExit(f'introduction: type sizes {sizes}, expected one')
    f = INTRO_PT / sizes.pop()
    for p in shape.text_frame.paragraphs:
        for r in p.runs:
            r.font.size = Pt(INTRO_PT)
        for tag in ('a:lnSpc', 'a:spcBef'):
            el = p._p.pPr.find(qn(tag))
            pts = None if el is None else el.find(qn('a:spcPts'))
            if pts is not None:
                pts.set('val', str(round(int(pts.get('val')) * f)))
    print(f'introduction: {len(INTRO)} paragraphs, his text; type {INTRO_PT} pt, spacing x{f:.4f}')


def main(src, dst):
    prs = Presentation(src)
    by = {sh.name: sh for sh in prs.slides[0].shapes}
    for name, old, new in SWAPS:
        hits = [p for p in by[name].text_frame.paragraphs if p.text == old]
        if len(hits) != 1:
            raise SystemExit(f'{name}: {len(hits)} paragraphs read {old!r}')
        runs = hits[0].runs
        runs[0].text = new
        for r in runs[1:]:
            r._r.getparent().remove(r._r)
        print(f'{name}: {new!r}')
    h0 = measure(src, {'introduction'})['introduction']             # PowerPoint's text height, in
    set_intro(by['introduction'])
    for name, old, new in FIXES:
        runs = [r for p in by[name].text_frame.paragraphs for r in p.runs]
        if old == 'error.':                                       # the heading's period is a run of its own
            hits = [(i, r) for i, r in enumerate(runs) if r.text.startswith('.') and i > 0
                    and runs[i - 1].text.rstrip('  ').endswith('error')]
            if len(hits) != 1:
                raise SystemExit(f'{name}: {len(hits)} periods after "error"')
            hits[0][1].text = hits[0][1].text[1:]
            print(f'{name}: final period removed')
            continue
        hits = [r for r in runs if (r.text == old if old == 'control' else old in r.text)]
        n = sum(r.text.count(old) for r in hits) if old != 'control' else len(hits)
        if n != 1:
            raise SystemExit(f'{name}: {n} runs read {old!r}')
        hits[0].text = new if old == 'control' else hits[0].text.replace(old, new)
        print(f'{name}: {old!r} -> {new!r}')
    prs.save(dst)
    # the frame and text box grow by the text's change in height, so the frame keeps its padding
    # (poster_resize.py later refits it with that padding at the new width)
    dh = measure(dst, {'introduction'})['introduction'] - h0
    for n in ('introduction', 'introduction frame'):
        by[n].height = Emu(int(by[n].height + Inches(dh)))
    prs.save(dst)
    print(f'introduction: text {h0:.2f} -> {h0 + dh:.2f} in, frame {dh:+.2f} in')
    print(dst)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
