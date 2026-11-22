# Bar elements — execution ledger

Plan: `docs/bar-elements-plan.md` (agreed 2026-11-21). This file tracks who does
what, in which worktree, and in which order it merges. It is not committed.

## Strategy

The plan says "one step at a time, committed on its own"; the user asked for
parallel work with Claude and OpenCode. Both hold if we run **waves**:

- Every step gets **its own child worktree**, branched from `master`.
- Steps merge back **in plan order** (0 → 16). A worker whose step is next
  rebases on `master` before committing if its base is stale.
- The hot shared files (`bar/widgets.js`, `vitrail/prefs.map`,
  `shell/Prefs.qml`, `shell/main.qml`, `kit/i18n/*.json`, `packages/*.txt`,
  `tests/test_dependencies.py`, `docs/features.md`,
  `docs/manual-checks.md`) get **additive edits only**: one line per entry,
  inside the existing block for that family, never a reorder. That keeps the
  merges conflict-free.
- Step 0 is the blocker: every other element builds its button on the
  `BarElement` base. Nothing that touches QML fans out until it lands.
- Work that does not touch QML (Python snapshot providers + their tests, new
  files only) runs in parallel from the start.

## Owners

| Who | Gets |
| --- | --- |
| Claude `claude-sonnet-5-5` | the hardest steps: base architecture, PipeWire streams, clock group, sampler/graphs, privacy, system health |
| OpenCode worker | the mechanical steps: reusing existing modules, Python providers, forms and lists |

## Prerequisites

- `master` has unrelated uncommitted work (capture editor, monitors). Workers
  never touch it, and nothing merges into those files.
- `docs/bar-elements-plan.md` is untracked, so each spec quotes its step.
- Open questions gate steps 2, 3, 10 and 16 (see below).

## Wave 1 (running)

| Step | Task | Owner | Worktree | Status |
| --- | --- | --- | --- | --- |
| 0 | Foundation: `BarElement`, popup host, "only while active", Python snapshot pattern, settings section, sample element | Claude sonnet 4.6 | `bar-foundation` | dispatched |
| 1a | `vitrail/audio.py` snapshot provider + `tests/test_audio.py` (new files only) | OpenCode | `bar-volume-data` | retried after an OpenCode auth failure |
| 10a | `vitrail/updates.py` (official/AUR/Flatpak) + tests, new files only | OpenCode | `bar-updates-data` | dispatched |
| 12a | `vitrail/disks.py` (removable drives, udisksctl) + tests, new files only | OpenCode | `bar-disks-data` | dispatched |
| 14a | `vitrail/battery.py` (UPower peripherals) + tests | OpenCode | `bar-battery-data` | **done, `5f94eb3`, 1190 tests OK** |

## Wave 2+ (queued)

| Step | Task | Owner | Notes |
| --- | --- | --- | --- |
| 1b | Volume button + popup (master, per-app streams, devices, mic mute) | Claude | needs 0 and 1a |
| 2 | Brightness + night light (`hyprsunset`) | OpenCode | needs 0; open question 4 |
| 3 | Clock with grouped popup | Claude | needs 0; open question 1 |
| 4 | Resources + network usage, shared sampler | Claude | needs 0 |
| 5 | Weather | OpenCode | needs 0 |
| 6 | Pomodoro/timer + notes | OpenCode | needs 0 |
| 7 | Privacy | Claude | needs 0 |
| 8 | DND/focus + caffeine | OpenCode | needs 0 |
| 9 | Clipboard + colour picker | OpenCode | needs 0 |
| 10 | Updates | OpenCode | needs 0; open question 2 |
| 11 | Downloads | OpenCode | needs 0 |
| 12 | Disks | OpenCode | needs 0 |
| 13 | System health | Claude | needs 0 |
| 14 | Peripherals battery | OpenCode | needs 0 |
| 15 | Containers | OpenCode | needs 0 |
| 16 | Crypto/stocks | Claude | needs 0; open question 3 |

## Wave 2 (running)

| Step | Task | Owner | Worktree | Status |
| --- | --- | --- | --- | --- |
| 2a | `vitrail/nightlight.py` (hyprsunset, schedule, plan()) | OpenCode flash | `bar-nightlight-data` | dispatched |
| 13a | `vitrail/health.py` (services, disk, hyprctl, doctor) | OpenCode flash | `bar-health-data` | dispatched |
| 15a | `vitrail/containers.py` (docker/podman, optional) | OpenCode flash | `bar-containers-data` | dispatched |
| 16a | `vitrail/market.py` (CoinGecko, cache) | OpenCode flash | `bar-market-data` | dispatched |

Waiting on step 0's review before the UI halves of steps 1, 10, 12 and 14:
they need the merged `BarElementBase`.

## Housekeeping

Finished workers are released as soon as their task is verified
(`orchestration worker-release`), so Orca does not keep their windows open.

