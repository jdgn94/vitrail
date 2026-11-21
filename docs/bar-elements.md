# Bar elements

New bar elements use `bar/BarElementBase.qml` and a companion Python snapshot
module so they can be added, placed and removed with no changes to the shell's
core code — only the registry entry and the preference files change.

## Architecture

```
bar/BarElementBase.qml    base Item: icon button, tooltip, shown/showMode
bar/<name>/NameButton.qml extends BarElementBase; sets icon/tooltip/data
bar/<name>/NamePanel.qml  popup body with VitrailPopupGear + settingsRequested
vitrail/<name>.py         Python snapshot: state() → JSON dict, cached
shell/pages/Bar...Page    settings page wired in shell/main.qml
```

The shell wires the button, popup and Python data together in `bar/shell.qml`;
the registry entry in `bar/widgets.js` and the hidden default in
`bar/layouts.js` control placement.

## Adding a new bar element

1. **Create the button** at `bar/<name>/NameButton.qml`:

   ```qml
   import ".."
   import "../kit"

   BarElementBase {
       id: root
       property var data: ({})
       property var strings: ({})
       icon: "my_icon"
       tooltip: root.data.label || "My element"
       tooltipDetail: "Opens the popup"
   }
   ```

2. **Create the panel** at `bar/<name>/NamePanel.qml`:

   ```qml
   import "../kit"
   import "../kit/base"
   Item {
       signal settingsRequested()
       // ... popup body with VitrailPopupGear at the top right
   }
   ```

3. **Create the Python module** at `vitrail/<name>.py`:

   ```python
   def state(cache=None, now=None) -> dict: ...
   def main(argv=None) -> int: ...
   ```
   Follow `vitrail/sample.py`. No new programs.

4. **Register the element** in `bar/widgets.js`:

   ```js
   { id: "my-element", surfaces: ["bar"], group: "end",
     labelKey: "bar.widget.my-element", icon: "my_icon",
     sizes: [], styles: [] },
   ```

5. **Hide by default** in `bar/layouts.js`:

   ```js
   var DEFAULT_HIDDEN = { bar: ["capture", "sample", "my-element"] }
   ```

6. **Wire in `bar/shell.qml`**:
   - Add `import "my-element"` to the import block.
   - Add `property var myElementState: ({})` + `Timer` + `Process` at shell level.
   - Add `Component { id: myElementWidget; ... }` after the existing widgets.
   - Add `case "my-element": return myElementWidget` in `widgetComponent`.
   - Add `case "my-element": return monitor.loadedItem("my-element")` in `anchorFor`.
   - Add `Popout { name: "my-element"; ... }` and `Component { id: myElementComponent; ... }`.

7. **Add preferences** to `vitrail/prefs.map` and `shell/Prefs.qml`.

8. **Add i18n strings** to all six `kit/i18n/*.json`.

9. **Add a settings page** in `shell/pages/` and wire it in `shell/main.qml`.

10. **Add a gallery section** to `gallery/Main.qml`.

11. **Run tests**: `uv run python -m unittest discover -s tests` and `bash tests/qml_smoke.sh`.

## Reference: sample element

`bar/sample/` is the reference implementation. It is hidden by default
(`DEFAULT_HIDDEN.bar` in `bar/layouts.js`). Enable it by right-clicking the bar,
opening the editor and moving it into a group, or by toggling its visibility in
Settings → Bar elements.
