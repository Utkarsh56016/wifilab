import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var backend

    function pushSample(rx, tx) {
        graph.pushSample(rx, tx)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            spacing: 10

            Repeater {
                model: [
                    { label: "RX", value: backend.formatRate(backend.rxRate), detail: backend.formatPps(backend.rxPacketRate), color: backend.info },
                    { label: "TX", value: backend.formatRate(backend.txRate), detail: backend.formatPps(backend.txPacketRate), color: backend.violet },
                    { label: "MODE", value: backend.currentMode.toUpperCase(), detail: backend.currentInterface + " / " + backend.currentPhy, color: backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary },
                    { label: "PROTOCOLS", value: String(backend.protocolSamplePackets), detail: backend.protocolAvailable ? "frames sampled" : "tshark unavailable", color: backend.protocolPermitted ? backend.success : backend.warning }
                ]

                delegate: GlassCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fillColor: backend.surfaceHigh
                    outlineColor: backend.outline

                    Row {
                        anchors.centerIn: parent
                        spacing: 9
                        StatusDot { dotColor: modelData.color }
                        Column {
                            spacing: 1
                            Text { text: modelData.label; color: backend.textMuted; font.pixelSize: 8; font.bold: true }
                            Text { text: modelData.value; color: modelData.color; font.pixelSize: 16; font.bold: true }
                            Text { text: modelData.detail; color: backend.textMuted; font.pixelSize: 8 }
                        }
                    }
                }
            }
        }

        GlassCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            fillColor: backend.surfaceHigh
            outlineColor: backend.outline

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 13
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "LIVE ADAPTER TRAFFIC"; color: backend.textMuted; font.pixelSize: 9; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "● RX"; color: backend.info; font.pixelSize: 9 }
                    Text { text: "● TX"; color: backend.violet; font.pixelSize: 9 }
                }

                TrafficGraph {
                    id: graph
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    rxColor: backend.info
                    txColor: backend.violet
                    gridColor: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.30)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Read-only kernel interface counters • 1 s samples"; color: backend.textMuted; font.pixelSize: 8 }
                    Item { Layout.fillWidth: true }
                    Text { text: backend.currentInterface; color: backend.textMuted; font.pixelSize: 8 }
                }
            }
        }

        GlassCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 132
            fillColor: backend.surfaceHigh
            outlineColor: backend.outline

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 13

                Column {
                    Layout.preferredWidth: 240
                    spacing: 5
                    Text { text: "PROTOCOL MIX"; color: backend.textMuted; font.pixelSize: 9; font.bold: true }
                    Text {
                        text: !backend.protocolAvailable ? "Optional tshark sampler not installed" : (!backend.protocolPermitted ? "Capture permission unavailable" : "Passive short sample")
                        color: backend.protocolPermitted ? backend.success : backend.warning
                        font.pixelSize: 9
                    }
                    Text {
                        width: 230
                        text: "Protocol sampling never invokes pkexec. Existing dumpcap permissions only."
                        color: backend.textMuted
                        font.pixelSize: 8
                        wrapMode: Text.Wrap
                    }
                }

                Rectangle { width: 1; Layout.fillHeight: true; color: backend.outline }

                Flow {
                    Layout.fillWidth: true
                    spacing: 7

                    Repeater {
                        model: backend.protocols
                        delegate: Rectangle {
                            required property var modelData
                            width: protocolText.implicitWidth + 18
                            height: 28
                            radius: 10
                            color: Qt.rgba(backend.info.r, backend.info.g, backend.info.b, 0.08)
                            border.width: 1
                            border.color: Qt.rgba(backend.info.r, backend.info.g, backend.info.b, 0.28)
                            Text { id: protocolText; anchors.centerIn: parent; text: modelData.name + "  " + modelData.count; color: backend.textPrimary; font.pixelSize: 8 }
                        }
                    }

                    Text {
                        visible: backend.protocols.length === 0
                        width: 560
                        text: backend.protocolPermitted ? "No protocol frames observed in this sample." : "Protocol labels will appear here once optional tshark/dumpcap capability is configured."
                        color: backend.textMuted
                        font.pixelSize: 8
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
