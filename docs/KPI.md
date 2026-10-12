# Sirens — Weekly KPI Scoreboard

Team: Elie Boutros, Bassam Eter (one team, no individual feature ownership)
Capacity: ~10 h/week total
Start: week of 2026-10-12 · Deadline: end of month (exact date TBC)
Deliverable: live demo + written report + code

**Rules:** each session states this week's KPI, works only on it, and ends by
ticking what is done. Cut-line: defer the lowest item rather than extend into
week 4. Only tick an item when it has been verified (pasted output or a
working check), not just "edited".

Status: [x] done (verified) · [~] in progress · [ ] not started

## W1 — Foundation
- [~] Feature branch pushed (`bassam/w1-foundation` on fork, draft PR open). Done once Elie reviews.
- [x] `.gitignore` excludes `data/sirens.db*`, `.venv`, `venv`, `__pycache__`, `data/photos/`.
  Evidence 2026-10-12: `git check-ignore -v` matches all of them; the committed
  `venv/` (7,969 files) is no longer tracked; `git ls-files venv | wc -l` = 0.
- [~] Fresh clone runs from README in <= 10 min. Evidence 2026-10-12 (cloud
  machine, not the real test): fresh clone, `bash setup.sh`, `python app.py`,
  demo data loaded in 45 s. Still needed: timed run on a second laptop.
- [x] Demo-mode button loads sample data. Evidence: `/demo` page, "Load demo
  data (fabricated)" button; `tests/test_demo.py` passes (temp DB, 40
  incidents); clicked in a headless browser: "40 in database".
- [~] htmx + Chart.js load from `static/vendor/` with network off. Evidence:
  `/vendor-check` in headless Chromium with every non-127.0.0.1 request
  blocked: htmx 2.0.11 and Chart.js 4.5.1 detected, chart drawn, htmx swap
  works, zero external requests; `tests/test_vendor.py` passes (no external
  script/stylesheet in any template). Still needed: open it with Wi-Fi off.
- [x] DB tables for link decisions and notes exist (`linker/decisions.py`).
  Evidence: `python -m linker.decisions` ends with `SELF-CHECK PASSED`;
  `tests/test_decisions.py` passes.

## W2 — Analyst workbench
- [ ] Confirm / Reject / Unsure on every link, no page reload
- [ ] Decisions + notes persist across restart
- [ ] Scripted 10-click test: zero server errors

## W3 — Dashboard + auto-flagging
- [ ] Timeline chart + 2 more charts + working filters
- [ ] Saving a report shows its likely network with band + reasons (first to defer)

## W4 — Freeze / polish / deliver
- [ ] Tooltips on all form fields
- [ ] Regression test fails if F1 < 0.73
- [ ] README with screenshots
- [ ] Written report, first draft
- [ ] Deck updated
- [ ] Full demo rehearsal with the model pre-loaded
- Stretch: CSV/JSON import · live threshold slider · completeness badge

## Measured accuracy (only numbers we actually measured)
| Date | Data | Threshold | P | R | F1 |
|---|---|---|---|---|---|
| (before W1) | 100 synthetic, seed 7 | 0.25 | 0.628 | 0.888 | 0.736 |
| 2026-10-12 | 100 synthetic, seed 7 | 0.25 | 0.628 | 0.888 | 0.736 |

Target: P 0.90 / R 0.80 / F1 0.85.

## Open items to verify on Elie's laptop
- BEFORE pulling: back up the local DB (`cp data/sirens.db data/sirens.db.bak`).
- Pulling commit 828e3ec deletes the old `venv/` folder from disk (it is no
  longer tracked). That is expected: run `bash setup.sh` to get `.venv/`.
- GitHub already has `debug=False`, the width / watermark / checkbox CSS and
  the brief "Incidents on record here" list; `tests/` exists. Check whether
  any newer unpushed edits differ, then merge them (app.py changed by only 3
  lines on this branch: 2 Blueprint registrations, 1 nav link).
- Open `/vendor-check` with Wi-Fi off; both rows must say "ok".
- Check the AI panels with Ollama running (not testable in the cloud session).
- Not fixed (outside W1, decide later): root `cli.py` has a SyntaxError on
  line 1 (README "Use" section relies on it); `anthropic` is in
  requirements.txt but never imported; `data/generated/` is tracked.

## Session log
- 2026-10-12 (Bassam, browser): forked repo, created branch, fixed
  `.gitignore`, untracked `sirens.db`, added this scoreboard.
    Also: vendored htmx 2.0.11 + Chart.js 4.5.1; added linker/decisions.py
  (written in browser, NOT yet run: verify with `python -m linker.decisions`).
- 2026-10-12 (Bassam + Claude Code, cloud session): ran everything for the
  first time. Install from README: 37 s. Decisions self-check passed. Pages
  `/`, `/map`, `/tree`, `/brief` return 200; no crash without Ollama.
  Accuracy re-measured: identical to baseline (table above).
  Changed: untracked committed `venv/` and fixed ignore rules; removed
  leftover `import_500.py`, `load_500.py`, `data/consolidated_incidents.json`;
  added `/vendor-check` (vendor_bp.py) and `/demo` (demo_bp.py) Blueprints;
  added tests (21 pass, temp DB only); fixed README/setup.sh install steps.
  Still unverified: Wi-Fi-off test, timed second-machine install, AI with
  Ollama. Elie: see "Open items" above.
