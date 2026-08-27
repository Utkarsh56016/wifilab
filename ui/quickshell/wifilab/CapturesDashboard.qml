import QtQuick
import Quickshell.Io

Item {
    id: root
    required property var backend
    clip: true

    property var captures: []
    property int selectedIndex: -1
    property string selectedId: ""
    property var inspection: ({})
    property string requestedInspectId: ""
    property var protocolDetails: ({ protocols: [] })
    property string requestedProtocolId: ""
    property var viewerStatus: ({ graphical_session: false, viewer: ({ available: false }), reveal: ({ available: false }) })
    property string inventoryMessage: ""
    property string actionMessage: ""
    property bool actionBusy: false

    readonly property var selectedCapture: selectedIndex >= 0 && selectedIndex < captures.length ? captures[selectedIndex] : ({})
    readonly property var inspectedCapture: inspection.capture || ({})
    readonly property var pcap: inspection.pcap || ({})
    readonly property var integrity: inspection.integrity || ({})
    readonly property var protocols: protocolDetails.protocols || []
    readonly property bool hasSelection: selectedId.length > 0
    readonly property bool inspecting: inspectProcess.running
    readonly property bool analyzingProtocols: captureProtocolProcess.running
    readonly property bool viewerAvailable: viewerStatus.graphical_session === true && viewerStatus.viewer && viewerStatus.viewer.available === true
    readonly property bool revealAvailable: viewerStatus.graphical_session === true && viewerStatus.reveal && viewerStatus.reveal.available === true

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

    function formatDuration(value) {
        var n = Math.max(0, Number(value) || 0)
        if (n >= 60) return (n / 60).toFixed(1) + " min"
        if (n >= 10) return n.toFixed(2) + " s"
        return n.toFixed(3) + " s"
    }

    function formatEpoch(value) {
        var n = Number(value) || 0
        if (n <= 0) return "—"
        return Qt.formatDateTime(new Date(n * 1000), "yyyy-MM-dd  HH:mm:ss.zzz")
    }

    function shortCreated(value) {
        if (!value || value.length < 19) return "Unknown time"
        return value.substring(0, 10) + "  " + value.substring(11, 19) + " UTC"
    }

    function captureDetail(capture) {
        if (!capture) return ""
        if (capture.metadata_state === "complete") {
            var iface = capture.interface || "unknown iface"
            var channel = Number(capture.channel) || 0
            return iface + (channel > 0 ? "  •  ch " + channel : "")
        }
        if (capture.metadata_state === "invalid") return "Invalid sidecar metadata"
        return "Legacy capture metadata"
    }

    function metadataColor(state) {
        if (state === "complete") return backend.success
        if (state === "invalid") return backend.error
        return backend.warning
    }

    function integrityColor(state) {
        if (state === "verified") return backend.success
        if (state === "mismatch") return backend.error
        if (state === "invalid_manifest") return backend.error
        return backend.warning
    }

    function applyInventory(payload) {
        var next = payload.captures || []
        var previousId = selectedId
        captures = next
        inventoryMessage = next.length + " saved capture" + (next.length === 1 ? "" : "s")

        if (next.length === 0) {
            selectedIndex = -1
            selectedId = ""
            inspection = ({})
            protocolDetails = ({ protocols: [] })
            requestedInspectId = ""
            requestedProtocolId = ""
            return
        }

        var wanted = -1
        if (previousId.length > 0) {
            for (var i = 0; i < next.length; ++i) {
                if (next[i].id === previousId) {
                    wanted = i
                    break
                }
            }
        }

        if (wanted < 0) wanted = 0
        selectedIndex = wanted
        selectedId = next[wanted].id || next[wanted].name || ""

        var currentInspected = inspectedCapture.id || ""
        if (selectedId.length > 0 && currentInspected !== selectedId) {
            requestedInspectId = selectedId
            startInspectIfIdle()
        }

        var currentProtocolId = protocolDetails.capture_id || ""
        if (selectedId.length > 0 && currentProtocolId !== selectedId) {
            requestedProtocolId = selectedId
            startProtocolIfIdle()
        }
    }

    function refreshInventory() {
        if (!inventoryProcess.running)
            inventoryProcess.exec(["wifilab", "captures", "--json"])
    }

    function refreshViewerStatus() {
        if (!viewerStatusProcess.running)
            viewerStatusProcess.exec(["wifilab", "capture", "viewer", "status", "--json"])
    }

    function selectCapture(index) {
        if (index < 0 || index >= captures.length) return
        selectedIndex = index
        selectedId = captures[index].id || captures[index].name || ""
        inspection = ({})
        protocolDetails = ({ protocols: [] })
        actionMessage = ""
        requestedInspectId = selectedId
        requestedProtocolId = selectedId
        startInspectIfIdle()
        startProtocolIfIdle()
    }

    function startInspectIfIdle() {
        if (inspectProcess.running || requestedInspectId.length === 0) return
        var captureId = requestedInspectId
        requestedInspectId = ""
        inspectProcess.exec(["wifilab", "capture", "inspect", captureId, "--json"])
    }

    function startProtocolIfIdle() {
        if (captureProtocolProcess.running || requestedProtocolId.length === 0) return
        var captureId = requestedProtocolId
        requestedProtocolId = ""
        captureProtocolProcess.exec(["wifilab", "capture", "protocols", captureId, "--json"])
    }

    function revealSelected() {
        if (actionBusy || !hasSelection || !revealAvailable) return
        actionBusy = true
        actionMessage = "Opening capture directory…"
        revealProcess.exec(["wifilab", "capture", "reveal", selectedId])
    }

    function openSelected() {
        if (actionBusy || !hasSelection || !viewerAvailable) return
        actionBusy = true
        actionMessage = "Opening saved capture in Wireshark…"
        openProcess.exec(["wifilab", "capture", "open", selectedId])
    }

    Process {
        id: inventoryProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = root.parseJson(text, { ok: false, captures: [] })
                if (parsed.ok === true) root.applyInventory(parsed)
                else root.inventoryMessage = parsed.message || "Capture inventory unavailable"
            }
        }
    }

    Process {
        id: inspectProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = root.parseJson(text, {})
                if (parsed.ok === true && parsed.capture && parsed.capture.id === root.selectedId)
                    root.inspection = parsed
            }
        }
        onExited: function(code, status) {
            if (code !== 0 && root.requestedInspectId.length === 0)
                root.inventoryMessage = "Capture inspection failed"
            root.startInspectIfIdle()
        }
    }

    Process {
        id: captureProtocolProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = root.parseJson(text, {})
                if (parsed.ok === true && parsed.capture_id === root.selectedId)
                    root.protocolDetails = parsed
            }
        }
        onExited: function(code, status) {
            if (code !== 0 && root.requestedProtocolId.length === 0)
                root.protocolDetails = ({ protocols: [] })
            root.startProtocolIfIdle()
        }
    }

    Process {
        id: viewerStatusProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = root.parseJson(text, {})
                if (parsed.ok === true) root.viewerStatus = parsed
            }
        }
    }

    Process {
        id: revealProcess
        stdout: StdioCollector { id: revealOut }
        stderr: StdioCollector { id: revealErr }
        onExited: function(code, status) {
            root.actionBusy = false
            var result = root.parseJson(revealOut.text, {})
            if (code === 0 && result.ok === true) {
                root.actionMessage = "Capture directory opened"
                backend.log("Revealed saved capture directory")
            } else {
                var reason = result.message || revealErr.text.trim() || "reveal failed"
                root.actionMessage = reason
                backend.log("Reveal failed: " + reason)
            }
            root.refreshViewerStatus()
        }
    }

    Process {
        id: openProcess
        stdout: StdioCollector { id: openOut }
        stderr: StdioCollector { id: openErr }
        onExited: function(code, status) {
            root.actionBusy = false
            var result = root.parseJson(openOut.text, {})
            if (code === 0 && result.ok === true) {
                root.actionMessage = "Opened saved capture in Wireshark"
                backend.log("Opened saved capture in Wireshark")
            } else {
                var reason = result.message || openErr.text.trim() || "viewer launch failed"
                root.actionMessage = reason
                backend.log("Open failed: " + reason)
            }
            root.refreshViewerStatus()
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.refreshInventory()
    }

    Timer {
        interval: 12000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.refreshViewerStatus()
    }

    GlassCard {
        id: libraryCard
        x: 0
        y: 0
        width: 402
        height: parent.height
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text {
            x: 15; y: 14
            text: "CAPTURE LIBRARY"
            color: backend.textMuted
            font.pixelSize: 10
            font.bold: true
        }

        Text {
            anchors.right: refreshIcon.left
            anchors.rightMargin: 10
            y: 14
            text: root.inventoryMessage
            color: backend.textMuted
            font.pixelSize: 9
        }

        Text {
            id: refreshIcon
            anchors.right: parent.right
            anchors.rightMargin: 15
            y: 10
            text: "refresh"
            color: refreshMouse.containsMouse ? backend.textPrimary : backend.textMuted
            font.family: "Material Symbols Rounded"
            font.pixelSize: 19

            MouseArea {
                id: refreshMouse
                anchors.fill: parent
                anchors.margins: -7
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refreshInventory()
            }
        }

        Rectangle {
            x: 14; y: 42
            width: parent.width - 28
            height: 1
            color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.72)
        }

        ListView {
            id: captureList
            x: 10
            y: 52
            width: parent.width - 20
            height: parent.height - 62
            clip: true
            spacing: 7
            model: root.captures

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: captureList.width
                height: 79
                radius: 12
                color: root.selectedIndex === index
                       ? Qt.rgba(backend.accent.r, backend.accent.g, backend.accent.b, 0.11)
                       : Qt.rgba(backend.surfaceRaised.r, backend.surfaceRaised.g, backend.surfaceRaised.b, 0.72)
                border.width: 1
                border.color: root.selectedIndex === index
                              ? Qt.rgba(backend.accent.r, backend.accent.g, backend.accent.b, 0.66)
                              : Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.72)

                Text {
                    x: 12; y: 11
                    text: "inventory_2"
                    color: root.metadataColor(modelData.metadata_state)
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                }

                Text {
                    x: 43; y: 9
                    width: parent.width - 55
                    text: modelData.name || modelData.id || "capture"
                    color: backend.textPrimary
                    font.pixelSize: 9
                    font.bold: true
                    elide: Text.ElideMiddle
                }

                Text {
                    x: 43; y: 29
                    width: parent.width - 55
                    text: root.shortCreated(modelData.created_at_utc)
                    color: backend.textMuted
                    font.pixelSize: 8
                }

                Text {
                    x: 43; y: 47
                    width: parent.width - 145
                    text: root.captureDetail(modelData)
                    color: root.metadataColor(modelData.metadata_state)
                    font.pixelSize: 8
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 47
                    text: root.formatBytes(modelData.bytes)
                    color: backend.textMuted
                    font.pixelSize: 8
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectCapture(index)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.captures.length === 0
                text: "No saved captures yet.\nCreate one from TRAFFIC when the lab adapter is in monitor mode."
                color: backend.textMuted
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.35
            }
        }
    }

    GlassCard {
        id: inspectorCard
        x: 412
        y: 0
        width: parent.width - 412
        height: parent.height
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text {
            x: 16; y: 14
            text: "CAPTURE INSPECTOR"
            color: backend.textMuted
            font.pixelSize: 10
            font.bold: true
        }

        Text {
            x: 145; y: 13
            width: parent.width - 162
            text: root.hasSelection ? root.selectedId : "No capture selected"
            color: backend.textPrimary
            font.pixelSize: 10
            font.bold: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
        }

        Rectangle {
            x: 15; y: 42
            width: parent.width - 30
            height: 1
            color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.72)
        }

        Item {
            anchors.fill: parent
            visible: !root.hasSelection

            Column {
                anchors.centerIn: parent
                spacing: 8
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "inventory"; color: backend.textMuted; font.family: "Material Symbols Rounded"; font.pixelSize: 38 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Select a saved capture to inspect"; color: backend.textPrimary; font.pixelSize: 14; font.bold: true }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Inspection is offline and never opens a live interface."; color: backend.textMuted; font.pixelSize: 9 }
            }
        }

        Item {
            anchors.fill: parent
            visible: root.hasSelection

            Row {
                x: 15; y: 56
                spacing: 8

                Repeater {
                    model: [
                        { label: "PACKETS", value: root.pcap.packet_count !== undefined ? String(root.pcap.packet_count) : "—", color: backend.info },
                        { label: "DURATION", value: root.pcap.duration_seconds !== undefined ? root.formatDuration(root.pcap.duration_seconds) : "—", color: backend.violet },
                        { label: "SIZE", value: root.pcap.file_bytes !== undefined ? root.formatBytes(root.pcap.file_bytes) : root.formatBytes(root.selectedCapture.bytes), color: backend.dmsPrimary }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: 181
                        height: 72
                        radius: 12
                        color: Qt.rgba(backend.surfaceRaised.r, backend.surfaceRaised.g, backend.surfaceRaised.b, 0.78)
                        border.width: 1
                        border.color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.76)

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: backend.textMuted; font.pixelSize: 8; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.value; color: modelData.color; font.pixelSize: 17; font.bold: true }
                        }
                    }
                }
            }

            Text {
                x: 15; y: 146
                text: "CAPTURE CONTEXT"
                color: backend.textMuted
                font.pixelSize: 9
                font.bold: true
            }

            Column {
                x: 15; y: 168
                width: 275
                spacing: 10

                Text { width: parent.width; text: "Created\n" + root.shortCreated(root.inspectedCapture.created_at_utc || root.selectedCapture.created_at_utc); color: backend.textPrimary; font.pixelSize: 9; lineHeight: 1.2 }
                Text { width: parent.width; text: "Runtime adapter\n" + ((root.inspectedCapture.interface || "—") + "  /  " + (root.inspectedCapture.phy || "—")); color: backend.textPrimary; font.pixelSize: 9; lineHeight: 1.2 }
                Text { width: parent.width; text: "Driver\n" + (root.inspectedCapture.driver || "—"); color: backend.textPrimary; font.pixelSize: 9; lineHeight: 1.2 }
                Text { width: parent.width; text: "Radio\n" + ((Number(root.inspectedCapture.channel) || 0) > 0 ? "channel " + root.inspectedCapture.channel + "  •  " + root.inspectedCapture.frequency_mhz + " MHz  •  " + (root.inspectedCapture.regdomain || "—") : "historical radio metadata unavailable"); color: backend.textPrimary; font.pixelSize: 9; lineHeight: 1.2; wrapMode: Text.Wrap }
            }

            Rectangle {
                x: 303; y: 160
                width: 1
                height: 205
                color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.70)
            }

            Column {
                x: 320; y: 146
                width: parent.width - 335
                spacing: 10

                Text { text: "FILE + INTEGRITY"; color: backend.textMuted; font.pixelSize: 9; font.bold: true }
                Text { width: parent.width; text: "Type\n" + (root.pcap.file_type || "—"); color: backend.textPrimary; font.pixelSize: 9; lineHeight: 1.2 }
                Text { width: parent.width; text: "Encapsulation\n" + (root.pcap.encapsulation || "—"); color: backend.textPrimary; font.pixelSize: 9; lineHeight: 1.2; wrapMode: Text.Wrap }
                Text { width: parent.width; text: "Integrity\n" + (root.integrity.state || (root.inspecting ? "checking" : "—")); color: root.integrityColor(root.integrity.state); font.pixelSize: 9; font.bold: true; lineHeight: 1.2 }
                Text { width: parent.width; text: "Metadata\n" + (root.inspectedCapture.metadata_state || root.selectedCapture.metadata_state || "—"); color: root.metadataColor(root.inspectedCapture.metadata_state || root.selectedCapture.metadata_state); font.pixelSize: 9; lineHeight: 1.2 }
            }

            Rectangle {
                x: 15; y: 380
                width: parent.width - 30
                height: 1
                color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.70)
            }

            Text { x: 15; y: 394; text: "FIRST FRAME"; color: backend.textMuted; font.pixelSize: 8; font.bold: true }
            Text { x: 100; y: 392; width: parent.width - 115; text: root.formatEpoch(root.pcap.start_epoch); color: backend.textPrimary; font.pixelSize: 9; elide: Text.ElideRight }
            Text { x: 15; y: 417; text: "LAST FRAME"; color: backend.textMuted; font.pixelSize: 8; font.bold: true }
            Text { x: 100; y: 415; width: parent.width - 115; text: root.formatEpoch(root.pcap.end_epoch); color: backend.textPrimary; font.pixelSize: 9; elide: Text.ElideRight }

            Text {
                x: 15; y: 443
                text: "PROTOCOLS"
                color: backend.textMuted
                font.pixelSize: 8
                font.bold: true
            }

            Flow {
                x: 100; y: 438
                width: parent.width - 115
                height: 29
                spacing: 5

                Repeater {
                    model: root.protocols.slice(0, 4)
                    delegate: Rectangle {
                        required property var modelData
                        width: protocolLabel.implicitWidth + 14
                        height: 24
                        radius: 8
                        color: Qt.rgba(backend.info.r, backend.info.g, backend.info.b, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(backend.info.r, backend.info.g, backend.info.b, 0.30)
                        Text {
                            id: protocolLabel
                            anchors.centerIn: parent
                            text: modelData.name + " " + modelData.count
                            color: backend.textPrimary
                            font.pixelSize: 8
                        }
                    }
                }

                Text {
                    visible: root.protocols.length === 0
                    height: 24
                    text: root.analyzingProtocols ? "Reading saved PCAP…" : "No offline protocol labels"
                    color: root.analyzingProtocols ? backend.info : backend.textMuted
                    font.pixelSize: 8
                    verticalAlignment: Text.AlignVCenter
                }
            }

            CyberButton {
                x: 15; y: 477
                width: 122; height: 34
                label: root.actionBusy ? "WORKING" : "REVEAL"
                icon: "folder_open"
                compact: true
                enabled: root.revealAvailable && !root.actionBusy
                accentColor: backend.dmsPrimary
                textColor: backend.textPrimary
                mutedColor: backend.textMuted
                onClicked: root.revealSelected()
            }

            CyberButton {
                x: 145; y: 477
                width: 168; height: 34
                label: root.viewerAvailable ? "OPEN WIRESHARK" : "WIRESHARK N/A"
                icon: "troubleshoot"
                compact: true
                enabled: root.viewerAvailable && !root.actionBusy
                accentColor: backend.info
                textColor: backend.textPrimary
                mutedColor: backend.textMuted
                onClicked: root.openSelected()
            }

            Text {
                x: 324; y: 484
                width: parent.width - 339
                text: root.actionMessage.length > 0
                      ? root.actionMessage
                      : (!root.viewerStatus.graphical_session
                         ? "No graphical session"
                         : (root.viewerAvailable ? "Saved-PCAP viewer ready" : "GUI Wireshark not installed"))
                color: root.actionMessage.length > 0 ? backend.textPrimary : (root.viewerAvailable ? backend.success : backend.textMuted)
                font.pixelSize: 8
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
