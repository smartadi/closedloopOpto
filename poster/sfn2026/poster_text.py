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
    prs.save(dst)
    print(dst)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