## Verification policy

**A task is only committed when it is complete and its tests pass.** When a
worker reports `worker_done`:

1. read its report and `git show --stat` in its worktree;
2. run the worktree's own test file, then the whole suite
   (`uv run python -m unittest discover -s tests`) and `ruff`;
3. if the tree is clean and green, the worker's commit stands (I amend only a
   wrong message); if it left work uncommitted, I commit it with a
   conventional message;
4. if something fails, the worker gets the failure back before any commit.

Every step that Claude writes is reviewed by a **second Claude worker on
`claude-sonnet-5-5`** before it merges: it reads the diff, runs the step's own
tests plus the enforced ones (`test_design_system`, `test_prefs_map`,
`test_tooltips`, `test_dependencies`, `test_i18n`, `qml_smoke.sh`), checks the
"Every element ships with" contract, and **fixes what it finds** in the same
worktree (a follow-up commit; the branch is squashed into one commit at
merge). This applies first to step 0 (written by `claude-sonnet-4-6`).

Steps merge into `master` in plan order, one commit per step, once the step's
data and UI halves are both green.

## Open questions (from the plan)

1. Calendar events (step 3): none, local ICS, or CalDAV?
2. Updates (step 10): notify, or counter only?
3. Crypto/stocks (step 16): provider and API key?
4. Night light (step 2): is `hyprsunset` acceptable? (already installed here)

## Log

- 2026-11-21: wave 1 dispatched (step 0 → Claude, step 1a → OpenCode).
- 2026-11-21: OpenCode workers now run `opencode-go/deepseek-v4.1-flash`
  (`--model` needs an existing worktree first: `worktree create`, then
  `worker-start --worktree path:…`). The three workers already dispatched keep
  the CLI default; new ones use deepseek flash.
- 2026-11-21: Claude workers now run `claude-sonnet-5-5`. The step 0 worker
  already in flight keeps `claude-sonnet-4-6` (it is mid-task with 15 files
  touched); every later Claude dispatch uses 5.5.

## Answers (2026-11-21)

1. Calendar (step 3): events come from a calendar stack installed for this,
   with Microsoft/Google sign-in, and the **popup shows them** (not just a
   button to the app). Decision: GNOME Calendar as the frontend and
   Evolution Data Server (`evolution-data-server`, `evolution-ews`,
   `gnome-online-accounts`) as the source — the only Linux stack with
   first-class Google/Microsoft OAuth. A small `vitrail/calendar.py` reads the
   events over EDS and the popup renders them in Vitrail style, so the visible
   UI stays ours. Declare all three packages when step 3 runs.
2. Updates (step 10): counter **and** a notification when new packages appear.
3. Crypto/stocks (step 16): CoinGecko, public endpoint, no API key.
4. Night light (step 2): `hyprsunset` approved (already installed here).
- 2026-11-21: the three OpenCode workers died at startup with "Sign in to
  OpenCode / Permission denied on the service" and their `new-child` worktrees
  were never created. Relaunched on `opencode-go/deepseek-v4.1-flash` after
  creating `bar-volume-data`, `bar-updates-data`, `bar-disks-data` by hand.
  Working launch pattern: `worktree create` then
  `worker-start --worktree path:<dir> --model opencode-go/deepseek-v4.1-flash`.
- 2026-11-21: user asked for step 0 to be verified by Sonnet 5.5 when the
  4.6 worker finishes, fixing whatever it finds (see Verification policy).
- 2026-11-21: all five workers succeeded with their own commits and clean trees.
  Verified here: foundation `9bafd99` (1174 tests OK, `qml_smoke.sh` 123/123),
  volume `ed91ea5` (1189 OK), updates `3cfb9f0` (1185 OK), disks `cc7b716`
  (1185 OK), battery `5f94eb3` (1190 OK); ruff clean on the three providers.
- 2026-11-21: step 0 review dispatched to `claude-sonnet-5-5` on the same
  worktree (dispatch `ctx_b114747499db`), with an explicit defect checklist
  (reusability for the next 16 elements, dead bindings, weakened tests,
  prefs/i18n/docs contract). Fixes land as a follow-up commit, squashed at
  integration.
- 2026-11-21: convergence done. `bar-elements` (all nine task branches merged,
  PKGBUILD `depends` unions and the README dependency table resolved) merged
  `master` and then `master` fast-forwarded to it: `4cbf485`. The user's
  uncommitted monitors/capture work survived (README stashed and re-applied
  with `git apply --3way`; every other modified file untouched).
  Green: 1373 Python tests, 124 QML renders.
- 2026-11-21: `tests/test_docs.py` failed on the untracked
  `docs/bar-elements-plan.md` (index must link every document). Added its row
  to `docs/index.md`, uncommitted like the rest of the user's tree.
