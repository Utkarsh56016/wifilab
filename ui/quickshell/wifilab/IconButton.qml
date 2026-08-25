import QtQuick
import QtQuick.Controls

Button {
    id: root

    property string symbol: "settings"
    property string tip: ""
    property color foreground: "#DCE4EA"
    property color hoverFill: "#22313C49"
    property color pressedFill: "#33455466"

    implicitWidth: 42
    implicitHeight: 42
    hoverEnabled: true

    contentItem: Text {
        text: root.symbol
        color: root.foreground
        font.family: "Material Symbols Rounded"
        font.pixelSize: 21
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: 12
        color: root.down ? root.pressedFill : (root.hovered ? root.hoverFill : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    ToolTip.visible: hovered && tip.length > 0
    ToolTip.text: tip
    ToolTip.delay: 450
}
