"""talk_script.py -- the 5-minute poster walkthrough on one US Letter page, for printing.

    python poster/sfn2026/talk_script.py

Writes poster/sfn2026/talk_script.pdf (git-ignored). Arial is embedded. The body font shrinks in 0.25 pt
steps from 11 pt until the whole page fits; main() refuses below 8.5 pt. Text = the 5-minute version from
2026-11-05, with the corrected close ("one likely limit is how fast the loop can respond"), plus short
answers for questions. Numbers are the ones on the poster.
"""
from pathlib import Path

import fitz

OUT = Path(__file__).resolve().parent / 'talk_script.pdf'
FONTS = 'C:/Windows/Fonts'
MARGIN = 0.42 * 72

SECTIONS = [
    ('0:00', 'Intro', 'Most optogenetic experiments are open loop. You choose a stimulus in advance, deliver it, and average over '
     'whatever the brain happened to be doing. But cortex is never in the same state twice, so the same light gives a different '
     'result on every trial. We asked a simple question: can feedback hold cortical activity at a level we choose, and if it '
     'can, what limits it?'),
    ('0:30', '1 · The loop', '<i>[rig]</i> The mice express GCaMP8s in excitatory neurons and the opsin ChrimsonR in inhibitory '
     'interneurons, so red light on a spot turns local excitatory activity down. We image the whole dorsal cortex with wide-field '
     'calcium imaging and read ΔF/F at the stimulated spot. <i>[frame]</i> A PI controller compares that signal to a target and '
     'updates the laser power 35 times a second. <i>[loop]</i> The mice are awake and head-fixed, with no task.'),
    ('1:00', '2 · Is it controllable?', 'Before you can control a system, it has to be predictable. <i>[traces]</i> Short '
     'open-loop pulses give a clean suppression that scales with laser power. A low-order linear model predicts held-out '
     'trials, with R<sup>2</sup> from 0.56 at the lowest power to 0.98 at the highest. <i>[fit]</i> But single trials vary, and '
     'that depends on brain state. <i>[state panel]</i> Variability falls at the highest levels of movement and rises with '
     '2–4 Hz power, with or without stimulation. The average is simple but single trials aren’t, and that’s exactly where '
     'feedback should help.'),
    ('1:40', '3 · It works', '<i>[example trials]</i> Open loop on the left, closed loop on the right, target 5% below baseline. '
     'Open-loop light is fixed, so activity drifts away from the target. The controller keeps adjusting and stays close. '
     '<i>[ratio plots]</i> Across 15 sessions in 4 mice, closed loop lowers the error by 23% in every session, and '
     'trial-to-trial variability by 42%.'),
    ('2:15', '4 · Moving target', 'We also asked it to follow a 1 Hz sine wave. <i>[four traces]</i> Feedback reduces the error '
     'compared with open loop, but it lags behind the target, because it can only react once an error appears. Adding preview, '
     'which uses the model to tell the controller what the target is about to need, removes most of that lag. '
     '<i>[phase-lag bars]</i>'),
    ('2:45', '5 · What feedback does to the site', '<i>[maps]</i> Each dot is a point on cortex; its colour shows how its '
     'correlation with the site changed during stimulation. Teal means less correlated. Before stimulation the site rises and '
     'falls with the rest of cortex, correlation about 0.74. During closed loop that drops to about 0.59, in all 12 sessions, '
     'across the whole cortex. Open loop barely changes it. Open-loop light is the same on every trial, so it can’t cancel '
     'fluctuations that differ from trial to trial. The controller’s light can, so the site stops following the rest of cortex.'),
    ('3:25', '6 · What explains the remaining error', 'So the controller works; why isn’t it perfect? <i>[example trials]</i> We '
     'looked at four things that might make a trial hard: how far the site started from the target, movement, and two measures '
     'of delta-band power. <i>[R<sup>2</sup> plot]</i> Each bar is how much of the remaining error that variable explains on its '
     'own. In the first second, the starting deviation explains about half; after that almost nothing, because the controller '
     'has corrected it. Absolute 1–4 Hz power explains a smaller part, about a tenth, but it’s the largest factor once the '
     'controller has settled.'),
    ('3:55', '7 · Error across brain states', '<i>[quartiles: open loop red, closed loop blue]</i> Movement makes open-loop '
     'error worse, but closed-loop error stays flat, so during movement feedback removes more of the error. Delta power is '
     'different: closed-loop error rises about as much as open-loop error. One explanation is speed: the opsin, the calcium '
     'indicator and the loop delay limit how fast the controller can respond, so faster fluctuations get through.'),
    ('4:25', '8 · Disturbance from the other hemisphere', '<i>[kernel map]</i> A linear model fit on laser-off frames predicts '
     'the site from the opposite hemisphere, R<sup>2</sup> 0.75 in this example. <i>[rejection ratios]</i> Closed loop rejects '
     'part of that predicted disturbance: most of the steady offset, less of the faster fluctuations, which fits the same '
     'speed limit.'),
    ('4:50', 'Close', 'A near-linear average response is enough to design a controller that holds a cortical site at a target, '
     'better than open loop in every session and mouse. How well it works depends on brain state, and one likely limit is how '
     'fast the loop can respond. Happy to go into any part in more detail.'),
]

