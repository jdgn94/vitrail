# Settings gear on the popups, and a Power section

Asked in chat (2026-11-21): the popups of internet, VPN, Bluetooth, power
profile and keyboard get the settings button at the top right, with a rule that
it always sits there. The power-profile popup had no destination, so the
settings window gains a Power section where each mode can be configured — the
one the daemon allows (the three profiles are fixed; what is configurable is
global).

## Tasks

- [x] 1. `vitrail/network.py`: `power()` in the state (profile, battery-aware,
      the daemon's actions) and the `power-set` / `power-aware` /
      `power-action` requests, validated like every other verb.
- [x] 2. `tests/test_network.py`: the state block, the argv of each request and
      the refused arguments.
- [x] 3. `shell/pages/ConnectionPage.qml`: the Power tab — the three modes as a
      selector with their explanation, the automatic-change switch and one
      switch per daemon action. Requests go through `ask()`, and the page says
      so when the daemon is not installed.
- [x] 4. `kit/VitrailPopupGear.qml`: the one gear (plain, secondary, sm,
      `settings`), so every popup draws the same button.
- [x] 5. The four panels (`NetworkPanel`, `VpnPanel`, `PowerProfilePanel`,
      `KeyboardPanel`) get the gear as the last item of their first row, and a
      `settingsRequested` signal.
- [x] 6. `bar/shell.qml`: each popup opens the settings window on its page and
      tab (`connection/internet`, `connection/bluetooth`, `connection/vpn`,
      `connection/power`, `input/keyboard`).
- [x] 7. Rule: `references/popups.md` says where the gear goes and what it
      opens; a test keeps the five popups in line.
- [x] 8. `kit/i18n/*.json` (six languages): the tab, the switches, the actions
      heading and the missing-daemon line.
- [x] 9. Docs: README (Runtime dependencies gets `power-profiles-daemon`),
      CHANGELOG, `tests/test_dependencies.py` if `powerprofilesctl` is new.
- [x] 10. Verify: python suite, `tests/qml_smoke.sh`, the settings grab of the
      Power tab, and the popups rendered in a throwaway `ShellRoot`.
