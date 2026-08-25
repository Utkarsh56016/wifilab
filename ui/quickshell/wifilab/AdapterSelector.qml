import QtQuick

Item {
    id: root

    property var adapters: []
    property int currentIndex: -1
    property color surfaceColor: "#1B2029"
    property color surfaceRaised: "#222832"
    property color outlineColor: "#43505F"
    property color textColor: "#EAF1F7"
    property color mutedColor: "#9AA9B7"
    property color accentColor: "#9CCBFF"
    property color successColor: "#4CE56B"
    property color warningColor: "#FFBC45"
    property bool opened: false

    signal activated(int index)

    implicitHeight: 62
    z: opened ? 80 : 1

    readonly property var selectedAdapter: currentIndex >= 0 && currentIndex < adapters.length ? adapters[currentIndex] : ({})

    function adapterProtected(adapter) {
        return adapter && (adapter.protected === true || adapter.role === "system" || (adapter.nm_state === "connected" && adapter.connection))
    }

    Rectangle {
        id: field
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(root.surfaceRaised.r, root.surfaceRaised.g, root.surfaceRaised.b, 0.965)
        border.width: 1
        border.color: root.opened ? root.accentColor : root.outlineColor

        Row {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 13
            spacing: 11

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.adapterProtected(root.selectedAdapter) ? "wifi_lock" : "usb"
                color: root.adapterProtected(root.selectedAdapter) ? root.warningColor : root.accentColor
                font.family: "Material Symbols Rounded"
                font.pixelSize: 23
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 86
                spacing: 2

                Text {
                    width: parent.width
                    text: root.selectedAdapter.device_name || "Choose wireless adapter"
                    color: root.textColor
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.currentIndex >= 0
                          ? ((root.selectedAdapter.interface || "—") + "  •  " + (root.selectedAdapter.driver || "unknown driver") + (root.adapterProtected(root.selectedAdapter) ? "  •  SYSTEM PROTECTED" : ""))
                          : "No adapter selected"
                    color: root.adapterProtected(root.selectedAdapter) ? root.warningColor : root.mutedColor
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.opened ? "expand_less" : "expand_more"
                color: root.mutedColor
                font.family: "Material Symbols Rounded"
                font.pixelSize: 21
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.opened = !root.opened
        }
    }

    Rectangle {
        id: menu
        visible: root.opened
        x: 0
        y: root.height + 8
        width: root.width
        height: Math.max(66, 10 + Math.min(root.adapters.length, 5) * 58)
        radius: 16
        color: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 0.995)
        border.width: 1
        border.color: root.outlineColor
        z: 100
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 2

            Repeater {
                model: root.adapters

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 56
                    radius: 12
                    readonly property bool protectedAdapter: root.adapterProtected(modelData)
                    color: rowMouse.containsMouse
                           ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.10)
                           : (index === root.currentIndex ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.055) : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.protectedAdapter ? "shield_lock" : "wifi_tethering"
                            color: parent.parent.protectedAdapter ? root.warningColor : root.successColor
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80
                            spacing: 2

                            Text {
                                width: parent.width
                                text: modelData.device_name || modelData.interface
                                color: root.textColor
                                font.pixelSize: 10
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: (modelData.interface || "—") + "  •  " + (modelData.phy || "—") + "  •  " + (modelData.driver || "unknown")
                                color: root.mutedColor
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.protectedAdapter ? "PROTECTED" : (modelData.role === "lab-candidate" ? "LAB" : "IDLE")
                            color: parent.parent.protectedAdapter ? root.warningColor : root.successColor
                            font.pixelSize: 8
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.opened = false
                            root.activated(index)
                        }
                    }
                }
            }
        }
    }
}
