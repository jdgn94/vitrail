import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// The capture overlay's action bar: a glass pill outside the selected area.
// Icons only, so it stays narrow enough to fit on a small monitor; the tooltip
// names each one. `mode` decides which action the overlay runs on Enter, and
// that button is the filled one.
Item {
    id: root

    property var t: function (key) {
        return key
    }
    // "shot": Enter takes a picture; "record": Enter records the area.
    property string mode: "shot"
    // Countdown before the action runs: 0, 3 or 5 seconds.
    property int timer: 0
    // "Ask AI" is a preference (captureAi): off, there is no button.
    property bool ai: true
    // The text recognition languages the preference sets ("" = the default).
    property string languages: ""
    // Background detection (preference captureDetect): the actions that need
    // text, or a code, wait for it. Off, they are all offered.
    property bool detect: true
    property bool detecting: false
    property bool hasText: false
    property bool hasCode: false

    signal shot()
    signal save()
    signal annotate()
    signal pin()
    signal ocr()
    signal translate()
    signal qr()
    signal palette()
    signal ask()
    signal record()
    signal timerCycled()
    signal windowMode()
    signal fullScreen()
    signal closed()

    // The actions that read text work when it was found (or detection is off).
    readonly property bool textReady: !root.detect || root.hasText
    readonly property string textWhy: root.detecting ? root.t("capture.detecting") : root.t("capture.ocr.none")

    implicitWidth: card.width
    implicitHeight: card.height

    component Action: Item {
        id: action

        property string icon: ""
        property string tooltip: ""
        property string tooltipDetail: ""
        property string value: ""
        property bool highlighted: false
        // False greys the button; `disabledWhy` replaces the tooltip's detail.
        // (Not `enabled`: a disabled item gets no hover, and the tooltip must
        // still say why.)
        property bool available: true
        property string disabledWhy: ""
        // The colour of the filled state: the primary action is the accent,
        // recording is the red one.
        property string tone: "primary"

        signal clicked()

        implicitWidth: button.implicitWidth
        implicitHeight: button.implicitHeight

        // The button fades and takes no hover when disabled; the tooltip
        // still has to say why.
        HoverHandler {
            id: hover
        }

        VitrailButton {
            id: button

            anchors.fill: parent
            enabled: action.available
            variant: action.highlighted ? "filled" : "text"
            tone: action.highlighted ? action.tone : "secondary"
            size: "sm"
            icon: action.icon
            text: action.value
            onClicked: action.clicked()
        }

        VitrailTooltip {
            text: action.tooltip
            detail: action.available ? action.tooltipDetail : action.disabledWhy
            active: hover.hovered
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: VitrailTokens.gap("xs")
        }
    }

    VitrailSurface {
        id: card

        anchors.centerIn: parent
        width: body.implicitWidth + 2 * VitrailTokens.gap("sm")
        height: body.implicitHeight + 2 * VitrailTokens.gap("xs")
        radius: VitrailTokens.radius

        RowLayout {
            id: body

            anchors.centerIn: parent
            spacing: VitrailTokens.gap("xs")

            Action {
                icon: "screenshot_monitor"
                tooltip: root.t("capture.shot")
                tooltipDetail: root.t("capture.shot.detail")
                highlighted: root.mode === "shot"
                onClicked: root.shot()
            }

            Action {
                icon: "save"
                tooltip: root.t("capture.save")
                tooltipDetail: root.t("capture.save.detail")
                onClicked: root.save()
            }

            Action {
                icon: "edit"
                tooltip: root.t("capture.annotate")
                tooltipDetail: root.t("capture.annotate.detail")
                onClicked: root.annotate()
            }

            Action {
                icon: "push_pin"
                tooltip: root.t("capture.pin")
                tooltipDetail: root.t("capture.pin.detail")
                onClicked: root.pin()
            }

            Action {
                icon: "document_scanner"
                available: root.textReady
                disabledWhy: root.textWhy
                tooltip: root.t("capture.ocr")
                tooltipDetail: root.t("capture.ocr.detail")
                    + (root.languages !== "" ? " (" + root.languages + ")" : "")
                onClicked: root.ocr()
            }

            Action {
                icon: "translate"
                available: root.textReady
                disabledWhy: root.textWhy
                tooltip: root.t("capture.translate")
                tooltipDetail: root.t("capture.translate.detail")
                onClicked: root.translate()
            }

            Action {
                icon: "qr_code_2"
                visible: !root.detect || root.hasCode
                tooltip: root.t("capture.qr")
                tooltipDetail: root.t("capture.qr.detail")
                onClicked: root.qr()
            }

            Action {
                icon: "palette"
                tooltip: root.t("capture.palette.name")
                tooltipDetail: root.t("capture.palette.detail")
                onClicked: root.palette()
            }

            Action {
                icon: "auto_awesome"
                visible: root.ai
                tooltip: root.t("capture.ask")
                tooltipDetail: root.t("capture.ask.detail")
                onClicked: root.ask()
            }

            Action {
                icon: "screen_record"
                tooltip: root.t("capture.record")
                tooltipDetail: root.t("capture.record.detail")
                tone: "error"
                highlighted: root.mode === "record"
                onClicked: root.record()
            }

            Action {
                icon: "timer"
                tooltip: root.t("capture.timer")
                tooltipDetail: root.t("capture.timer.detail")
                    + (root.timer > 0 ? " (" + root.timer + " s)" : "")
                value: root.timer > 0 ? String(root.timer) : ""
                onClicked: root.timerCycled()
            }

            Action {
                icon: "desktop_windows"
                tooltip: root.t("capture.window")
                tooltipDetail: root.t("capture.window.detail")
                onClicked: root.windowMode()
            }

            Action {
                icon: "fullscreen"
                tooltip: root.t("capture.full")
                tooltipDetail: root.t("capture.full.detail")
                onClicked: root.fullScreen()
            }

            Action {
                icon: "close"
                tooltip: root.t("capture.close")
                tooltipDetail: root.t("capture.close.detail")
                onClicked: root.closed()
            }
        }
    }
}
