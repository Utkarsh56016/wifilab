//@ pragma AppId io.github.utkarsh56016.wifilab
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: app

    property var adapters: []
    property var adapterLabels: []
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
    property bool protocolAvailable: false
    property bool protocolPermitted: false
    property int protocolSamplePackets: 0

    property double lastTelemetryTime: 0
    property double lastRxBytes: 0
    property double lastTxBytes: 0
    property double lastRxPackets: 0
    property double lastTxPackets: 0
    property double rxRate: 0
    property double txRate: 0
    property double rxPacketRate: 0
    property double txPacketRate: 0

    // DMS-compatible fallback palette. At launch we read DMS' generated palette
    // and replace any values we can identify without importing DMS internals.
    property color dmsPrimary: "#9CCBFF"
    property color surface: "#141820"
    property color surfaceHigh: "#1B2029"
    property color surfaceHighest: "#222832"
    property color textPrimary: "#EAF1F7"
    property color textMuted: "#9AA9B7"
    property color outline: "#43505F"
    property color success: "#4CE56B"
    property color warning: "#FFBC45"
    property color error: "#FF5D68"
    property color info: "#58D8FF"
    property color monitorAccent: "#42E85F"
    property color accent: monitorMode && !inspectingProtected ? monitorAccent : dmsPrimary

    readonly property var inspectedAdapter: inspectedIndex >= 0 && inspectedIndex < adapters.length ? adapters[inspectedIndex] : ({})
    readonly property bool protectedView: inspectingProtected || status.protected === true
    readonly property string currentMode: inspectingProtected ? (inspectedAdapter.type || "managed") : (status.mode || "unknown")
    readonly property string currentNmState: inspectingProtected ? (inspectedAdapter.nm_state || "unknown") : (status.nm_state || "unknown")
    readonly property string currentInterface: inspectingProtected ? (inspectedAdapter.interface || "—") : (status.interface || "—")
    readonly property string currentPhy: inspectingProtected ? (inspectedAdapter.phy || "—") : (status.phy || "—")
    readonly property string currentDriver: inspectingProtected ? (inspectedAdapter.driver || "—") : (status.driver || "—")
    readonly property string currentDeviceName: inspectingProtected ? (inspectedAdapter.device_name || "Wireless adapter") : (status.device_name || "Selected wireless adapter")
    readonly property bool monitorMode: currentMode === "monitor"

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
        v = findColor(data, ["surfaceContainerHighest", "surface_container_highest"]); if (v) surfaceHighest = v
        v = findColor(data, ["surfaceText", "onSurface", "on_surface"]); if (v) textPrimary = v
        v = findColor(data, ["surfaceVariantText", "onSurfaceVariant", "on_surface_variant"]); if (v) textMuted = v
        v = findColor(data, ["outline"]); if (v) outline = v
        v = findColor(data, ["success"]); if (v) success = v
        v = findColor(data, ["warning"]); if (v) warning = v
        v = findColor(data, ["error"]); if (v) error = v
        v = findColor(data, ["info"]); if (v) info = v
    }

    function log(message) {
        var a = activity.slice(0)
        a.unshift(Qt.formatTime(new Date(), "HH:mm:ss") + "  " + message)
        while (a.length > 5) a.pop()
        activity = a
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

    function applyAdapters(payload) {
        adapters = payload.adapters || []
        var labels = []
        for (var i = 0; i < adapters.length; ++i) {
            var a = adapters[i]
            var protectedText = (a.role === "system" || (a.nm_state === "connected" && a.connection)) ? "  • SYSTEM PROTECTED" : ""
            labels.push((a.device_name || a.interface) + "  • " + a.interface + protectedText)
        }
        adapterLabels = labels

        var wanted = inspectingProtected ? (inspectedAdapter.interface || "") : (status.interface || "")
        for (var j = 0; j < adapters.length; ++j) {
            if (adapters[j].interface === wanted) {
                inspectedIndex = j
                return
            }
        }
        if (!inspectingProtected && status.present) {
            for (var k = 0; k < adapters.length; ++k) {
                var c = adapters[k]
                if (c.bus === status.bus && c.vendor_id === status.vendor_id && c.model_id === status.model_id && c.driver === status.driver) {
                    inspectedIndex = k
                    return
                }
            }
        }
    }

    function inspectAdapter(index) {
        if (index < 0 || index >= adapters.length) return
        inspectedIndex = index
        var a = adapters[index]
        var isProtected = a.role === "system" || (a.nm_state === "connected" && a.connection)
        if (isProtected) {
            inspectingProtected = true
            log("Viewing protected system adapter " + a.interface)
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
        else riskDialog.open()
    }

    function bandChannels() {
        var wantedBand = radio.band === "5 GHz" ? "5 GHz" : "2.4 GHz"
        var result = []
        for (var i = 0; i < channels.length; ++i) {
            if (channels[i].band === wantedBand) result.push(channels[i])
        }
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
        if (list[index].disabled) {
            log("Channel " + list[index].channel + " is disabled by kernel/regulatory state")
            return
        }
        runAction("channel", list[index].channel)
    }

    function stepChannel(direction) {
        var list = bandChannels()
        var index = currentChannelIndex()
        var next = index
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
                    app.log("Selected identity matched at " + app.status.interface + " / " + (app.status.phy || "unknown PHY"))
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
        stdout: StdioCollector { id: selectOut }
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
        stderr: StdioCollector { id: doctorErr }
        onExited: function(code, status) {
            app.diagnosticsExpanded = true
            app.log(code === 0 ? "Doctor checks passed" : "Doctor found a required dependency problem")
        }
    }

    Timer {
        interval: 1000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: if (!telemetryProcess.running) telemetryProcess.exec(["wifilab", "telemetry", "--json"])
    }
    Timer {
        interval: 2000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: app.refreshFast()
    }
    Timer {
        interval: 4000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: app.refreshSlow()
    }
    Timer {
        interval: 6000; repeat: true; running: app.activeTab === 1; triggeredOnStart: true
        onTriggered: if (!protocolProcess.running) protocolProcess.exec(["wifilab", "protocols", "--json"])
    }

    FloatingWindow {
        id: win
        visible: true
        title: "WiFiLab"
        implicitWidth: 1040
        implicitHeight: 700
        minimumSize: Qt.size(860, 600)
        maximumSize: Qt.size(1280, 860)
        color: "transparent"
        surfaceFormat.opaque: false
        onClosed: Qt.quit()

        BackgroundEffect.blurRegion: Region { item: rootPanel }

        Rectangle {
            id: rootPanel
            anchors.fill: parent
            radius: 24
            color: app.monitorMode && !app.inspectingProtected
                   ? Qt.rgba(0.02, 0.075, 0.04, 0.91)
                   : Qt.rgba(app.surface.r, app.surface.g, app.surface.b, 0.90)
            border.width: 1
            border.color: app.monitorMode && !app.inspectingProtected ? Qt.rgba(app.monitorAccent.r, app.monitorAccent.g, app.monitorAccent.b, 0.50) : app.outline
            clip: true

            Behavior on color { ColorAnimation { duration: 240 } }
            Behavior on border.color { ColorAnimation { duration: 240 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    spacing: 10

                    MouseArea {
                        Layout.preferredWidth: 210
                        Layout.fillHeight: true
                        cursorShape: Qt.SizeAllCursor
                        onPressed: win.startSystemMove()
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 9
                            Text { text: "wifi_tethering"; color: app.accent; font.family: "Material Symbols Rounded"; font.pixelSize: 26 }
                            Text { text: "WiFiLab"; color: app.textPrimary; font.pixelSize: 23; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 270
                        Layout.preferredHeight: 40
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
                                delegate: Button {
                                    required property int index
                                    required property string modelData
                                    width: 129; height: 32
                                    onClicked: app.activeTab = index
                                    contentItem: Text { text: modelData; color: app.activeTab === index ? app.textPrimary : app.textMuted; font.bold: app.activeTab === index; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    background: Rectangle { radius: 10; color: app.activeTab === index ? Qt.rgba(app.accent.r, app.accent.g, app.accent.b, 0.14) : "transparent"; border.width: app.activeTab === index ? 1 : 0; border.color: app.accent }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        visible: app.monitorMode && !app.inspectingProtected
                        text: "RESTORE"
                        enabled: app.helperReady && !app.actionBusy
                        onClicked: app.runAction("restore", 0)
                        contentItem: Text { text: parent.text; color: app.error; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 11; color: Qt.rgba(app.error.r, app.error.g, app.error.b, 0.10); border.width: 1; border.color: app.error }
                    }

                    IconButton { symbol: "health_and_safety"; tip: "Run WiFiLab doctor"; foreground: app.success; onClicked: doctorProcess.exec(["wifilab", "doctor"]) }
                    IconButton { symbol: "refresh"; tip: "Refresh adapters"; onClicked: { app.refreshFast(); app.refreshSlow(); } }
                    IconButton { symbol: "close"; tip: "Close UI; adapter state persists"; onClicked: Qt.quit() }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    spacing: 10

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline
                        ComboBox {
                            id: adapterCombo
                            anchors.fill: parent
                            anchors.margins: 10
                            model: app.adapterLabels
                            currentIndex: app.inspectedIndex
                            onActivated: function(index) { app.inspectAdapter(index) }
                        }
                    }

                    GlassCard {
                        Layout.preferredWidth: 220
                        Layout.fillHeight: true
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline
                        Row {
                            anchors.centerIn: parent
                            spacing: 9
                            StatusDot { dotColor: app.inspectingProtected ? app.warning : (app.status.present ? app.success : app.warning); pulse: !app.inspectingProtected && app.status.selected && !app.status.present }
                            Column {
                                Text { text: app.inspectingProtected ? "System protected" : (app.status.present ? "Physical identity matched" : "Selected device absent"); color: app.inspectingProtected ? app.warning : (app.status.present ? app.success : app.warning); font.bold: true; font.pixelSize: 12 }
                                Text { text: app.inspectingProtected ? "Controls disabled" : (app.status.present ? app.currentInterface + " / " + app.currentPhy : "Watching for replug"); color: app.textMuted; font.pixelSize: 10 }
                            }
                        }
                    }

                    GlassCard {
                        Layout.preferredWidth: 225
                        Layout.fillHeight: true
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline
                        Row {
                            anchors.centerIn: parent
                            spacing: 9
                            Text { text: "shield"; color: app.success; font.family: "Material Symbols Rounded"; font.pixelSize: 24 }
                            Column {
                                Text { text: "System link protected"; color: app.success; font.bold: true; font.pixelSize: 12 }
                                Text { text: "NM + default-route guard"; color: app.textMuted; font.pixelSize: 10 }
                            }
                        }
                    }

                    GlassCard {
                        Layout.preferredWidth: 88
                        Layout.fillHeight: true
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline
                        Text { anchors.centerIn: parent; text: "REG: " + (app.status.regdomain || "—"); color: app.status.regdomain ? app.success : app.textMuted; font.bold: true; font.pixelSize: 11 }
                    }
                }

                GlassCard {
                    visible: !app.inspectingProtected && app.status.selected && !app.status.present
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fillColor: app.surfaceHigh
                    outlineColor: app.warning
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "usb_off"; color: app.warning; font.family: "Material Symbols Rounded"; font.pixelSize: 46 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Selected adapter not present"; color: app.textPrimary; font.pixelSize: 20; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "WiFiLab is watching the saved physical identity and will recover automatically after replug."; color: app.textMuted; font.pixelSize: 11 }
                    }
                }

                StackLayout {
                    visible: app.inspectingProtected || !app.status.selected || app.status.present
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: app.activeTab

                    Item {
                        RowLayout {
                            anchors.fill: parent
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 10

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 180
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.monitorMode && !app.protectedView ? app.monitorAccent : app.outline
                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 17
                                        spacing: 10
                                        Text { text: "MODE"; color: app.textMuted; font.pixelSize: 10; font.bold: true }
                                        Rectangle {
                                            width: parent.width; height: 80; radius: 27
                                            color: Qt.rgba(0, 0, 0, 0.24)
                                            border.width: 1; border.color: app.outline
                                            Row {
                                                anchors.fill: parent; anchors.margins: 5; spacing: 4
                                                Button {
                                                    width: (parent.width - 4) / 2; height: parent.height
                                                    enabled: app.helperReady && !app.actionBusy && !app.protectedView && app.status.present
                                                    onClicked: if (app.monitorMode) app.runAction("restore", 0)
                                                    contentItem: Text { text: "MAN"; color: !app.monitorMode ? app.textPrimary : app.textMuted; font.pixelSize: 21; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                    background: Rectangle { radius: 23; color: !app.monitorMode ? Qt.rgba(app.dmsPrimary.r, app.dmsPrimary.g, app.dmsPrimary.b, 0.13) : "transparent"; border.width: !app.monitorMode ? 1 : 0; border.color: app.dmsPrimary }
                                                }
                                                Button {
                                                    width: (parent.width - 4) / 2; height: parent.height
                                                    enabled: app.helperReady && !app.actionBusy && !app.protectedView && app.status.present
                                                    onClicked: if (!app.monitorMode) app.requestMonitor()
                                                    contentItem: Text { text: "MON"; color: app.monitorMode ? app.monitorAccent : app.textMuted; font.pixelSize: 21; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                    background: Rectangle { radius: 23; color: app.monitorMode ? Qt.rgba(app.monitorAccent.r, app.monitorAccent.g, app.monitorAccent.b, 0.14) : "transparent"; border.width: app.monitorMode ? 1 : 0; border.color: app.monitorAccent }
                                                }
                                            }
                                        }
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 7
                                            StatusDot { dotColor: app.protectedView ? app.warning : (app.monitorMode ? app.monitorAccent : app.dmsPrimary); pulse: app.monitorMode }
                                            Text { text: app.protectedView ? "Protected adapter — mutation disabled" : (app.monitorMode ? "Monitor active • NM unmanaged" : "Managed • NM " + app.currentNmState); color: app.protectedView ? app.warning : (app.monitorMode ? app.monitorAccent : app.textMuted); font.pixelSize: 11 }
                                        }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 190
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline
                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 8
                                        Row {
                                            width: parent.width
                                            Text { text: "CHANNEL  •  " + (app.radio.band || "unknown"); color: app.textMuted; font.pixelSize: 10; font.bold: true }
                                            Item { width: parent.width - 260; height: 1 }
                                            Text { text: app.radio.channel > 0 ? ("CH " + app.radio.channel + "  •  " + app.radio.frequency_mhz + " MHz") : "No fixed channel"; color: app.textPrimary; font.pixelSize: 11 }
                                        }
                                        Row {
                                            width: parent.width
                                            spacing: 9
                                            Button { width: 42; height: 38; text: "−"; enabled: app.monitorMode && !app.protectedView; onClicked: app.stepChannel(-1) }
                                            Slider {
                                                id: channelSlider
                                                width: parent.width - 102
                                                from: 0
                                                to: Math.max(0, app.bandChannels().length - 1)
                                                stepSize: 1
                                                snapMode: Slider.SnapAlways
                                                value: app.currentChannelIndex()
                                                enabled: app.monitorMode && !app.protectedView && app.bandChannels().length > 0
                                                onPressedChanged: if (!pressed) app.commitChannel(Math.round(value))
                                            }
                                            Button { width: 42; height: 38; text: "+"; enabled: app.monitorMode && !app.protectedView; onClicked: app.stepChannel(1) }
                                        }
                                        Text {
                                            property var selectedChannel: app.bandChannels().length > 0 ? app.bandChannels()[Math.round(channelSlider.value)] : ({})
                                            text: selectedChannel.channel ? ("CH " + selectedChannel.channel + " • " + selectedChannel.frequency_mhz + " MHz" + (selectedChannel.radar ? " • DFS" : "") + (selectedChannel.no_ir ? " • NO IR" : "") + (selectedChannel.disabled ? " • BLOCKED" : "")) : "Channel information unavailable"
                                            color: selectedChannel.disabled ? app.error : ((selectedChannel.radar || selectedChannel.no_ir) ? app.warning : app.textMuted)
                                            font.pixelSize: 11
                                        }
                                        Text { text: "Kernel/regulatory state is authoritative • future: fixed/channel-hop mode"; color: app.textMuted; font.pixelSize: 9; opacity: 0.75 }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline
                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 13
                                        spacing: 7
                                        Row {
                                            width: parent.width
                                            Text { text: "DETAILS"; color: app.textMuted; font.bold: true; font.pixelSize: 10 }
                                            Item { width: parent.width - 120; height: 1 }
                                            IconButton { width: 30; height: 26; symbol: app.detailsExpanded ? "expand_less" : "expand_more"; tip: "Toggle adapter details"; onClicked: app.detailsExpanded = !app.detailsExpanded }
                                        }
                                        GridLayout {
                                            visible: app.detailsExpanded
                                            columns: 2; columnSpacing: 16; rowSpacing: 5
                                            Text { text: "Device"; color: app.textMuted } Text { text: app.currentDeviceName; color: app.textPrimary; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Text { text: "Runtime"; color: app.textMuted } Text { text: app.currentInterface + " / " + app.currentPhy; color: app.textPrimary }
                                            Text { text: "Driver"; color: app.textMuted } Text { text: app.currentDriver; color: app.textPrimary }
                                            Text { text: "MAC"; color: app.textMuted } Text { text: app.inspectingProtected ? (app.inspectedAdapter.mac || "—") : (app.status.mac || "—"); color: app.textPrimary }
                                            Text { text: "Identity"; color: app.textMuted } Text { text: app.inspectingProtected ? "system / protected" : "persistent physical match"; color: app.inspectingProtected ? app.warning : app.success }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 350
                                Layout.fillHeight: true
                                spacing: 10

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 135
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.monitorMode ? app.monitorAccent : app.outline
                                    Row {
                                        anchors.fill: parent; anchors.margins: 16; spacing: 14
                                        Column {
                                            width: parent.width - 92; spacing: 6
                                            Text { text: "RUNTIME INTERFACE"; color: app.textMuted; font.pixelSize: 10; font.bold: true }
                                            Text { text: app.currentInterface + "  •  " + app.currentPhy; color: app.textPrimary; font.pixelSize: 20; font.bold: true }
                                            Text { text: "Driver: " + app.currentDriver; color: app.textMuted; font.pixelSize: 10 }
                                            Text { text: "NM: " + app.currentNmState; color: app.textMuted; font.pixelSize: 10 }
                                        }
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: "cell_tower"; color: app.monitorMode ? app.monitorAccent : app.dmsPrimary; font.family: "Material Symbols Rounded"; font.pixelSize: 50 }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: app.monitorMode ? 125 : 90
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.monitorMode ? app.error : app.outline
                                    Column {
                                        anchors.fill: parent; anchors.margins: 13; spacing: 7
                                        Text { text: app.monitorMode ? "RESTORE / ROLLBACK" : "PRIVILEGE BOUNDARY"; color: app.monitorMode ? app.error : app.success; font.bold: true; font.pixelSize: 10 }
                                        Button {
                                            visible: app.monitorMode
                                            width: parent.width; height: 45
                                            text: "Restore to Managed"
                                            enabled: app.helperReady && !app.actionBusy && !app.protectedView
                                            onClicked: app.runAction("restore", 0)
                                        }
                                        Text { visible: !app.monitorMode; text: app.helperReady ? "Root-owned helper ready • polkit authentication on mutation" : "Read-only UI • install helper to enable mutations"; color: app.helperReady ? app.success : app.warning; font.pixelSize: 10; wrapMode: Text.Wrap; width: parent.width }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline
                                    Column {
                                        anchors.fill: parent; anchors.margins: 13; spacing: 6
                                        Row {
                                            width: parent.width
                                            Text { text: "DIAGNOSTICS"; color: app.textMuted; font.bold: true; font.pixelSize: 10 }
                                            Item { width: parent.width - 170; height: 1 }
                                            IconButton { width: 30; height: 26; symbol: app.diagnosticsExpanded ? "expand_less" : "expand_more"; tip: "Toggle diagnostics"; onClicked: app.diagnosticsExpanded = !app.diagnosticsExpanded }
                                        }
                                        Column {
                                            visible: app.diagnosticsExpanded
                                            spacing: 5
                                            Text { text: "NetworkManager: " + app.currentNmState; color: app.textPrimary; font.pixelSize: 10 }
                                            Text { text: "monitor capability: " + (app.inspectingProtected ? app.inspectedAdapter.monitor_supported : app.status.monitor_supported); color: app.textPrimary; font.pixelSize: 10 }
                                            Text { text: "regdomain: " + (app.status.regdomain || "unknown"); color: app.textPrimary; font.pixelSize: 10 }
                                            Text { text: "polkit helper: " + (app.helperReady ? "ready" : "not installed"); color: app.helperReady ? app.success : app.warning; font.pixelSize: 10 }
                                            Text { visible: doctorOut.text.length > 0; text: doctorOut.text; color: app.textMuted; font.family: "monospace"; font.pixelSize: 8; wrapMode: Text.Wrap; width: 310 }
                                        }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 125
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline
                                    Column {
                                        anchors.fill: parent; anchors.margins: 12; spacing: 5
                                        Text { text: "ACTIVITY"; color: app.textMuted; font.bold: true; font.pixelSize: 10 }
                                        Repeater {
                                            model: app.activity
                                            delegate: Text {
                                                required property string modelData
                                                text: modelData
                                                color: index === 0 ? app.textPrimary : app.textMuted
                                                font.pixelSize: 8
                                                elide: Text.ElideRight
                                                width: 315
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 82
                                spacing: 10
                                Repeater {
                                    model: [
                                        { label: "RX", value: app.formatRate(app.rxRate), detail: app.formatPps(app.rxPacketRate), color: app.info },
                                        { label: "TX", value: app.formatRate(app.txRate), detail: app.formatPps(app.txPacketRate), color: "#B98AFF" },
                                        { label: "MODE", value: app.currentMode.toUpperCase(), detail: app.currentInterface, color: app.monitorMode ? app.monitorAccent : app.dmsPrimary },
                                        { label: "PROTOCOL SAMPLE", value: String(app.protocolSamplePackets), detail: "frames / sample", color: app.protocolPermitted ? app.success : app.warning }
                                    ]
                                    delegate: GlassCard {
                                        required property var modelData
                                        Layout.fillWidth: true; Layout.fillHeight: true
                                        fillColor: app.surfaceHigh; outlineColor: app.outline
                                        Row {
                                            anchors.centerIn: parent; spacing: 9
                                            StatusDot { dotColor: modelData.color }
                                            Column {
                                                Text { text: modelData.label; color: app.textMuted; font.pixelSize: 9; font.bold: true }
                                                Text { text: modelData.value; color: modelData.color; font.pixelSize: 17; font.bold: true }
                                                Text { text: modelData.detail; color: app.textMuted; font.pixelSize: 9 }
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
                                    anchors.fill: parent; anchors.margins: 14; spacing: 7
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "LIVE ADAPTER TRAFFIC"; color: app.textMuted; font.bold: true; font.pixelSize: 10 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: "● RX"; color: app.info; font.pixelSize: 10 }
                                        Text { text: "● TX"; color: "#B98AFF"; font.pixelSize: 10 }
                                    }
                                    TrafficGraph {
                                        id: trafficGraph
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        rxColor: app.info
                                        txColor: "#B98AFF"
                                        gridColor: Qt.rgba(app.outline.r, app.outline.g, app.outline.b, 0.25)
                                    }
                                    Text { text: "Kernel interface counters • 1 s samples • RX/TX graph requires no root or packet capture"; color: app.textMuted; font.pixelSize: 9 }
                                }
                            }

                            GlassCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 145
                                fillColor: app.surfaceHigh
                                outlineColor: app.outline
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 13; spacing: 14
                                    ColumnLayout {
                                        Layout.preferredWidth: 220
                                        Text { text: "PROTOCOL MIX"; color: app.textMuted; font.bold: true; font.pixelSize: 10 }
                                        Text { text: !app.protocolAvailable ? "tshark not installed" : (!app.protocolPermitted ? "Capture permission unavailable" : "Passive short sample"); color: app.protocolPermitted ? app.success : app.warning; font.pixelSize: 10 }
                                        Text { text: "Protocol sampling never invokes pkexec. Existing dumpcap permissions only."; color: app.textMuted; font.pixelSize: 9; wrapMode: Text.Wrap; Layout.fillWidth: true }
                                    }
                                    Rectangle { width: 1; Layout.fillHeight: true; color: app.outline }
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 7
                                        Repeater {
                                            model: app.protocols
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: protocolLabel.implicitWidth + 18; height: 30; radius: 10
                                                color: Qt.rgba(app.info.r, app.info.g, app.info.b, 0.09)
                                                border.width: 1; border.color: Qt.rgba(app.info.r, app.info.g, app.info.b, 0.30)
                                                Text { id: protocolLabel; anchors.centerIn: parent; text: modelData.name + "  " + modelData.count; color: app.textPrimary; font.pixelSize: 9 }
                                            }
                                        }
                                        Text { visible: app.protocols.length === 0; width: 480; text: app.protocolPermitted ? "No protocol frames observed in this sample." : "Protocol details appear here when tshark/dumpcap capture permission is available."; color: app.textMuted; font.pixelSize: 9; wrapMode: Text.Wrap }
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    spacing: 8
                    StatusDot { dotColor: app.status.present ? app.success : app.warning }
                    Text { text: app.status.present ? "Backend ready" : "Waiting for selected adapter"; color: app.textMuted; font.pixelSize: 9 }
                    Item { Layout.fillWidth: true }
                    StatusDot { dotColor: app.helperReady ? app.success : app.warning }
                    Text { text: app.helperReady ? "Guarded mutations enabled" : "Read-only mode"; color: app.textMuted; font.pixelSize: 9 }
                    Item { Layout.fillWidth: true }
                    Text { text: "Agent-ready JSON contract • UI remains unprivileged"; color: app.textMuted; font.pixelSize: 9 }
                }
            }
        }

        Dialog {
            id: riskDialog
            modal: true
            anchors.centerIn: parent
            title: "Confirm monitor mode"
            standardButtons: Dialog.Ok | Dialog.Cancel
            onAccepted: app.runAction("monitor", 0)
            background: Rectangle { color: app.surfaceHighest; radius: 18; border.width: 1; border.color: app.warning }
            contentItem: Text {
                width: 400
                padding: 16
                color: app.textPrimary
                wrapMode: Text.Wrap
                text: "This adapter is not classified as the known idle USB lab candidate. The privileged helper will still revalidate live wireless state, NetworkManager activity, and default-route ownership before changing anything."
            }
        }
    }
}
