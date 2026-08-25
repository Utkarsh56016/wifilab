import QtQuick

Item {
    id: root

    property color dotColor: "#45E26B"
    property bool pulse: false

    implicitWidth: 12
    implicitHeight: 12

    Rectangle {
        id: halo
        anchors.centerIn: parent
        width: 12
        height: 12
        radius: 6
        color: "transparent"
        border.width: 2
        border.color: Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.30)
        opacity: root.pulse ? 0.9 : 0.0
        scale: root.pulse ? 1.0 : 0.7

        SequentialAnimation on scale {
            running: root.pulse
            loops: Animation.Infinite
            NumberAnimation { to: 1.7; duration: 900; easing.type: Easing.OutCubic }
            NumberAnimation { to: 0.7; duration: 0 }
        }
        SequentialAnimation on opacity {
            running: root.pulse
            loops: Animation.Infinite
            NumberAnimation { from: 0.55; to: 0.0; duration: 900 }
            NumberAnimation { to: 0.55; duration: 0 }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 7
        height: 7
        radius: 3.5
        color: root.dotColor
    }
}
