import QtQuick

Item {
    id: root
    required property var backend
    clip: true

    function pushSample(rx, tx) {
        graph.pushSample(rx, tx)
    }

    readonly property real gap: 10
    readonly property real metricH: 84
    readonly property real graphH: 300
    readonly property real protocolH: 123
    readonly property real cardW: (width - gap * 3) / 4

    // Top metrics strip: exact height. Never allowed to stretch.
    Repeater {
        model: [
            { label: "RX", value: backend.formatRate(backend.rxRate), detail: backend.formatPps(backend.rxPacketRate), color: backend.info },
            { label: "TX", value: backend.formatRate(backend.txRate), detail: backend.formatPps(backend.txPacketRate), color: backend.violet },
            { label: "MODE", value: backend.currentMode.toUpperCase(), detail: backend.currentInterface + " / " + backend.currentPhy, color: backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary },
            { label: "PROTOCOLS", value: String(backend.protocolSamplePackets), detail: backend.protocolAvailable ? "frames sampled" : "tshark unavailable", color: backend.protocolPermitted ? backend.success : backend.warning }
        ]

        delegate: GlassCard {
            required property var modelData
            required property int index
            x: index * (root.cardW + root.gap)
            y: 0
            width: root.cardW
            height: root.metricH
            fillColor: backend.surfaceHigh
            outlineColor: backend.outline

            Row {
                anchors.centerIn: parent
                spacing: 10
                StatusDot { dotColor: modelData.color }
                Column {
                    spacing: 2
                    Text { text: modelData.label; color: backend.textMuted; font.pixelSize: 10; font.bold: true }
                    Text { text: modelData.value; color: modelData.color; font.pixelSize: 18; font.bold: true }
                    Text { text: modelData.detail; color: backend.textMuted; font.pixelSize: 9 }
                }
            }
        }
    }

    // Main graph card.
    GlassCard {
        x: 0
        y: root.metricH + root.gap
        width: parent.width
        height: root.graphH
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text {
            x: 15
            y: 13
            text: "LIVE ADAPTER TRAFFIC"
            color: backend.textMuted
            font.pixelSize: 10
            font.bold: true
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 15
            y: 13
            spacing: 14
            Text { text: "●  RX"; color: backend.info; font.pixelSize: 10 }
            Text { text: "●  TX"; color: backend.violet; font.pixelSize: 10 }
        }

        TrafficGraph {
            id: graph
            x: 14
            y: 38
            width: parent.width - 28
            height: parent.height - 66
            rxColor: backend.info
            txColor: backend.violet
            gridColor: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.34)
        }

        Text {
            x: 15
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 11
            text: "Read-only /sys/class/net counters  •  1 s samples  •  " + backend.currentInterface
            color: backend.textMuted
            font.pixelSize: 9
        }
    }

    // Protocol section.
    GlassCard {
        x: 0
        y: root.metricH + root.gap + root.graphH + root.gap
        width: parent.width
        height: root.protocolH
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Column {
            x: 15
            y: 14
            width: 245
            spacing: 5
            Text { text: "PROTOCOL MIX"; color: backend.textMuted; font.pixelSize: 10; font.bold: true }
            Text {
                text: !backend.protocolAvailable ? "Optional tshark sampler not installed" : (!backend.protocolPermitted ? "Capture permission unavailable" : "Passive short sample")
                color: backend.protocolPermitted ? backend.success : backend.warning
                font.pixelSize: 10
            }
            Text {
                width: parent.width
                text: "Protocol sampling remains unprivileged. Existing dumpcap permissions only; no pkexec path is used."
                color: backend.textMuted
                font.pixelSize: 9
                wrapMode: Text.Wrap
            }
        }

        Rectangle {
            x: 274
            y: 14
            width: 1
            height: parent.height - 28
            color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.75)
        }

        Flow {
            x: 292
            y: 16
            width: parent.width - 307
            height: parent.height - 32
            spacing: 7

            Repeater {
                model: backend.protocols
                delegate: Rectangle {
                    required property var modelData
                    width: protocolText.implicitWidth + 20
                    height: 30
                    radius: 10
                    color: Qt.rgba(backend.info.r, backend.info.g, backend.info.b, 0.09)
                    border.width: 1
                    border.color: Qt.rgba(backend.info.r, backend.info.g, backend.info.b, 0.30)
                    Text { id: protocolText; anchors.centerIn: parent; text: modelData.name + "  " + modelData.count; color: backend.textPrimary; font.pixelSize: 9 }
                }
            }

            Text {
                visible: backend.protocols.length === 0
                width: parent.width
                text: backend.protocolPermitted ? "No protocol frames observed in this sample." : "Protocol labels will appear here once optional tshark/dumpcap capability is configured."
                color: backend.textMuted
                font.pixelSize: 10
                wrapMode: Text.Wrap
            }
        }
    }
}
