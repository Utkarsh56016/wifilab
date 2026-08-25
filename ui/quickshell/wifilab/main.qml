//@ pragma AppId io.github.utkarsh56016.wifilab
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: app

    // -----------------------------
    // Runtime state
    // -----------------------------
    property var adapters: []
    property var status: ({ selected: false, present: false })
    property var radio: ({ present: false, channel: 0, frequency_mhz: 0, band: "unknown" })
    property var channels: []
    property var protocols: []
    property var activity: ["WiFiLab UI started"]

    property int activeTab: 0
    property int inspectedIndex: -1
    property bool inspectingProtected: false
    property bool helperReady: false
    property bool actionBusy: false
    property bool detailsExpanded: false
    property bool diagnosticsExpanded: false
    property bool riskConfirmVisible: false
    property bool protocolAvailable: false
    property bool protocolPermitted: false
    property int protocolSamplePackets: 0

    // Telemetry deltas are calculated in the UI from read-only kernel counters.
    property double lastTelemetryTime: 0
    property double lastRxBytes: 0
    property double lastTxBytes: 0
    property double lastRxPackets: 0
    property double lastTxPackets: 0
    property double rxRate: 0
    property double txRate: 0
    property double rxPacketRate: 0
    property double txPacketRate: 0

    // -----------------------------
    // DMS-aligned palette
    // -----------------------------
    property color dmsPrimary: "#9CCBFF"
    property color surface: "#12171E"
    property color surfaceHigh: "#1A2028"
    property color surfaceRaised: "#202832"
    property color textPrimary: "#EDF2F7"
    property color textMuted: "#95A2AF"
    property color outline: "#3D4A58"
    property color success: "#45E56A"
    property color warning: "#FFBC45"
    property color error: "#FF5D68"
    property color info: "#58D8FF"
    property color monitorAccent: "#42E85F"
    property color violet: "#B98AFF"

    readonly property var inspectedAdapter: inspectedIndex >= 0 && inspectedIndex < adapters.length ? adapters[inspectedIndex] : ({})
    readonly property bool protectedView: inspectingProtected || status.protected === true
    readonly property string currentMode: inspectingProtected ? (inspectedAdapter.type || "managed") : (status.mode || "unknown")
    readonly property string currentNmState: inspectingProtected ? (inspectedAdapter.nm_state || "unknown") : (status.nm_state || "unknown")
    readonly property string currentInterface: inspectingProtected ? (inspectedAdapter.interface || "—") : (status.interface || "—")
    readonly property string currentPhy: inspectingProtected ? (inspectedAdapter.phy || "—") : (status.phy || "—")
    readonly property string currentDriver: inspectingProtected ? (inspectedAdapter.driver || "—") : (status.driver || "—")
    readonly property string currentDeviceName: inspectingProtected ? (inspectedAdapter.device_name || "Wireless adapter") : (status.device_name || "Selected wireless adapter")
    readonly property bool monitorMode: currentMode === "monitor"
    readonly property color accent: monitorMode && !protectedView ? monitorAccent : dmsPrimary

    // -----------------------------
    // Utility functions
    // -----------------------------
    function parseJson(text, fallback) {
        try { return JSON.parse(text) } catch (e) { return fallback }
    }

    function findColor(obj, names) {
        if (!obj || typeof obj !== "object") return ""
        for (var i = 0; i < names.length; ++i) {
            if (typeof obj[names[i]] === "string" && obj[names[i]].length > 0) return obj[names[i]]
        }
        for (var key in obj) {
            if (obj[key] && typeof obj[key] === "object") {
                var nested = findColor(obj[key], names)
                if (nested) return nested
            }
        }
        return ""
    }

    function applyDmsTheme(data) {
        var v
        v = findColor(data, ["primary"]); if (v) dmsPrimary = v
        v = findColor(data, ["surface"]); if (v) surface = v
        v = findColor(data, ["surfaceContainerHigh", "surface_container_high"]); if (v) surfaceHigh = v
        v = findColor(data, ["surfaceContainerHighest", "surface_container_highest"]); if (v) surfaceRaised = v
        v = findColor(data, ["surfaceText", "onSurface", "on_surface"]); if (v) textPrimary = v
        v = findColor(data, ["surfaceVariantText", "onSurfaceVariant", "on_surface_variant"]); if (v) textMuted = v
        v = findColor(data, ["outline"]); if (v) outline = v
        v = findColor(data, ["success"]); if (v) success = v
        v = findColor(data, ["warning"]); if (v) warning = v
        v = findColor(data, ["error"]); if (v) error = v
        v = findColor(data, ["info"]); if (v) info = v
    }

    function log(message) {
        var copy = activity.slice(0)
        copy.unshift(Qt.formatTime(new Date(), "HH:mm:ss") + "  " + message)
        while (copy.length > 5) copy.pop()
        activity = copy
    }

    function formatRate(value) {
        var n = Math.max(0, Number(value) || 0)
        if (n >= 1048576) return (n / 1048576).toFixed(2) + " MiB/s"
        if (n >= 1024) return (n / 1024).toFixed(1) + " KiB/s"
        return n.toFixed(0) + " B/s"
    }

    function formatPps(value) {
        var n = Math.max(0, Number(value) || 0)
        return n >= 1000 ? (n / 1000).toFixed(1) + " Kpps" : n.toFixed(0) + " pps"
    }

    function adapterIsProtected(a) {
        return a && (a.protected === true || a.role === "system" || (a.nm_state === "connected" && a.connection))
    }

    function applyAdapters(payload) {
        adapters = payload.adapters || []
        var wanted = inspectingProtected ? (inspectedAdapter.interface || "") : (status.interface || "")

        for (var i = 0; i < adapters.length; ++i) {
            if (adapters[i].interface === wanted) {
                inspectedIndex = i
                return
            }
        }

        if (!inspectingProtected && status.present) {
            for (var j = 0; j < adapters.length; ++j) {
                var c = adapters[j]
                if (c.bus === status.bus && c.vendor_id === status.vendor_id && c.model_id === status.model_id && c.driver === status.driver) {
                    inspectedIndex = j
                    return
                }
            }
        }

        if (inspectedIndex < 0 && adapters.length > 0) inspectedIndex = 0
    }

    function inspectAdapter(index) {
        if (index < 0 || index >= adapters.length) return
        inspectedIndex = index
        var a = adapters[index]

        if (adapterIsProtected(a)) {
            inspectingProtected = true
            log("Viewing protected system adapter " + (a.interface || ""))
            return
        }

        inspectingProtected = false
        selectProcess.exec(["wifilab", "select", a.interface])
    }

    function runAction(operation, value) {
        if (actionBusy || !helperReady || protectedView || !status.present) return
        var command = ["pkexec", "/usr/lib/wifilab/wifilab-helper", operation, status.interface]
        if (operation === "channel") command.push(String(value))
        actionBusy = true
        actionProcess.exec(command)
        log("Requested " + operation + " on " + status.interface)
    }

    function requestMonitor() {
        if (protectedView || !status.present || !helperReady) return
        if (status.role === "lab-candidate" && status.bus === "usb") runAction("monitor", 0)
        else riskConfirmVisible = true
    }

    function bandChannels() {
        var wantedBand = radio.band === "5 GHz" ? "5 GHz" : "2.4 GHz"
        var result = []
        for (var i = 0; i < channels.length; ++i) if (channels[i].band === wantedBand) result.push(channels[i])
        return result
    }

    function currentChannelIndex() {
        var list = bandChannels()
        for (var i = 0; i < list.length; ++i) if (Number(list[i].channel) === Number(radio.channel)) return i
        for (var j = 0; j < list.length; ++j) if (!list[j].disabled) return j
        return 0
    }

    function commitChannel(index) {
        var list = bandChannels()
        if (!monitorMode || protectedView || index < 0 || index >= list.length) return
        var channel = list[index]
        if (channel.disabled) {
            log("Channel " + channel.channel + " blocked by kernel/regulatory state")
            return
        }
        runAction("channel", channel.channel)
    }

    function stepChannel(direction) {
        var list = bandChannels()
        if (list.length === 0) return
        var next = currentChannelIndex()
        do {
            next += direction
            if (next < 0 || next >= list.length) return
        } while (list[next].disabled)
        commitChannel(next)
    }

    function applyTelemetry(t) {
        if (!t.present) {
            lastTelemetryTime = 0
            rxRate = txRate = rxPacketRate = txPacketRate = 0
            return
        }

        var time = Number(t.timestamp_ms) || 0
        var rx = Number(t.rx_bytes) || 0
        var tx = Number(t.tx_bytes) || 0
        var rxp = Number(t.rx_packets) || 0
        var txp = Number(t.tx_packets) || 0

        if (lastTelemetryTime > 0 && time > lastTelemetryTime && rx >= lastRxBytes && tx >= lastTxBytes) {
            var dt = (time - lastTelemetryTime) / 1000.0
            rxRate = (rx - lastRxBytes) / dt
            txRate = (tx - lastTxBytes) / dt
            rxPacketRate = (rxp - lastRxPackets) / dt
            txPacketRate = (txp - lastTxPackets) / dt
            trafficGraph.pushSample(rxRate, txRate)
        }

        lastTelemetryTime = time
        lastRxBytes = rx
        lastTxBytes = tx
        lastRxPackets = rxp
        lastTxPackets = txp
    }

    function refreshFast() {
        if (!statusProcess.running) statusProcess.exec(["wifilab", "status", "--json"])
        if (!radioProcess.running) radioProcess.exec(["wifilab", "radio", "--json"])
    }

    function refreshSlow() {
        if (!adapterProcess.running) adapterProcess.exec(["wifilab", "--json"])
        if (!channelProcess.running) channelProcess.exec(["wifilab", "channels", "--json"])
    }

    // -----------------------------
    // Backend processes
    // -----------------------------
    Process {
        id: themeProcess
        stdout: StdioCollector { onStreamFinished: app.applyDmsTheme(app.parseJson(text, {})) }
        Component.onCompleted: exec(["cat", Quickshell.env("HOME") + "/.cache/DankMaterialShell/dms-colors.json"])
    }

    Process {
        id: helperProbe
        onExited: function(code, status) { app.helperReady = code === 0 }
        Component.onCompleted: exec(["test", "-x", "/usr/lib/wifilab/wifilab-helper"])
    }

    Process {
        id: adapterProcess
        stdout: StdioCollector { onStreamFinished: app.applyAdapters(app.parseJson(text, { adapters: [] })) }
    }

    Process {
        id: statusProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var oldIface = app.status.interface || ""
                var oldPresent = app.status.present === true
                app.status = app.parseJson(text, { selected: false, present: false })
                if (!app.inspectingProtected && app.status.present && (!oldPresent || oldIface !== app.status.interface))
                    app.log("Physical identity matched at " + app.status.interface + " / " + (app.status.phy || "unknown PHY"))
            }
        }
    }

    Process {
        id: radioProcess
        stdout: StdioCollector { onStreamFinished: app.radio = app.parseJson(text, { present: false, channel: 0, frequency_mhz: 0, band: "unknown" }) }
    }

    Process {
        id: channelProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = app.parseJson(text, { channels: [] })
                app.channels = parsed.channels || []
            }
        }
    }

    Process {
        id: telemetryProcess
        stdout: StdioCollector { onStreamFinished: app.applyTelemetry(app.parseJson(text, { present: false })) }
    }

    Process {
        id: protocolProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var p = app.parseJson(text, { available: false, permitted: false, protocols: [] })
                app.protocolAvailable = p.available === true
                app.protocolPermitted = p.permitted === true
                app.protocolSamplePackets = Number(p.sample_packets) || 0
                app.protocols = p.protocols || []
            }
        }
    }

    Process {
        id: selectProcess
        stderr: StdioCollector { id: selectErr }
        onExited: function(code, status) {
            app.log(code === 0 ? "Adapter selection updated" : "Selection failed: " + (selectErr.text.trim() || "unknown error"))
            app.inspectingProtected = false
            app.refreshFast()
            app.refreshSlow()
        }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector { id: actionOut }
        stderr: StdioCollector { id: actionErr }
        onExited: function(code, status) {
            app.actionBusy = false
            app.log(code === 0 ? (actionOut.text.trim().split("\n")[0] || "Action completed") : "Action failed: " + (actionErr.text.trim() || "unknown error"))
            app.refreshFast()
            app.refreshSlow()
        }
    }

    Process {
        id: doctorProcess
        stdout: StdioCollector { id: doctorOut }
        onExited: function(code, status) {
            app.diagnosticsExpanded = true
            app.log(code === 0 ? "Doctor checks passed" : "Doctor found a dependency problem")
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!telemetryProcess.running) telemetryProcess.exec(["wifilab", "telemetry", "--json"])
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: app.refreshFast()
    }

    Timer {
        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: app.refreshSlow()
    }

    Timer {
        interval: 6000
        repeat: true
        running: app.activeTab === 1
        triggeredOnStart: true
        onTriggered: if (!protocolProcess.running) protocolProcess.exec(["wifilab", "protocols", "--json"])
    }

    // -----------------------------
    // Window
    // -----------------------------
    FloatingWindow {
        id: win
        visible: true
        title: "WiFiLab"
        implicitWidth: 1040
        implicitHeight: 720
        minimumSize: Qt.size(960, 660)
        maximumSize: Qt.size(1120, 800)
        color: "transparent"
        surfaceFormat.opaque: false
        onClosed: Qt.quit()

        Rectangle {
            id: rootPanel
            anchors.fill: parent
            radius: 24
            clip: true
            color: app.monitorMode && !app.protectedView
                   ? Qt.rgba(0.015, 0.075, 0.035, 0.87)
                   : Qt.rgba(app.surface.r, app.surface.g, app.surface.b, 0.88)
            border.width: 1
            border.color: app.monitorMode && !app.protectedView
                          ? Qt.rgba(app.monitorAccent.r, app.monitorAccent.g, app.monitorAccent.b, 0.56)
                          : Qt.rgba(app.outline.r, app.outline.g, app.outline.b, 0.84)

            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on border.color { ColorAnimation { duration: 220 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                // Header
                Item {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 48
                    Layout.maximumHeight: 48

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9

                        Text {
                            text: "wifi_tethering"
                            color: app.accent
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 26
                        }

                        Text {
                            text: "WiFiLab"
                            color: app.textPrimary
                            font.pixelSize: 22
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "v0.1"
                            color: app.textMuted
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: 210
                        height: parent.height
                        cursorShape: Qt.SizeAllCursor
                        onPressed: win.startSystemMove()
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 246
                        height: 38
                        radius: 14
                        color: Qt.rgba(0, 0, 0, 0.20)
                        border.width: 1
                        border.color: app.outline

                        Row {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4

                            Repeater {
                                model: ["CONTROL", "TRAFFIC"]

                                delegate: Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: 117
                                    height: 30
                                    radius: 10
                                    color: app.activeTab === index ? Qt.rgba(app.accent.r, app.accent.g, app.accent.b, 0.14) : "transparent"
                                    border.width: app.activeTab === index ? 1 : 0
                                    border.color: app.accent

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: app.activeTab === index ? app.textPrimary : app.textMuted
                                        font.pixelSize: 10
                                        font.bold: app.activeTab === index
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: app.activeTab = index
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        IconButton {
                            symbol: "health_and_safety"
                            tip: "Run WiFiLab doctor"
                            foreground: app.success
                            onClicked: doctorProcess.exec(["wifilab", "doctor"])
                        }
                        IconButton {
                            symbol: "refresh"
                            tip: "Refresh adapter state"
                            foreground: app.textPrimary
                            onClicked: { app.refreshFast(); app.refreshSlow() }
                        }
                        IconButton {
                            symbol: "close"
                            tip: "Close UI; adapter state persists"
                            foreground: app.textPrimary
                            onClicked: Qt.quit()
                        }
                    }
                }

                // Adapter + safety row: fixed height, never stretches.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 78
                    Layout.maximumHeight: 78
                    spacing: 9

                    AdapterSelector {
                        id: selector
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        adapters: app.adapters
                        currentIndex: app.inspectedIndex
                        surfaceColor: app.surface
                        surfaceRaised: app.surfaceRaised
                        outlineColor: app.outline
                        textColor: app.textPrimary
                        mutedColor: app.textMuted
                        accentColor: app.accent
                        successColor: app.success
                        warningColor: app.warning
                        onActivated: function(index) { app.inspectAdapter(index) }
                    }

                    GlassCard {
                        Layout.preferredWidth: 205
                        Layout.fillHeight: true
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            StatusDot {
                                dotColor: app.inspectingProtected ? app.warning : (app.status.present ? app.success : app.warning)
                                pulse: !app.inspectingProtected && app.status.selected && !app.status.present
                            }
                            Column {
                                spacing: 2
                                Text {
                                    text: app.inspectingProtected ? "System protected" : (app.status.present ? "Identity matched" : "Adapter absent")
                                    color: app.inspectingProtected ? app.warning : (app.status.present ? app.success : app.warning)
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                                Text {
                                    text: app.inspectingProtected ? "Controls disabled" : (app.status.present ? app.currentInterface + " / " + app.currentPhy : "Watching for replug")
                                    color: app.textMuted
                                    font.pixelSize: 8
                                }
                            }
                        }
                    }

                    GlassCard {
                        Layout.preferredWidth: 215
                        Layout.fillHeight: true
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "shield"
                                color: app.success
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 23
                            }
                            Column {
                                spacing: 2
                                Text { text: "System link protected"; color: app.success; font.pixelSize: 10; font.bold: true }
                                Text { text: "NM + default-route guard"; color: app.textMuted; font.pixelSize: 8 }
                            }
                        }
                    }

                    GlassCard {
                        Layout.preferredWidth: 84
                        Layout.fillHeight: true
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline
                        Text {
                            anchors.centerIn: parent
                            text: "REG: " + (app.status.regdomain || "—")
                            color: app.status.regdomain ? app.success : app.textMuted
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                }

                // Selected adapter missing state.
                GlassCard {
                    visible: !app.inspectingProtected && app.status.selected && !app.status.present
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fillColor: app.surfaceHigh
                    outlineColor: app.warning

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "usb_off"; color: app.warning; font.family: "Material Symbols Rounded"; font.pixelSize: 44 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Selected adapter not present"; color: app.textPrimary; font.pixelSize: 18; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Saved physical identity is retained. Replug will recover automatically."; color: app.textMuted; font.pixelSize: 10 }
                    }
                }

                StackLayout {
                    visible: app.inspectingProtected || !app.status.selected || app.status.present
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: app.activeTab

                    // =========================================================
                    // CONTROL TAB
                    // =========================================================
                    Item {
                        RowLayout {
                            anchors.fill: parent
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 9

                                // Mode card
                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 166
                                    Layout.maximumHeight: 166
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.monitorMode && !app.protectedView ? app.monitorAccent : app.outline

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 15
                                        spacing: 9

                                        Text { text: "MODE"; color: app.textMuted; font.pixelSize: 9; font.bold: true }

                                        Rectangle {
                                            width: parent.width
                                            height: 76
                                            radius: 26
                                            color: Qt.rgba(0, 0, 0, 0.23)
                                            border.width: 1
                                            border.color: app.outline

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 5
                                                spacing: 4

                                                Rectangle {
                                                    width: (parent.width - 4) / 2
                                                    height: parent.height
                                                    radius: 22
                                                    color: !app.monitorMode ? Qt.rgba(app.dmsPrimary.r, app.dmsPrimary.g, app.dmsPrimary.b, 0.13) : "transparent"
                                                    border.width: !app.monitorMode ? 1 : 0
                                                    border.color: app.dmsPrimary
                                                    opacity: app.helperReady && !app.protectedView ? 1.0 : 0.72

                                                    Row {
                                                        anchors.centerIn: parent
                                                        spacing: 8
                                                        Text { text: "wifi"; color: !app.monitorMode ? app.dmsPrimary : app.textMuted; font.family: "Material Symbols Rounded"; font.pixelSize: 24 }
                                                        Text { text: "MAN"; color: !app.monitorMode ? app.textPrimary : app.textMuted; font.pixelSize: 20; font.bold: true }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        enabled: app.helperReady && !app.actionBusy && !app.protectedView && app.status.present
                                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                        onClicked: if (app.monitorMode) app.runAction("restore", 0)
                                                    }
                                                }

                                                Rectangle {
                                                    width: (parent.width - 4) / 2
                                                    height: parent.height
                                                    radius: 22
                                                    color: app.monitorMode ? Qt.rgba(app.monitorAccent.r, app.monitorAccent.g, app.monitorAccent.b, 0.14) : "transparent"
                                                    border.width: app.monitorMode ? 1 : 0
                                                    border.color: app.monitorAccent
                                                    opacity: app.helperReady && !app.protectedView ? 1.0 : 0.72

                                                    Row {
                                                        anchors.centerIn: parent
                                                        spacing: 8
                                                        Text { text: "cell_tower"; color: app.monitorMode ? app.monitorAccent : app.textMuted; font.family: "Material Symbols Rounded"; font.pixelSize: 24 }
                                                        Text { text: "MON"; color: app.monitorMode ? app.monitorAccent : app.textMuted; font.pixelSize: 20; font.bold: true }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        enabled: app.helperReady && !app.actionBusy && !app.protectedView && app.status.present
                                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                        onClicked: if (!app.monitorMode) app.requestMonitor()
                                                    }
                                                }
                                            }
                                        }

                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 6
                                            StatusDot {
                                                dotColor: app.protectedView ? app.warning : (app.monitorMode ? app.monitorAccent : app.dmsPrimary)
                                                pulse: app.monitorMode
                                            }
                                            Text {
                                                text: app.protectedView ? "Protected adapter — mutation disabled" : (app.monitorMode ? "Monitor active • NM unmanaged" : "Managed • NM " + app.currentNmState)
                                                color: app.protectedView ? app.warning : (app.monitorMode ? app.monitorAccent : app.textMuted)
                                                font.pixelSize: 10
                                            }
                                        }
                                    }
                                }

                                // Channel card
                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 164
                                    Layout.maximumHeight: 164
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 15
                                        spacing: 8

                                        Row {
                                            width: parent.width
                                            Text { text: "CHANNEL  •  " + (app.radio.band || "unknown"); color: app.textMuted; font.pixelSize: 9; font.bold: true }
                                            Item { width: Math.max(10, parent.width - 250); height: 1 }
                                            Text {
                                                text: app.radio.channel > 0 ? ("CH " + app.radio.channel + "  •  " + app.radio.frequency_mhz + " MHz") : "No fixed channel"
                                                color: app.textPrimary
                                                font.pixelSize: 10
                                            }
                                        }

                                        Row {
                                            width: parent.width
                                            height: 42
                                            spacing: 9

                                            CyberButton {
                                                width: 42
                                                height: 40
                                                compact: true
                                                label: ""
                                                icon: "remove"
                                                accentColor: app.accent
                                                textColor: app.textPrimary
                                                mutedColor: app.textMuted
                                                enabled: app.monitorMode && !app.protectedView && app.helperReady
                                                onClicked: app.stepChannel(-1)
                                            }

                                            Item {
                                                id: channelTrack
                                                width: parent.width - 102
                                                height: 40

                                                readonly property var list: app.bandChannels()
                                                readonly property int idx: app.currentChannelIndex()
                                                readonly property real fraction: list.length > 1 ? idx / (list.length - 1) : 0

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 5
                                                    radius: 3
                                                    color: Qt.rgba(app.outline.r, app.outline.g, app.outline.b, 0.65)
                                                }

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: Math.max(0, (parent.width - 14) * channelTrack.fraction + 7)
                                                    height: 5
                                                    radius: 3
                                                    color: app.monitorMode ? app.monitorAccent : app.dmsPrimary
                                                }

                                                Rectangle {
                                                    width: 16
                                                    height: 16
                                                    radius: 8
                                                    y: (parent.height - height) / 2
                                                    x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * channelTrack.fraction))
                                                    color: app.monitorMode ? app.monitorAccent : app.dmsPrimary
                                                    border.width: 2
                                                    border.color: Qt.rgba(1, 1, 1, 0.22)
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: app.monitorMode && !app.protectedView && app.helperReady && channelTrack.list.length > 0
                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: function(mouse) {
                                                        var raw = Math.round((mouse.x / Math.max(1, width)) * Math.max(0, channelTrack.list.length - 1))
                                                        app.commitChannel(Math.max(0, Math.min(channelTrack.list.length - 1, raw)))
                                                    }
                                                }
                                            }

                                            CyberButton {
                                                width: 42
                                                height: 40
                                                compact: true
                                                label: ""
                                                icon: "add"
                                                accentColor: app.accent
                                                textColor: app.textPrimary
                                                mutedColor: app.textMuted
                                                enabled: app.monitorMode && !app.protectedView && app.helperReady
                                                onClicked: app.stepChannel(1)
                                            }
                                        }

                                        Text {
                                            property var selectedChannel: app.bandChannels().length > 0 ? app.bandChannels()[app.currentChannelIndex()] : ({})
                                            text: selectedChannel.channel ? ("CH " + selectedChannel.channel + " • " + selectedChannel.frequency_mhz + " MHz" + (selectedChannel.radar ? " • DFS" : "") + (selectedChannel.no_ir ? " • NO IR" : "") + (selectedChannel.disabled ? " • BLOCKED" : "")) : "Channel information unavailable"
                                            color: selectedChannel.disabled ? app.error : ((selectedChannel.radar || selectedChannel.no_ir) ? app.warning : app.textMuted)
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            text: "Kernel/regulatory state is authoritative  •  future: fixed/channel-hop mode"
                                            color: app.textMuted
                                            font.pixelSize: 8
                                            opacity: 0.72
                                        }
                                    }
                                }

                                // Details card fills remaining height.
                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 13
                                        spacing: 8

                                        Row {
                                            width: parent.width
                                            Text { text: "DETAILS"; color: app.textMuted; font.pixelSize: 9; font.bold: true }
                                            Item { width: Math.max(10, parent.width - 110); height: 1 }
                                            IconButton {
                                                width: 28
                                                height: 26
                                                symbol: app.detailsExpanded ? "expand_less" : "expand_more"
                                                tip: "Toggle adapter details"
                                                foreground: app.textMuted
                                                onClicked: app.detailsExpanded = !app.detailsExpanded
                                            }
                                        }

                                        GridLayout {
                                            visible: app.detailsExpanded
                                            width: parent.width
                                            columns: 2
                                            columnSpacing: 14
                                            rowSpacing: 5

                                            Text { text: "Device"; color: app.textMuted; font.pixelSize: 9 }
                                            Text { text: app.currentDeviceName; color: app.textPrimary; font.pixelSize: 9; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Text { text: "Runtime"; color: app.textMuted; font.pixelSize: 9 }
                                            Text { text: app.currentInterface + " / " + app.currentPhy; color: app.textPrimary; font.pixelSize: 9 }
                                            Text { text: "Driver"; color: app.textMuted; font.pixelSize: 9 }
                                            Text { text: app.currentDriver; color: app.textPrimary; font.pixelSize: 9 }
                                            Text { text: "MAC"; color: app.textMuted; font.pixelSize: 9 }
                                            Text { text: app.inspectingProtected ? (app.inspectedAdapter.mac || "—") : (app.status.mac || "—"); color: app.textPrimary; font.pixelSize: 9 }
                                            Text { text: "Identity"; color: app.textMuted; font.pixelSize: 9 }
                                            Text { text: app.inspectingProtected ? "system / protected" : "persistent physical match"; color: app.inspectingProtected ? app.warning : app.success; font.pixelSize: 9 }
                                        }

                                        Row {
                                            visible: !app.detailsExpanded
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 7
                                            Text { text: "fingerprint"; color: app.success; font.family: "Material Symbols Rounded"; font.pixelSize: 18 }
                                            Text { text: "Persistent physical identity matched"; color: app.textMuted; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                        }
                                    }
                                }
                            }

                            // Right control rail
                            ColumnLayout {
                                Layout.preferredWidth: 330
                                Layout.fillHeight: true
                                spacing: 9

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 128
                                    Layout.maximumHeight: 128
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.monitorMode ? app.monitorAccent : app.outline

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 15
                                        spacing: 12

                                        Column {
                                            width: parent.width - 78
                                            spacing: 5
                                            Text { text: "RUNTIME INTERFACE"; color: app.textMuted; font.pixelSize: 9; font.bold: true }
                                            Text { text: app.currentInterface + "  •  " + app.currentPhy; color: app.textPrimary; font.pixelSize: 19; font.bold: true }
                                            Text { text: "Driver  " + app.currentDriver; color: app.textMuted; font.pixelSize: 9 }
                                            Text { text: "NM  " + app.currentNmState; color: app.textMuted; font.pixelSize: 9 }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "cell_tower"
                                            color: app.monitorMode ? app.monitorAccent : app.dmsPrimary
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 45
                                        }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: app.monitorMode ? 116 : 84
                                    Layout.maximumHeight: app.monitorMode ? 116 : 84
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.monitorMode ? app.error : app.outline

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 7
                                        Text {
                                            text: app.monitorMode ? "RESTORE / ROLLBACK" : "PRIVILEGE BOUNDARY"
                                            color: app.monitorMode ? app.error : app.success
                                            font.pixelSize: 9
                                            font.bold: true
                                        }

                                        CyberButton {
                                            visible: app.monitorMode
                                            width: parent.width
                                            label: "Restore to Managed"
                                            icon: "settings_backup_restore"
                                            accentColor: app.error
                                            textColor: app.textPrimary
                                            mutedColor: app.textMuted
                                            enabled: app.helperReady && !app.actionBusy && !app.protectedView
                                            onClicked: app.runAction("restore", 0)
                                        }

                                        Text {
                                            visible: !app.monitorMode
                                            width: parent.width
                                            text: app.helperReady ? "Root-owned helper ready • polkit on mutation" : "Read-only gate • privileged helper not installed"
                                            color: app.helperReady ? app.success : app.warning
                                            font.pixelSize: 9
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 6

                                        Row {
                                            width: parent.width
                                            Text { text: "DIAGNOSTICS"; color: app.textMuted; font.pixelSize: 9; font.bold: true }
                                            Item { width: Math.max(10, parent.width - 150); height: 1 }
                                            IconButton {
                                                width: 28
                                                height: 26
                                                symbol: app.diagnosticsExpanded ? "expand_less" : "expand_more"
                                                tip: "Toggle diagnostics"
                                                foreground: app.textMuted
                                                onClicked: app.diagnosticsExpanded = !app.diagnosticsExpanded
                                            }
                                        }

                                        Column {
                                            visible: app.diagnosticsExpanded
                                            spacing: 5
                                            Text { text: "NetworkManager   " + app.currentNmState; color: app.textPrimary; font.pixelSize: 9 }
                                            Text { text: "Monitor support  " + (app.inspectingProtected ? app.inspectedAdapter.monitor_supported : app.status.monitor_supported); color: app.textPrimary; font.pixelSize: 9 }
                                            Text { text: "Regdomain        " + (app.status.regdomain || "unknown"); color: app.textPrimary; font.pixelSize: 9 }
                                            Text { text: "Polkit helper    " + (app.helperReady ? "ready" : "not installed"); color: app.helperReady ? app.success : app.warning; font.pixelSize: 9 }
                                            Text { visible: doctorOut.text.length > 0; width: 285; text: doctorOut.text; color: app.textMuted; font.family: "monospace"; font.pixelSize: 8; wrapMode: Text.Wrap }
                                        }

                                        Column {
                                            visible: !app.diagnosticsExpanded
                                            spacing: 6
                                            Row { spacing: 7; StatusDot { dotColor: app.success } Text { text: "Discovery backend healthy"; color: app.textMuted; font.pixelSize: 9 } }
                                            Row { spacing: 7; StatusDot { dotColor: app.status.regdomain ? app.success : app.warning } Text { text: "Regdomain " + (app.status.regdomain || "unknown"); color: app.textMuted; font.pixelSize: 9 } }
                                            Row { spacing: 7; StatusDot { dotColor: app.helperReady ? app.success : app.warning } Text { text: app.helperReady ? "Guarded mutation path ready" : "Mutation path intentionally disabled"; color: app.textMuted; font.pixelSize: 9 } }
                                        }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 116
                                    Layout.maximumHeight: 116
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 11
                                        spacing: 5
                                        Text { text: "ACTIVITY"; color: app.textMuted; font.pixelSize: 9; font.bold: true }

                                        Repeater {
                                            model: app.activity
                                            delegate: Text {
                                                required property string modelData
                                                required property int index
                                                width: 292
                                                text: modelData
                                                color: index === 0 ? app.textPrimary : app.textMuted
                                                font.pixelSize: 8
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =========================================================
                    // TRAFFIC TAB
                    // =========================================================
                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 9

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.minimumHeight: 76
                                Layout.maximumHeight: 76
                                spacing: 9

                                Repeater {
                                    model: [
                                        { label: "RX", value: app.formatRate(app.rxRate), detail: app.formatPps(app.rxPacketRate), color: app.info },
                                        { label: "TX", value: app.formatRate(app.txRate), detail: app.formatPps(app.txPacketRate), color: app.violet },
                                        { label: "MODE", value: app.currentMode.toUpperCase(), detail: app.currentInterface, color: app.monitorMode ? app.monitorAccent : app.dmsPrimary },
                                        { label: "PROTOCOLS", value: String(app.protocolSamplePackets), detail: app.protocolAvailable ? "frames sampled" : "tshark unavailable", color: app.protocolPermitted ? app.success : app.warning }
                                    ]

                                    delegate: GlassCard {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        fillColor: app.surfaceHigh
                                        outlineColor: app.outline

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 8
                                            StatusDot { dotColor: modelData.color }
                                            Column {
                                                spacing: 1
                                                Text { text: modelData.label; color: app.textMuted; font.pixelSize: 8; font.bold: true }
                                                Text { text: modelData.value; color: modelData.color; font.pixelSize: 15; font.bold: true }
                                                Text { text: modelData.detail; color: app.textMuted; font.pixelSize: 8 }
                                            }
                                        }
                                    }
                                }
                            }

                            GlassCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                fillColor: app.surfaceHigh
                                outlineColor: app.outline

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 13
                                    spacing: 7

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "LIVE ADAPTER TRAFFIC"; color: app.textMuted; font.pixelSize: 9; font.bold: true }
                                        Item { Layout.fillWidth: true }
                                        Text { text: "● RX"; color: app.info; font.pixelSize: 9 }
                                        Text { text: "● TX"; color: app.violet; font.pixelSize: 9 }
                                    }

                                    TrafficGraph {
                                        id: trafficGraph
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        rxColor: app.info
                                        txColor: app.violet
                                        gridColor: Qt.rgba(app.outline.r, app.outline.g, app.outline.b, 0.30)
                                    }

                                    Text {
                                        text: "Read-only /sys/class/net counters • 1 s samples • graph does not require capture privilege"
                                        color: app.textMuted
                                        font.pixelSize: 8
                                    }
                                }
                            }

                            GlassCard {
                                Layout.fillWidth: true
                                Layout.minimumHeight: 126
                                Layout.maximumHeight: 126
                                fillColor: app.surfaceHigh
                                outlineColor: app.outline

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    Column {
                                        Layout.preferredWidth: 225
                                        spacing: 5
                                        Text { text: "PROTOCOL MIX"; color: app.textMuted; font.pixelSize: 9; font.bold: true }
                                        Text {
                                            text: !app.protocolAvailable ? "Optional tshark sampler not installed" : (!app.protocolPermitted ? "Capture permission unavailable" : "Passive short sample")
                                            color: app.protocolPermitted ? app.success : app.warning
                                            font.pixelSize: 9
                                        }
                                        Text {
                                            width: 215
                                            text: "Protocol sampling never invokes pkexec; existing dumpcap permissions only."
                                            color: app.textMuted
                                            font.pixelSize: 8
                                            wrapMode: Text.Wrap
                                        }
                                    }

                                    Rectangle { width: 1; Layout.fillHeight: true; color: app.outline }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: app.protocols
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: protocolText.implicitWidth + 18
                                                height: 28
                                                radius: 10
                                                color: Qt.rgba(app.info.r, app.info.g, app.info.b, 0.08)
                                                border.width: 1
                                                border.color: Qt.rgba(app.info.r, app.info.g, app.info.b, 0.28)
                                                Text { id: protocolText; anchors.centerIn: parent; text: modelData.name + "  " + modelData.count; color: app.textPrimary; font.pixelSize: 8 }
                                            }
                                        }

                                        Text {
                                            visible: app.protocols.length === 0
                                            width: 560
                                            text: app.protocolPermitted ? "No protocol frames observed in this sample." : "Protocol labels will appear here once optional tshark/dumpcap capture capability is configured."
                                            color: app.textMuted
                                            font.pixelSize: 8
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Footer
                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 22
                    Layout.maximumHeight: 22
                    spacing: 7
                    StatusDot { dotColor: app.status.present ? app.success : app.warning }
                    Text { text: app.status.present ? "Backend ready" : "Waiting for selected adapter"; color: app.textMuted; font.pixelSize: 8 }
                    Item { Layout.fillWidth: true }
                    StatusDot { dotColor: app.helperReady ? app.success : app.warning }
                    Text { text: app.helperReady ? "Guarded mutations enabled" : "Read-only mode"; color: app.textMuted; font.pixelSize: 8 }
                    Item { Layout.fillWidth: true }
                    Text { text: "Agent-ready JSON contract • UI unprivileged"; color: app.textMuted; font.pixelSize: 8 }
                }
            }

            // Risk confirmation is an in-window overlay, not a Qt Quick Controls Dialog.
            Item {
                anchors.fill: parent
                visible: app.riskConfirmVisible
                z: 200

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.62)
                    MouseArea { anchors.fill: parent; onClicked: app.riskConfirmVisible = false }
                }

                GlassCard {
                    width: 440
                    height: 208
                    anchors.centerIn: parent
                    fillColor: app.surfaceRaised
                    outlineColor: app.warning

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        Row {
                            spacing: 9
                            Text { text: "warning"; color: app.warning; font.family: "Material Symbols Rounded"; font.pixelSize: 24 }
                            Text { text: "Confirm monitor mode"; color: app.textPrimary; font.pixelSize: 16; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Text {
                            width: parent.width
                            text: "This adapter is not classified as the known idle USB lab candidate. The privileged helper will revalidate wireless state, NetworkManager activity, and IPv4/IPv6 default-route ownership before any mutation."
                            color: app.textMuted
                            font.pixelSize: 10
                            wrapMode: Text.Wrap
                        }

                        Row {
                            anchors.right: parent.right
                            spacing: 9
                            CyberButton {
                                label: "Cancel"
                                accentColor: app.outline
                                textColor: app.textPrimary
                                mutedColor: app.textMuted
                                onClicked: app.riskConfirmVisible = false
                            }
                            CyberButton {
                                label: "Enter Monitor"
                                icon: "cell_tower"
                                accentColor: app.warning
                                textColor: app.textPrimary
                                mutedColor: app.textMuted
                                onClicked: {
                                    app.riskConfirmVisible = false
                                    app.runAction("monitor", 0)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