- 2026-11-21: UI halves are **serialised**, unlike the data providers: each one
  edits the same regions of `bar/shell.qml`, `BarElementsPage.qml`, the i18n
  files and the gallery, so two in parallel would conflict by construction.
  Step 1b (volume) dispatched to `claude-sonnet-5-5` in `bar-volume-ui`.
- 2026-11-21: step 1b (volume) committed `69af1ad` in `bar-volume-ui`
  (1378 tests OK, 124 QML) — pending my merge, blocked only by the user's dirty
  `kit/tokens.js`/`README.md` (stash + `git apply --3way`, as before).
- 2026-11-21: UI branches now **chain**: `bar-updates-ui` was branched from
  `bar-volume-ui`, so each finished element carries the previous wiring and the
  merge into `master` is one fast-forward per step. Step 10b dispatched to
  OpenCode flash on that branch.
- 2026-11-21: step 7a (privacy provider) dispatched to Claude 5.5 in
  `bar-privacy-data` (new files only, no conflict with the UI chain).
- 2026-11-22: volume `69af1ad`, updates `071c5ec`, disks `85d74a0` and the privacy
  provider `e8c29d9` are merged in `master` (1413 Python tests, 124 QML).
  Conflicts resolved: README dependency rows (one row per package group) and the
  `tests/test_dependencies.py` allowlist (`pactl` + `pw-cli`).
- 2026-11-22: two UI elements run in parallel for the first time (14b battery,
  2b brightness), each branch from `master`, with an explicit "additive lines
  only, never reorder" rule; their `bar/shell.qml` conflicts are resolved here
  by keeping both.
- 2026-11-22: step 14b (peripherals battery) `9d7212d` verified and merged
  (`1413` tests, `124` QML); window released. Options: `peripheralsHide`
  (JSON array, default none hidden), `peripheralsLow` (20 %).
- 2026-11-22: step 2b (brightness + night light) `1d9d29f` merged as `cb0874b`
  (1424 tests, 124 QML). The parallel merge needed real surgery, now the known
  recipe: (a) `git merge-file --union` for the additive files, (b) rebuild the
  three files where union glues two blocks (`shell/pages/BarElementsPage.qml`,
  `gallery/Main.qml`, `tests/qml/tst_layouts.qml`) by composing ours+theirs
  with `difflib` against the merge base, (c) merge the duplicated long README
  rows by hand. Keep this recipe for the next parallel pair.
- 2026-11-22: 13b (health, Claude 5.5) and 15b (containers, OpenCode flash)
  dispatched in parallel from `master`; windows of finished workers released.
- 2026-11-22: step 13b (health) `9aba6ef` verified and merged by fast-forward
  (1439 tests, 124 QML). It fast-forwarded its own branch to `master` before
  committing, which is the pattern to ask for. Warning for the suite: the
  qml-smoke unit step runs ~42 s against its 45 s timeout, so it can fail under
  parallel load — rerun alone before calling it broken.
- 2026-11-22: 7b (privacy UI, Claude 5.5) dispatched from `master` while 15b
  (containers) is still running.
- 2026-11-22: step 15b (containers) `df9d30b` merged as `f94a670`. Its
  prerequisite `8bcd214` repaired a real defect **my** brightness merge left in
  `bar/shell.qml`: the union glue dropped four closers, the bar did not parse,
  and every test stayed green because nothing loaded that file. Added
  `tests/test_qml_balance.py` (strips comments, strings and regex literals,
  matches brackets, rejects `<<<<<<<`); it flags the four braces in the broken
  revision and passes now. Lesson: after any union merge, check bracket balance
  before trusting the suite.
- 2026-11-22: step 7b (privacy) `a4ea33b` merged as `a93d332` (1461 tests, 124
  QML). It added `vitrail/privacy.py stop` + `cut_off()` (re-reads the graph and
  destroys the node only if it is still that use) with tests, and relaxed one
  health assertion from `"health"]` to a regex because health is no longer last
  in `DEFAULT_HIDDEN`.
- 2026-11-22: 16b (crypto) and 5 (weather) dispatched in parallel from `master`.
  Remaining after them: steps 3 (blocked on the calendar stack), 4, 6, 8, 9, 11.
- 2026-11-22: step 5 (weather) `cb6d76e` merged by fast-forward (1473 tests, 124
  QML). It shares `Dash.temperature/degrees/condition/weekday` with the desktop
  widget instead of copying, and `vitrail/weather.py` now returns 12 hourly
  points. Options: `weatherCities`, `weatherUnits`, `weatherInterval`.
- 2026-11-22: 4a (shared sampler + resources, Claude 5.5) and 11 (downloads,
  OpenCode flash) dispatched from `master`. Split because step 4 is two
  elements: 4a owns the sampler and the history buffers, 4b (network usage)
  plugs into them without touching the sampler.
