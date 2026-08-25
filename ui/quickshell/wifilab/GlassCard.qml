import QtQuick

Rectangle {
    id: root

    property color fillColor: "#B5161A22"
    property color outlineColor: "#334B5563"
    property real cornerRadius: 18

    radius: cornerRadius
    color: fillColor
    border.width: 1
    border.color: outlineColor

    Behavior on color {
        ColorAnimation { duration: 180 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 180 }
    }
}
