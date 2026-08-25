import QtQuick

Rectangle {
    id: root

    property string label: "Button"
    property string icon: ""
    property color accentColor: "#9CCBFF"
    property color textColor: "#EAF1F7"
    property color mutedColor: "#83909E"
    property bool enabled: true
    property bool destructive: false
    property bool compact: false

    signal clicked()

    implicitWidth: compact ? 42 : Math.max(104, content.implicitWidth + 30)
    implicitHeight: compact ? 38 : 42
    radius: compact ? 12 : 14
    color: !enabled ? Qt.rgba(1, 1, 1, 0.025)
                    : mouse.containsMouse ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.16)
                                          : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.075)
    border.width: 1
    border.color: !enabled ? Qt.rgba(1, 1, 1, 0.08)
                          : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, mouse.containsMouse ? 0.75 : 0.38)
    opacity: enabled ? 1.0 : 0.45

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: icon.length > 0 && label.length > 0 ? 7 : 0

        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.enabled ? root.accentColor : root.mutedColor
            font.family: "Material Symbols Rounded"
            font.pixelSize: root.compact ? 18 : 19
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.label.length > 0
            text: root.label
            color: root.enabled ? root.textColor : root.mutedColor
            font.pixelSize: root.compact ? 10 : 11
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
