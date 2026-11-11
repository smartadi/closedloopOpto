"""poster_text.py -- sentences Aditya rewrote, swapped in by exact match (SfN poster, from v8, 2026-11-11).

    python poster/sfn2026/poster_text.py <in.pptx> <out.pptx>

Run after carry_edits.py. Each entry replaces one whole paragraph whose text equals OLD; the script stops if
OLD is not found exactly once (so it never edits a sentence that has changed since). The paragraph keeps the
formatting of its first run. Only his words go here; suggested rewordings stay in chat until he picks one.
"""
import sys

from pptx import Presentation

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
    ('introduction', 'Wide ranging', 'Wide-ranging'),
]


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
    print(dst)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