QA = [
    ('Is the drop in correlation just the laser cutting inputs?', 'No. Subtract the laser’s own contribution and the '
     'correlation comes back: cortex still drives the site, and the feedback cancels it.'),
    ('How many mice?', 'Controller: 15 sessions, 4 mice. Correlation box: 12 sessions from 2 of them. Moving target: one '
     'session, one mouse.'),
    ('Why an inhibitory opsin?', 'ChrimsonR in inhibitory interneurons suppresses local excitatory activity, so targets sit '
     'below baseline.'),
    ('Why two ΔF/F definitions?', 'The controller estimated its baseline online from the past 40 s, so we analyse the signal '
     'it fed back on. The open-loop impulse data use the session mean.'),
    ('Blood-flow artefacts?', 'The main expected objection: have your own answer ready.'),
]


def html():
    s = ['<h1>Poster walkthrough · 5 minutes</h1>',
         '<p class="sub">SfN 2026 · Controlling cortex in real time: state-dependent limits of closed-loop optogenetic '
         'regulation · <i>[brackets]</i> = point to</p>']
    for t, head, body in SECTIONS:
        s.append(f'<p class="sec"><b><span class="t">{t}</span>  {head}</b></p><p class="body">{body}</p>')
    s.append('<p class="qah"><b>If asked</b></p>')
    for q, a in QA:
        s.append(f'<p class="qa"><b>{q}</b> {a}</p>')
    return '\n'.join(s)


def css(fs):
    return f"""
    @font-face {{font-family: A; src: url(arial.ttf);}}
    @font-face {{font-family: A; src: url(arialbd.ttf); font-weight: bold;}}
    @font-face {{font-family: A; src: url(ariali.ttf); font-style: italic;}}
    @font-face {{font-family: A; src: url(arialbi.ttf); font-weight: bold; font-style: italic;}}
    * {{font-family: A;}}
    h1 {{font-size: {fs + 4}pt; color: #4B2E83; margin: 0 0 2pt 0;}}
    p {{margin: 0; line-height: 1.2;}}
    p.sub {{font-size: {fs - 1.5}pt; color: #555555; margin-bottom: {fs * 0.3}pt;}}
    p.sec {{font-size: {fs}pt; color: #4B2E83; margin-top: {fs * 0.45}pt;}}
    span.t {{color: #85754D;}}
    p.body {{font-size: {fs}pt;}}
    i {{color: #777777;}}
    p.qah {{font-size: {fs}pt; color: #4B2E83; margin-top: {fs * 0.9}pt; border-top: 0.6pt solid #B7A57A; padding-top: 3pt;}}
    p.qa {{font-size: {fs - 1.5}pt; margin-top: 1.5pt;}}
    """


def fits(fs):
    st = fitz.Story(html=html(), user_css=css(fs), archive=fitz.Archive(FONTS))
    page = fitz.paper_rect('letter')
    more, filled = st.place(page + (MARGIN, MARGIN, -MARGIN, -MARGIN))
    return not more, filled


def main():
    fs = 11.0
    while not fits(fs)[0]:
        fs -= 0.25
        assert fs >= 8.5, 'script does not fit one page at 8.5 pt'
    page = fitz.paper_rect('letter')
    st = fitz.Story(html=html(), user_css=css(fs), archive=fitz.Archive(FONTS))
    w = fitz.DocumentWriter(str(OUT))
    dev = w.begin_page(page)
    more, filled = st.place(page + (MARGIN, MARGIN, -MARGIN, -MARGIN))
    st.draw(dev)
    w.end_page()
    w.close()
    assert not more
    d = fitz.open(str(OUT))
    d.set_metadata({'title': 'SfN 2026 poster walkthrough, 5 minutes', 'author': 'Aditya Deole'})
    d.saveIncr()
    print(f'{OUT}: {d.page_count} page, body {fs:.2f} pt, text ends {(page.y1 - MARGIN - fitz.Rect(filled).y1) / 72:.2f} in above '
          f'the bottom margin')


if __name__ == '__main__':
    main()
