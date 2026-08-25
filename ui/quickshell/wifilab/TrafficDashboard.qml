import QtQuick
import Quickshell.Io

Item {
    id: root
    required property var backend
    clip: true

    property var captureState: ({ present: false, available: false, permitted: false, protected: false, ready: false, interface: "", mode: "" })
    property var savedCaptures: []
    property bool captureBusy: false
    property string captureMessage: ""

    readonly property bool captureReady: captureState.ready === true
    readonly property int captureCount: savedCaptures.length
    readonly property var latestCapture: captureCount > 0 ? savedCaptures[0] : ({})

    function pushSample(rx, tx) {
        graph.pushSample(rx, tx)
    }

    function parseJson(text, fallback) {
        try { return JSON.parse(text) } catch (e) { return fallback }
    }

    function formatBytes(value) {
        var n = Math.max(0, Number(value) || 0)
        if (n >= 1073741824) return (n / 1073741824).toFixed(2) + " GiB"
        if (n >= 1048576) return (n / 1048576).toFixed(2) + " MiB"
        if (n >= 1024) return (n / 1024).toFixed(1) + " KiB"
        return n.toFixed(0) + " B"
    }

    function refreshCapture() {
        if (!captureStatusProcess.running)
            captureStatusProcess.exec(["wifilab", "capture", "status", "--json"])
        if (!capturesProcess.running)
            capturesProcess.exec(["wifilab", "captures", "--json"])
    }

    function runCapture() {
        if (captureBusy || !captureReady || backend.protectedView) return
        captureBusy = true
        captureMessage = "Capturing 10 s / max 10 MiB…"
        backend.log("Started bounded capture on " + backend.currentInterface)
        captureRunProcess.exec(["wifilab", "capture", "run", "10", "10240"])
    }

    function captureMetricValue() {
        if (captureBusy) return "ACTIVE"
        if (captureReady) return "READY"
        if (captureState.available === true && captureState.permitted !== true) return "LOCKED"
        if (captureState.available !== true) return "OFFLINE"
        return backend.monitorMode ? "BLOCKED" : "MON REQ"
    }

    function captureMetricColor() {
        if (captureBusy || captureReady) return backend.success
        if (captureState.available === true && captureState.permitted !== true) return backend.warning
        return backend.textMuted
    }

    function captureStatusText() {
        if (captureBusy) return "Bounded capture in progress"
        if (captureState.available !== true) return "dumpcap unavailable in this session"
        if (captureState.permitted !== true) return "Capture permission not active"
        if (backend.protectedView || captureState.protected === true) return "Protected adapter cannot be captured"
        if (!backend.monitorMode) return "Monitor mode required"
        if (captureReady) return "Ready: selected lab adapter only"
        return "Capture blocked by backend safety state"
    }

    readonly property real gap: 10
    readonly property real metricH: 84
    readonly property real graphH: 300
    readonly property real protocolH: 123
    readonly property real cardW: (width - gap * 3) / 4

    Process {
        id: captureStatusProcess
        stdout: StdioCollector {
            onStreamFinished: root.captureState = root.parseJson(text, { present: false, available: false, permitted: false, protected: false, ready: false })
        }
    }

    Process {
        id: capturesProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = root.parseJson(text, { captures: [] })
                root.savedCaptures = parsed.captures || []
            }
        }
    }

    Process {
        id: captureRunProcess
        stdout: StdioCollector { id: captureRunOut }
        stderr: StdioCollector { id: captureRunErr }
        onExited: function(code, status) {
            root.captureBusy = false
            var result = root.parseJson(captureRunOut.text, {})
            if (code === 0 && result.ok === true) {
                root.captureMessage = "Saved " + root.formatBytes(result.bytes)
                backend.log("Capture saved: " + root.formatBytes(result.bytes))
            } else {
                var reason = result.message || captureRunErr.text.trim() || "capture failed"
                root.captureMessage = reason
                backend.log("Capture failed: " + reason)
            }
            root.refreshCapture()
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.refreshCapture()
    }

    // Top metrics strip: exact height. Never allowed to stretch.
    Repeater {
        model: [
            { label: "RX", value: backend.formatRate(backend.rxRate), detail: backend.formatPps(backend.rxPacketRate), color: backend.info },
            { label: "TX", value: backend.formatRate(backend.txRate), detail: backend.formatPps(backend.txPacketRate), color: backend.violet },
            { label: "MODE", value: backend.currentMode.toUpperCase(), detail: backend.currentInterface + " / " + backend.currentPhy, color: backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary },
            { label: "CAPTURE", value: root.captureMetricValue(), detail: root.captureCount + " saved", color: root.captureMetricColor() }
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

    // Capture + protocol section. Geometry remains frozen at 123 px.
    GlassCard {
        x: 0
        y: root.metricH + root.gap + root.graphH + root.gap
        width: parent.width
        height: root.protocolH
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Item {
            x: 15
            y: 12
            width: 258
            height: parent.height - 24

            Text {
                x: 0; y: 0
                text: "BOUNDED CAPTURE"
                color: backend.textMuted
                font.pixelSize: 10
                font.bold: true
            }

            Text {
                x: 0; y: 18
                width: parent.width
                text: root.captureStatusText()
                color: root.captureReady || root.captureBusy ? backend.success : backend.warning
                font.pixelSize: 9
                elide: Text.ElideRight
            }

            CyberButton {
                x: 0
                y: 39
                width: 132
                height: 34
                label: root.captureBusy ? "CAPTURING" : "CAPTURE 10s"
                icon: root.captureBusy ? "hourglass_top" : "radio_button_checked"
                compact: true
                enabled: root.captureReady && !root.captureBusy && !backend.protectedView
                accentColor: backend.monitorAccent
                textColor: backend.textPrimary
                mutedColor: backend.textMuted
                onClicked: root.runCapture()
            }

            Column {
                x: 142
                y: 39
                width: 116
                spacing: 2
                Text { text: root.captureCount + " saved"; color: backend.textPrimary; font.pixelSize: 9; font.bold: true }
                Text {
                    width: parent.width
                    text: root.captureMessage.length > 0
                          ? root.captureMessage
                          : (root.captureCount > 0 ? root.formatBytes(root.latestCapture.bytes) + " latest" : "10 s / 10 MiB max")
                    color: backend.textMuted
                    font.pixelSize: 8
                    elide: Text.ElideRight
                }
            }

            Text {
                x: 0
                y: 80
                width: parent.width
                text: "Non-root dumpcap • selected physical adapter • no pkexec capture"
                color: backend.textMuted
                font.pixelSize: 8
                elide: Text.ElideRight
            }
        }

        Rectangle {
            x: 286
            y: 14
            width: 1
            height: parent.height - 28
            color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.75)
        }

        Item {
            x: 304
            y: 12
            width: parent.width - 319
            height: parent.height - 24

            Text {
                x: 0; y: 0
                text: "PROTOCOL MIX"
                color: backend.textMuted
                font.pixelSize: 10
                font.bold: true
            }

            Text {
                x: 92; y: 0
                width: parent.width - 92
                text: !backend.protocolAvailable ? "tshark unavailable" : (!backend.protocolPermitted ? "capture permission unavailable" : backend.protocolSamplePackets + " frames sampled")
                color: backend.protocolPermitted ? backend.success : backend.warning
                font.pixelSize: 9
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

            Flow {
                x: 0
                y: 25
                width: parent.width
                height: parent.height - 25
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
                    text: backend.protocolPermitted ? "No protocol frames observed in this sample." : "Protocol labels appear when the current session has dumpcap permission."
                    color: backend.textMuted
                    font.pixelSize: 9
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
