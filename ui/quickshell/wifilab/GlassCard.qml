import QtQuick

Rectangle {
    id: root

    property color fillColor: "#161A22"
    property color outlineColor: "#4B5563"
    property real cornerRadius: 18
    property real glassAlpha: 0.955

    radius: cornerRadius
    color: Qt.rgba(fillColor.r, fillColor.g, fillColor.b, Math.min(fillColor.a, glassAlpha))
    border.width: 1
    border.color: outlineColor

    Behavior on color {
        ColorAnimation { duration: 180 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 180 }
    }
}