- 2026-11-22: note for later merges — a `worktree create` can silently base a
  new worktree on an old commit (bar-market-ui landed on `b215644`). Always
  check `git -C <worktree> rev-parse HEAD` against `master` before starting a
  worker on it.
- 2026-11-22: step 16b (market) `d9de6d7` merged as `4ec3b20`, and step 4a
  (resources + shared sampler) `e8574d7` merged as `497f9d9` (1498 tests, 126
  QML). `tests/qml_smoke.sh`'s qml-unit timeout raised 45 s → 120 s: the suite
  grew past 1600 unit tests and the old limit tripped under load, not because
  of a real failure.
- 2026-11-22: 4b (network usage) and 6 (pomodoro + notes) dispatched in parallel
  from `master`; both worktrees had to be fast-forwarded from `b215644` first.
- 2026-11-22: user instruction recorded — **when every task is finished, unify
  all remaining branches into the main branch** (`master`): the task branches,
  `bar-elements`, and the `docs/index.md` line plus the plan document, leaving
  the user's monitors/capture WIP untouched.
- 2026-11-22: step 11 (downloads) `b238ec7` merged as `53c3991` (1511 tests, 126
  QML). It added `vitrail/downloads.py state()` and a guarded `cancel`.
  Merge note: the union glue hit `bar/shell.qml`, `gallery/Main.qml` and
  `shell/pages/BarElementsPage.qml` again; the fix is now routine — rebuild
  `ours` and insert the other branch's blocks at unique anchors (import, refresh
  guard, BarSnapshot, watch Process, case, widget, loadedItem case, popout,
  component), then run `test_qml_balance` and the smoke before committing.
- 2026-11-22: steps 8 (dnd + caffeine) and 9 (clipboard + colour picker)
  dispatched in parallel from `master`; 4b (netusage) and 6 (pomodoro + notes)
  still running, so four workers are in flight.
- 2026-11-22: step 6 (pomodoro + notes) `1b43d77` merged as `27b54fb` (1511
  tests, 127 QML). It shares the shell's single `focusTimers` TimerEngine and
  the one `notes.js` store; adds `kit/base/VitrailRing.qml` and `notesPopupMax`.
  Merge lesson: the gallery has nested sections, so an anchor matched inside
  `component Preview` and duplicated 195 lines; always render the gallery with
  `qml6 gallery/Main.qml -- --palette '{}' --grab` before believing the smoke,
  and rebuild from the branch that renders when in doubt.
- 2026-11-22: step 8 (dnd + caffeine) `277347c` merged as `8de5591` (1511
  tests, 127 QML). It also exposed a master defect: the start/center/end bar
  delegates each carried **two** `Component.onDestruction` handlers (the union
  glue of an earlier merge), which QML collapses to one and made a direct
  quickshell launch fail. Fixed separately in `93d5f8c` (one handler that
  reports the failure and unregisters). Gallery lesson repeated: section
  extraction from master can carry the trailing `component Preview`; check
  `grep -c 'component Preview'` is 1 and render with `qmlscene`/`qml6` before
  committing.
- 2026-11-22: after the plan, the owner reported four things; opened a second
  round.
  1. Settings → Bar elements icons/order and a bar-shaped preview: dispatched
     to **claude-opus-5-5** (`bar-panel-redesign`).
  2. Workspaces enabled but invisible: fixed in `3a411d4`. Root cause:
     `Hyprland.workspaces.values` is a QJSValue sequence (length + indices,
     `Array.isArray` false), so `Workspaces.collect` started from an empty list.
     `listOf` now accepts a sequence; a test feeds that shape. Verified in the
     running shell: 2 entries after the fix, 0 before.
  3. Clock popup had no way to choose its widgets: dispatched to OpenCode flash
     (`bar-clock-widgets`, `dashboardWidgets` + gear + section).
  4. Workspaces "will have several styles": noted, not built yet.
- Also fixed on the way (all committed): missing `import "notes"` (the bar
  refused to start), the resources sampler reading a string as an int, the
  weather unit `Connections` on a non-QObject, and a guard test
  (`tests/test_shell_imports.py`) that every type the shell instantiates has
  its folder imported.
- 2026-11-22: clock popup widgets merged (`7dff1e3` → `326520a`): `dashboardWidgets`
  (bar.ini JSON array, empty/unknown falls back to all five), a gear in the
  popup that opens Settings → Bar elements → Clock, and a section with each
  widget's switch and up/down. 1538 tests, 127 QML.
- 2026-11-22: workspace pills confirmed live on DP-1 (two pills with the app
  icons of workspaces 1 and 2). A crash in the shell came from a temporary
  debug line that indexed `Hyprland.workspaces.values[0]` while the sequence
  was still empty ("pure virtual method called"); the line is gone and the bar
  runs again. `listOf` only indexes up to `length`, so the fix is safe.
