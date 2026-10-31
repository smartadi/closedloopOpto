# NC voice: a Nature paper (Nick's notes are advice)

Aditya, 2026-10-31: "we dont want to emulate Nick but we want to use it as advice and write in more of a
nature paper". Applies to the NC draft (`Closedloop_nc`); first applied in NC f0e01d7..5a955c7.
`STYLE_NICK.md` stays as advice: its sentence rules (literal verbs, "target level", past tense for what we
did or saw, hedge interpretations not observations, no colon reveals, no decorative clauses, claims on the
robust test) still hold. Its marker-word table and his intro constructions are not targets.

## Structure
- **Title:** at most 15 words; says the advance in plain words.
- **Abstract (at most 200 words):** a Nature summary paragraph. Context any scientist follows → the problem →
  "Here we show" → approach in one clause → findings in past tense, with n → what they show (present tense)
  → one sentence on broader use.
- **Introduction (~1,000 words):** problem and why it matters → what closed loop has done and where the gap
  is → open questions as statements ("The first is whether …"), never as direct questions → a "Here we …"
  paragraph with approach, findings in past tense and the conclusion.
- **Results:** subheadings are short declarative findings in present tense. Each paragraph opens with its
  finding or its purpose ("To test whether …, we …"). Give only the method needed to read the result; fit
  details, model orders and robustness checks go to Methods or Supplementary.
- **Discussion:** summary of the findings → one block per claim (interpretation + literature) → limitations
  → use → "In summary". No subheadings.
- **Legends:** the bold title sentence states the finding; at most 350 words; n, test and error-bar
  definition for each panel; numbers that carry a claim belong in the text, not only the legend.

## Sentences
- Numbers in parentheses with n and the test: (ratio 0.77, p = 5.8e-8; 15 sessions, four mice).
- Define a control term once in plain words, then use it (feedforward, disturbance, internal model principle).
- No "novel", "unprecedented" or bare priority claims; "to our knowledge" when priority matters.
- One sentence per line in the .tex files.

## Budget (nature.com/ncomms/submit/article, checked 2026-10-29)
Title at most 15 words · abstract at most 200 · main text ~5,000 · Methods typically under 3,000 · legends at
most 350 each · at most 10 display items · ~70 references. `nc_wordcount.py <draft>` measures all of these.
