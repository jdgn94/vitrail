import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Dropdown for a list of { key, label } entries.
ColumnLayout {
    id: root

    property string label: ""
    property var options: []
    property string current: ""
    property color foreground: VitrailTokens.color("foreground", "#e2e2e9")
    property color accent: VitrailTokens.color("primary", "#a8c7fa")
    property color panel: VitrailTokens.color("surfaceHigh", "#1d2024")

    signal selected(string key)

    spacing: 4

    Text {
        text: root.label
        color: root.foreground
        font.pixelSize: 12
        font.family: VitrailTokens.fontFamily
        opacity: 0.8
    }

    ComboBox {
        id: combo

        Layout.fillWidth: true
        implicitHeight: 36
        model: root.options.map(function (entry) { return entry.label })
        currentIndex: {
            for (var i = 0; i < root.options.length; i++) {
                if (root.options[i].key === root.current)
                    return i
            }
            return 0
        }
        onActivated: function (index) {
            root.selected(root.options[index].key)
        }

        background: Rectangle {
            radius: 10
            color: Qt.rgba(root.panel.r, root.panel.g, root.panel.b, 0.85)
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)
        }

        contentItem: Text {
            leftPadding: 12
            text: combo.displayText
            color: root.foreground
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Text {
            x: combo.width - width - 12
            y: combo.topPadding + (combo.availableHeight - height) / 2
            text: "▾"
            color: root.foreground
            font.pixelSize: 12
        }

        // The popup uses the combo's own model: combo.delegateModel is empty
        // until the popup is visible, which made the list appear with no rows.
        popup: Popup {
            y: combo.height + 4
            width: combo.width
            padding: 4
            implicitHeight: Math.min(contentItem.contentHeight + 8, 260)

            background: Rectangle {
                radius: 10
                color: Qt.rgba(root.panel.r, root.panel.g, root.panel.b, 0.98)
                border.width: 1
                border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
            }

            contentItem: ListView {
                model: combo.model
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: ItemDelegate {
                    width: combo.width - 8
                    height: 32

                    contentItem: Text {
                        text: modelData
                        color: root.foreground
                        font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 6
                        color: highlighted
                               ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                               : "transparent"
                    }

                    onClicked: {
                        combo.currentIndex = index
                        root.selected(root.options[index].key)
                        combo.popup.close()
                    }
                }
            }
        }
    }
}
