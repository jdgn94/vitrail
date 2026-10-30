import QtQuick
import "../kit"
import "../kit/base"

// The bar's main button: opens the application launcher. Super alone does
// the same (see hyprland.lua); both go through `vitrail-bar ipc call
// launcher toggle`.
VitrailButton {
    variant: "tonal"
    icon: "apps"
}
