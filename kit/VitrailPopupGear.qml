import QtQuick
import "base"

// The settings gear of a bar popup. One definition, so every popup that offers
// settings draws the same button in the same place: the last item of its first
// row, at the top right (see references/popups.md). The popup emits
// `settingsRequested()` and the shell opens the page and tab that owns it.
VitrailButton {
    objectName: "popupSettings"
    variant: "plain"
    tone: "secondary"
    size: "sm"
    icon: "settings"
}
