//@ pragma AppId io.github.utkarsh56016.wifilab
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: app

    // Runtime state
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
    property bool diagnosticsExpanded: false
    property bool riskConfirmVisible: false
    property bool protocolAvailable: false
    property bool protocolPermitted: false
    property int protocolSamplePackets: 0

    // Telemetry deltas
    property double lastTelemetryTime: 0
    property double lastRxBytes: 0
    property double lastTxBytes: 0
    property double lastRxPackets: 0
    property double lastTxPackets: 0
    property double rxRate: 0
    property double txRate: 0
    property double rxPacketRate: 0
    property double txPacketRate: 0

    // DMS-aligned palette with restrained cyber accents
    property color dmsPrimary: "#9CCBFF"
    property color surface: "#11161D"
    property color surfaceHigh: "#171D25"
    property color surfaceRaised: "#1D252E"
    property color textPrimary: "#EDF2F7"
    property color textMuted: "#96A3AF"
    property color outline: "#3C4856"
    property color success: "#43E66A"
    property color warning: "#FFBC45"
    property color error: "#FF5D68"
    property color info: "#58D8FF"
    property color monitorAccent: "#41E85D"
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

    function adapterIsProtected(adapter) {
        return adapter && (adapter.protected === true || adapter.role === "system" || (adapter.nm_state === "connected" && adapter.connection))
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
        var adapter = adapters[index]

        if (adapterIsProtected(adapter)) {
            inspectingProtected = true
            log("Viewing protected system adapter " + (adapter.interface || ""))
            return
        }

        inspectingProtected = false
        selectProcess.exec(["wifilab", "select", adapter.interface])
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
            trafficView.pushSample(rxRate, txRate)
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

    function runDoctor() {
        if (!doctorProcess.running) doctorProcess.exec(["wifilab", "doctor"])
    }

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

    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!telemetryProcess.running) telemetryProcess.exec(["wifilab", "telemetry", "--json"]) }
    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: app.refreshFast() }
    Timer { interval: 4000; repeat: true; running: true; triggeredOnStart: true; onTriggered: app.refreshSlow() }
    Timer { interval: 6000; repeat: true; running: app.activeTab === 1; triggeredOnStart: true; onTriggered: if (!protocolProcess.running) protocolProcess.exec(["wifilab", "protocols", "--json"]) }

    FloatingWindow {
        id: win
        visible: true
        title: "WiFiLab"
        implicitWidth: 1040
        implicitHeight: 720
        minimumSize: Qt.size(1040, 720)
        maximumSize: Qt.size(1040, 720)
        color: "transparent"
        surfaceFormat.opaque: false
        onClosed: Qt.quit()

        Rectangle {
            id: rootPanel
            anchors.fill: parent
            radius: 24
            clip: true
            color: app.monitorMode && !app.protectedView
                   ? Qt.rgba(0.010, 0.050, 0.025, 0.968)
                   : Qt.rgba(app.surface.r, app.surface.g, app.surface.b, 0.972)
            border.width: 1
            border.color: app.monitorMode && !app.protectedView
                          ? Qt.rgba(app.monitorAccent.r, app.monitorAccent.g, app.monitorAccent.b, 0.62)
                          : Qt.rgba(app.outline.r, app.outline.g, app.outline.b, 0.92)

            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on border.color { ColorAnimation { duration: 220 } }

            Item {
                id: frame
                x: 14; y: 14
                width: 1012; height: 692

                // ------------------------------------------------------
                // Header: 44 px
                // ------------------------------------------------------
                Item {
                    id: header
                    x: 0; y: 0
                    width: parent.width; height: 44

                    Row {
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Text { text: "wifi_tethering"; color: app.success; font.family: "Material Symbols Rounded"; font.pixelSize: 25 }
                        Text { text: "WiFiLab"; color: app.textPrimary; font.pixelSize: 21; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "v0.1.0"; color: app.textMuted; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        x: 0; y: 0; width: 220; height: parent.height
                        cursorShape: Qt.SizeAllCursor
                        onPressed: win.startSystemMove()
                    }

                    Rectangle {
                        x: (parent.width - width) / 2
                        y: 4
                        width: 373
                        height: 36
                        radius: 13
                        color: Qt.rgba(0,0,0,0.24)
                        border.width: 1
                        border.color: app.outline

                        Repeater {
                            model: ["CONTROL", "TRAFFIC", "CAPTURES"]
                            delegate: Rectangle {
                                required property string modelData
                                required property int index
                                x: 4 + index * 123
                                y: 4
                                width: 119
                                height: 28
                                radius: 9
                                color: app.activeTab === index ? Qt.rgba(app.accent.r, app.accent.g, app.accent.b, 0.14) : "transparent"
                                border.width: app.activeTab === index ? 1 : 0
                                border.color: app.accent
                                Text { anchors.centerIn: parent; text: modelData; color: app.activeTab === index ? app.textPrimary : app.textMuted; font.pixelSize: 9; font.bold: app.activeTab === index }
                                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.activeTab = index }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        IconButton { symbol: "health_and_safety"; tip: "Run WiFiLab doctor"; foreground: app.success; onClicked: app.runDoctor() }
                        IconButton { symbol: "refresh"; tip: "Refresh adapter state"; foreground: app.textPrimary; onClicked: { app.refreshFast(); app.refreshSlow() } }
                        IconButton { symbol: "close"; tip: "Close UI; adapter state persists"; foreground: app.textPrimary; onClicked: Qt.quit() }
                    }
                }

                // ------------------------------------------------------
                // Summary strip: y=53, h=74
                // 470 + 9 + 190 + 9 + 225 + 9 + 100 = 1012
                // ------------------------------------------------------
                Item {
                    id: summary
                    x: 0; y: 53
                    width: parent.width; height: 74
                    z: 80

                    AdapterSelector {
                        id: selector
                        x: 0; y: 0
                        width: 470; height: 74
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
                        x: 479; y: 0
                        width: 190; height: 74
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            StatusDot { dotColor: app.inspectingProtected ? app.warning : (app.status.present ? app.success : app.warning); pulse: !app.inspectingProtected && app.status.selected && !app.status.present }
                            Column {
                                spacing: 2
                                Text { text: app.inspectingProtected ? "System protected" : (app.status.present ? "Selected device ✓" : "Adapter absent"); color: app.inspectingProtected ? app.warning : (app.status.present ? app.success : app.warning); font.pixelSize: 9; font.bold: true }
                                Text { text: app.inspectingProtected ? "Controls disabled" : (app.status.present ? "Persistent identity matched" : "Watching for replug"); color: app.textMuted; font.pixelSize: 8 }
                            }
                        }
                    }

                    GlassCard {
                        x: 678; y: 0
                        width: 225; height: 74
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: "shield"; color: app.success; font.family: "Material Symbols Rounded"; font.pixelSize: 22 }
                            Column {
                                spacing: 2
                                Text { text: "System link protected"; color: app.success; font.pixelSize: 9; font.bold: true }
                                Text { text: "NM + default-route guard"; color: app.textMuted; font.pixelSize: 8 }
                            }
                        }
                    }

                    GlassCard {
                        x: 912; y: 0
                        width: 100; height: 74
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline
                        Text { anchors.centerIn: parent; text: "REG: " + (app.status.regdomain || "—"); color: app.status.regdomain ? app.success : app.textMuted; font.pixelSize: 9; font.bold: true }
                    }
                }

                // ------------------------------------------------------
                // Main instrument area: y=136, h=527
                // ------------------------------------------------------
                Item {
                    id: contentArea
                    x: 0; y: 136
                    width: parent.width; height: 527
                    clip: true

                    GlassCard {
                        visible: app.activeTab !== 2 && !app.inspectingProtected && app.status.selected && !app.status.present
                        anchors.fill: parent
                        fillColor: app.surfaceHigh
                        outlineColor: app.warning
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "usb_off"; color: app.warning; font.family: "Material Symbols Rounded"; font.pixelSize: 42 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Selected adapter not present"; color: app.textPrimary; font.pixelSize: 17; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Saved physical identity is retained. WiFiLab will recover automatically after replug."; color: app.textMuted; font.pixelSize: 9 }
                        }
                    }

                    ControlDashboard {
                        anchors.fill: parent
                        visible: (app.inspectingProtected || !app.status.selected || app.status.present) && app.activeTab === 0
                        backend: app
                    }

                    TrafficDashboard {
                        id: trafficView
                        anchors.fill: parent
                        visible: (app.inspectingProtected || !app.status.selected || app.status.present) && app.activeTab === 1
                        backend: app
                    }

                    CapturesDashboard {
                        anchors.fill: parent
                        visible: app.activeTab === 2
                        backend: app
                    }
                }

                // ------------------------------------------------------
                // Footer: y=672, h=20
                // ------------------------------------------------------
                Item {
                    id: footer
                    x: 0; y: 672
                    width: parent.width; height: 20

                    Row {
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7
                        StatusDot { dotColor: app.status.present ? app.success : app.warning }
                        Text { text: app.status.present ? "Backend ready" : "Waiting for selected adapter"; color: app.textMuted; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        x: (parent.width - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7
                        StatusDot { dotColor: app.helperReady ? app.success : app.warning }
                        Text { text: app.helperReady ? "Guarded mutations enabled" : "Read-only mode"; color: app.textMuted; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Agent-ready JSON contract • UI unprivileged"
                        color: app.textMuted
                        font.pixelSize: 8
                    }
                }
            }

            // In-window confirmation overlay
            Item {
                anchors.fill: parent
                visible: app.riskConfirmVisible
                z: 200

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0,0,0,0.72)
                    MouseArea { anchors.fill: parent; onClicked: app.riskConfirmVisible = false }
                }

                GlassCard {
                    width: 430
                    height: 202
                    anchors.centerIn: parent
                    fillColor: app.surfaceRaised
                    outlineColor: app.warning

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 11
                        Row {
                            spacing: 9
                            Text { text: "warning"; color: app.warning; font.family: "Material Symbols Rounded"; font.pixelSize: 23 }
                            Text { text: "Confirm monitor mode"; color: app.textPrimary; font.pixelSize: 15; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Text {
                            width: parent.width
                            text: "This adapter is not the known idle USB lab candidate. The privileged helper will revalidate wireless state, NetworkManager activity, and IPv4/IPv6 default-route ownership before any mutation."
                            color: app.textMuted
                            font.pixelSize: 9
                            wrapMode: Text.Wrap
                        }
                        Row {
                            anchors.right: parent.right
                            spacing: 8
                            CyberButton { label: "Cancel"; accentColor: app.outline; textColor: app.textPrimary; mutedColor: app.textMuted; onClicked: app.riskConfirmVisible = false }
                            CyberButton {
                                label: "Enter Monitor"; icon: "cell_tower"; accentColor: app.warning; textColor: app.textPrimary; mutedColor: app.textMuted
                                onClicked: { app.riskConfirmVisible = false; app.runAction("monitor", 0) }
                            }
                        }
                    }
                }
            }
        }
    }
}
