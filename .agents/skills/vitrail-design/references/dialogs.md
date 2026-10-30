# System dialogs

Vitrail answers the system's questions itself, in one modal layer
(`vitrail-dialog`, Overlay, `keyboardFocus: Exclusive`, black 40 % dim) with
`bar/dialogs/SystemDialog.qml`: icon in a tinted circle, title, message,
optional secret field (focused on show), detail line (`error` tone on
failure) and buttons (last = default = Enter, `cancelKey` = Escape).

- Polkit: `PolkitAgent` in bar/shell.qml makes the bar the session's agent.
  `AuthFlow`: message, inputPrompt, responseVisible, supplementaryMessage /
  IsError, isResponseRequired (busy while false); submit(text) /
  cancelAuthenticationRequest(). Polkit wins over anything queued.
- Hyprland (app not responding, permission prompts): Hyprland runs
  `hyprland-dialog` from PATH; `scripts/hyprland-dialog.sh` is installed as
  `~/.local/bin/hyprland-dialog` (ahead of /usr/bin). It calls
  `vitrail-bar ipc call dialog ask <pid-nonce> <title> <text> <a;b>`, waits for
  `$XDG_RUNTIME_DIR/vitrail-dialog/<id>` and prints the chosen label (Hyprland
  matches it by prefix). Without the bar it execs the real dialog. A killed
  shim is noticed by a 1 s `kill -0 <pid>` watch and its question leaves.
  Button labels stay Hyprland's (they are the answer); known ones are only
  displayed translated (`dialog.terminate`, `dialog.wait`).
- `vitrail-bar ipc call dialog answer <label>` answers the question on screen
  (tests, keybinds).

Not handled yet: gnome-keyring / gcr prompts, GPG pinentry, xdg portal
pickers.
