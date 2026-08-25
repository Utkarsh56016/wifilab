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

    // Runtime models
    property var adapters: []
    property var adapterLabels: []
    property var status: ({ selected: false, present: false })
    property var radio: ({ present: false, channel: 0, frequency_mhz: 0, band: "unknown" })
    property var channels: []
    property var protocols: []
    property bool protocolAvailable: false
    property bool protocolPermitted: false
    property int protocolSamplePackets: 0
    property int activeTab: 0
    property int inspectedIndex: -1
    property bool inspectingProtected: false
    property bool detailsExpanded: false
    property bool diagnosticsExpanded: false
    property bool helperReady: false
    property bool actionBusy: false
    property string actionError: ""
    property var activity: ["WiFiLab UI started"]

    // Telemetry state
    property double lastTelemetryTime: 0
    property double lastRxBytes: 0
    property double lastTxBytes: 0
    property double lastRxPackets: 0
    property double lastTxPackets: 0
    property double rxRate: 0
    property double txRate: 0
    property double rxPacketRate: 0
    property double txPacketRate: 0

    // DMS-like fallback palette. The theme loader replaces these when it can
    // parse ~/.cache/DankMaterialShell/dms-colors.json.
    property color dmsPrimary: "#9CCBFF"
    property color surface: "#E6141820"
    property color surfaceHigh: "#E81B2029"
    property color surfaceHighest: "#F0222832"
    property color textPrimary: "#EAF1F7"
    property color textMuted: "#9AA9B7"
    property color outline: "#43505F"
    property color success: "#4CE56B"
    property color warning: "#FFBC45"
    property color error: "#FF5D68"
    property color info: "#58D8FF"
    property color monitorAccent: "#42E85F"
    property color accent: status.mode === "monitor" && !inspectingProtected ? monitorAccent : dmsPrimary

    readonly property var inspectedAdapter: inspectedIndex >= 0 && inspectedIndex < adapters.length ? adapters[inspectedIndex] : ({})
    readonly property bool selectedPresent: !inspectingProtected && status.present === true
    readonly property bool protectedView: inspectingProtected || (status.protected === true)
    readonly property string currentMode: inspectingProtected ? (inspectedAdapter.type || "managed") : (status.mode || "unknown")
    readonly property string currentNmState: inspectingProtected ? (inspectedAdapter.nm_state || "unknown") : (status.nm_state || "unknown")
    readonly property string currentInterface: inspectingProtected ? (inspectedAdapter.interface || "—") : (status.interface || "—")
    readonly property string currentPhy: inspectingProtected ? (inspectedAdapter.phy || "—") : (status.phy || "—")
    readonly property string currentDriver: inspectingProtected ? (inspectedAdapter.driver || "—") : (status.driver || "—")
    readonly property string currentDeviceName: inspectingProtected ? (inspectedAdapter.device_name || "Wireless adapter") : (status.device_name || "Selected wireless adapter")
    readonly property bool monitorMode: currentMode === "monitor"

    function json(text, fallback) {
        try { return JSON.parse(text) } catch (e) { return fallback }
    }

    function findColor(obj, names) {
        if (!obj || typeof obj !== "object") return ""
        for (var i = 0; i < names.length; ++i) {
            if (obj[names[i]] && typeof obj[names[i]] === "string") return obj[names[i]]
        }
        for (var key in obj) {
            if (obj[key] && typeof obj[key] === "object") {
                var found = findColor(obj[key], names)
                if (found) return found
            }
        }
        return ""
    }

    function applyDmsTheme(data) {
        var v
        v = findColor(data, ["primary"]); if (v) dmsPrimary = v
        v = findColor(data, ["surface"]); if (v) surface = Qt.alpha(v, 0.88)
        v = findColor(data, ["surfaceContainerHigh", "surface_container_high"]); if (v) surfaceHigh = Qt.alpha(v, 0.91)
        v = findColor(data, ["surfaceContainerHighest", "surface_container_highest"]); if (v) surfaceHighest = Qt.alpha(v, 0.96)
        v = findColor(data, ["surfaceText", "onSurface", "on_surface"]); if (v) textPrimary = v
        v = findColor(data, ["surfaceVariantText", "onSurfaceVariant", "on_surface_variant"]); if (v) textMuted = v
        v = findColor(data, ["outline"]); if (v) outline = v
        v = findColor(data, ["success"]); if (v) success = v
        v = findColor(data, ["warning"]); if (v) warning = v
        v = findColor(data, ["error"]); if (v) error = v
        v = findColor(data, ["info"]); if (v) info = v
    }

    function addActivity(message) {
        var a = activity.slice(0)
        var now = new Date()
        a.unshift(Qt.formatTime(now, "HH:mm:ss") + "  " + message)
        while (a.length > 6) a.pop()
        activity = a
    }

    function formatRate(value) {
        var n = Math.max(0, Number(value) || 0)
        if (n >= 1024 * 1024) return (n / (1024 * 1024)).toFixed(2) + " MiB/s"
        if (n >= 1024) return (n / 1024).toFixed(1) + " KiB/s"
        return n.toFixed(0) + " B/s"
    }

    function formatPacketRate(value) {
        var n = Math.max(0, Number(value) || 0)
        if (n >= 1000) return (n / 1000).toFixed(1) + " Kpps"
        return n.toFixed(0) + " pps"
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
        var match = -1
        for (var j = 0; j < adapters.length; ++j) {
            if (adapters[j].interface === wanted) { match = j; break }
        }
        if (match < 0 && !inspectingProtected && status.present) {
            for (var k = 0; k < adapters.length; ++k) {
                var c = adapters[k]
                if (c.bus === status.bus && c.vendor_id === status.vendor_id && c.model_id === status.model_id && c.driver === status.driver) {
                    match = k; break
                }
            }
        }
        if (match >= 0) inspectedIndex = match
    }

    function inspectAdapter(index) {
        if (index < 0 || index >= adapters.length) return
        inspectedIndex = index
        var a = adapters[index]
        var isProtected = a.role === "system" || (a.nm_state === "connected" && a.connection)
        if (isProtected) {
            inspectingProtected = true
            addActivity("Viewing protected system adapter " + a.interface)
            return
        }
        inspectingProtected = false
        selectProcess.exec(["wifilab", "select", a.interface])
    }

    function runAction(operation, channel) {
        if (actionBusy || !helperReady || protectedView || !status.present) return
        var cmd = ["pkexec", "/usr/lib/wifilab/wifilab-helper", operation, status.interface]
        if (operation === "channel") cmd.push(String(channel))
        actionError = ""
        actionBusy = true
        actionProcess.exec(cmd)
        addActivity("Requested " + operation + " on " + status.interface)
    }

    function requestMonitor() {
        if (protectedView || !status.present || !helperReady) return
        if (status.role === "lab-candidate" && status.bus === "usb") {
            runAction("monitor", 0)
        } else {
            riskDialog.open()
        }
    }

    function currentBandChannels() {
        var band = radio.band === "5 GHz" ? "5 GHz" : "2.4 GHz"
        var out = []
        for (var i = 0; i < channels.length; ++i) if (channels[i].band === band) out.push(channels[i])
        return out
    }

    function currentChannelIndex() {
        var list = currentBandChannels()
        for (var i = 0; i < list.length; ++i) if (Number(list[i].channel) === Number(radio.channel)) return i
        for (var j = 0; j < list.length; ++j) if (!list[j].disabled) return j
        return 0
    }

    function commitChannel(index) {
        var list = currentBandChannels()
        if (!monitorMode || protectedView || index < 0 || index >= list.length) return
        var ch = list[index]
        if (ch.disabled) {
            addActivity("Channel " + ch.channel + " is disabled by the kernel/regulatory state")
            return
        }
        runAction("channel", ch.channel)
    }

    function stepChannel(delta) {
        var list = currentBandChannels()
        if (list.length === 0) return
        var index = currentChannelIndex()
        var next = index
        do {
            next += delta
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
            var seconds = (time - lastTelemetryTime) / 1000.0
            rxRate = (rx - lastRxBytes) / seconds
            txRate = (tx - lastTxBytes) / seconds
            rxPacketRate = (rxp - lastRxPackets) / seconds
            txPacketRate = (txp - lastTxPackets) / seconds
            trafficGraph.pushSample(rxRate, txRate)
        }
        lastTelemetryTime = time
        lastRxBytes = rx
        lastTxBytes = tx
        lastRxPackets = rxp
        lastTxPackets = txp
    }

    Process {
        id: themeProcess
        stdout: StdioCollector { onStreamFinished: app.applyDmsTheme(app.json(text, {})) }
        Component.onCompleted: exec(["cat", Quickshell.env("HOME") + "/.cache/DankMaterialShell/dms-colors.json"])
    }

    Process {
        id: helperProbe
        onExited: function(code, status) { app.helperReady = code === 0 }
        Component.onCompleted: exec(["test", "-x", "/usr/lib/wifilab/wifilab-helper"])
    }

    Process {
        id: adapterProcess
        stdout: StdioCollector { onStreamFinished: app.applyAdapters(app.json(text, { adapters: [] })) }
    }

    Process {
        id: statusProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var oldPresent = app.status.present === true
                var oldIface = app.status.interface || ""
                app.status = app.json(text, { selected: false, present: false })
                if (!app.inspectingProtected && app.status.present && (!oldPresent || oldIface !== app.status.interface))
                    app.addActivity("Selected device matched at " + app.status.interface + " / " + (app.status.phy || "unknown PHY"))
            }
        }
    }

    Process {
        id: radioProcess
        stdout: StdioCollector { onStreamFinished: app.radio = app.json(text, { present: false, channel: 0, frequency_mhz: 0, band: "unknown" }) }
    }

    Process {
        id: channelProcess
        stdout: StdioCollector { onStreamFinished: app.channels = app.json(text, { channels: [] }).channels || [] }
    }

    Process {
        id: telemetryProcess
        stdout: StdioCollector { onStreamFinished: app.applyTelemetry(app.json(text, { present: false })) }
    }

    Process {
        id: protocolProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var p = app.json(text, { available: false, permitted: false, protocols: [] })
                app.protocolAvailable = p.available === true
                app.protocolPermitted = p.permitted === true
                app.protocolSamplePackets = p.sample_packets || 0
                app.protocols = p.protocols || []
            }
        }
    }

    Process {
        id: selectProcess
        stdout: StdioCollector { id: selectOut }
        stderr: StdioCollector { id: selectErr }
        onExited: function(code, status) {
            if (code === 0) app.addActivity(selectOut.text.trim().split("\n")[0] || "Adapter selected")
            else app.addActivity("Selection failed: " + (selectErr.text.trim() || "unknown error"))
            app.inspectingProtected = false
            statusProcess.exec(["wifilab", "status", "--json"])
            adapterProcess.exec(["wifilab", "--json"])
            channelProcess.exec(["wifilab", "channels", "--json"])
        }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector { id: actionOut }
        stderr: StdioCollector { id: actionErr }
        onExited: function(code, status) {
            app.actionBusy = false
            if (code === 0) app.addActivity(actionOut.text.trim().split("\n")[0] || "Action completed")
            else {
                app.actionError = actionErr.text.trim() || "Operation failed"
                app.addActivity("Action failed: " + app.actionError)
            }
            statusProcess.exec(["wifilab", "status", "--json"])
            radioProcess.exec(["wifilab", "radio", "--json"])
            adapterProcess.exec(["wifilab", "--json"])
        }
    }

    Process {
        id: doctorProcess
        stdout: StdioCollector { id: doctorOut }
        stderr: StdioCollector { id: doctorErr }
        onExited: function(code, status) {
            app.diagnosticsExpanded = true
            app.addActivity(code === 0 ? "Doctor checks passed" : "Doctor found a missing required dependency")
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!telemetryProcess.running) telemetryProcess.exec(["wifilab", "telemetry", "--json"])
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!statusProcess.running) statusProcess.exec(["wifilab", "status", "--json"])
            if (!radioProcess.running) radioProcess.exec(["wifilab", "radio", "--json"])
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!adapterProcess.running) adapterProcess.exec(["wifilab", "--json"])
            if (!channelProcess.running) channelProcess.exec(["wifilab", "channels", "--json"])
        }
    }

    Timer {
        interval: 6000
        repeat: true
        running: app.activeTab === 1
        triggeredOnStart: true
        onTriggered: if (!protocolProcess.running) protocolProcess.exec(["wifilab", "protocols", "--json"])
    }

    FloatingWindow {
        id: win
        visible: true
        title: "WiFiLab"
        implicitWidth: 1080
        implicitHeight: 720
        minimumSize: Qt.size(880, 620)
        maximumSize: Qt.size(1280, 860)
        color: "transparent"
        surfaceFormat.opaque: false
        onClosed: Qt.quit()

        BackgroundEffect.blurRegion: Region { item: glassRoot }

        Rectangle {
            id: glassRoot
            anchors.fill: parent
            radius: 24
            color: app.monitorMode && !app.inspectingProtected ? Qt.rgba(0.025, 0.08, 0.045, 0.91) : app.surface
            border.width: 1
            border.color: app.monitorMode && !app.inspectingProtected ? Qt.rgba(0.26, 0.91, 0.37, 0.48) : app.outline
            clip: true

            Behavior on color { ColorAnimation { duration: 260 } }
            Behavior on border.color { ColorAnimation { duration: 260 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    spacing: 12

                    MouseArea {
                        Layout.preferredWidth: 230
                        Layout.fillHeight: true
                        onPressed: win.startSystemMove()
                        cursorShape: Qt.SizeAllCursor

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Text {
                                text: "wifi_tethering"
                                color: app.accent
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 27
                            }
                            Text {
                                text: "WiFiLab"
                                color: app.textPrimary
                                font.pixelSize: 24
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                width: 54; height: 25; radius: 10
                                color: Qt.rgba(app.accent.r, app.accent.g, app.accent.b, 0.08)
                                border.width: 1
                                border.color: Qt.rgba(app.accent.r, app.accent.g, app.accent.b, 0.18)
                                Text { anchors.centerIn: parent; text: "v0.1"; color: app.textMuted; font.pixelSize: 11 }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 280
                        Layout.preferredHeight: 42
                        radius: 14
                        color: Qt.rgba(0, 0, 0, 0.18)
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
                                    width: 132; height: 34
                                    text: modelData
                                    hoverEnabled: true
                                    onClicked: app.activeTab = index
                                    contentItem: Text {
                                        text: parent.text
                                        color: app.activeTab === index ? app.textPrimary : app.textMuted
                                        font.pixelSize: 12; font.bold: app.activeTab === index
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        radius: 11
                                        color: app.activeTab === index ? Qt.rgba(app.accent.r, app.accent.g, app.accent.b, 0.14) : "transparent"
                                        border.width: app.activeTab === index ? 1 : 0
                                        border.color: app.accent
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        visible: app.monitorMode && !app.inspectingProtected
                        text: "Restore"
                        hoverEnabled: true
                        onClicked: app.runAction("restore", 0)
                        contentItem: Text { text: parent.text; color: app.error; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 12; color: Qt.rgba(app.error.r, app.error.g, app.error.b, 0.10); border.width: 1; border.color: app.error }
                    }

                    IconButton {
                        symbol: "health_and_safety"
                        tip: "Run WiFiLab doctor"
                        foreground: app.success
                        onClicked: doctorProcess.exec(["wifilab", "doctor"])
                    }
                    IconButton { symbol: "refresh"; tip: "Refresh adapters"; onClicked: { adapterProcess.exec(["wifilab", "--json"]); statusProcess.exec(["wifilab", "status", "--json"]); } }
                    IconButton { symbol: "close"; tip: "Close WiFiLab UI (radio state persists)"; onClicked: Qt.quit() }
                }

                // Adapter / safety strip
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84
                    spacing: 12

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
                            contentItem: Column {
                                leftPadding: 10
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: app.currentDeviceName; color: app.textPrimary; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight; width: adapterCombo.width - 70 }
                                Text { text: app.currentDriver + "  •  runtime " + app.currentInterface + " / " + app.currentPhy; color: app.textMuted; font.pixelSize: 11; elide: Text.ElideRight; width: adapterCombo.width - 70 }
                            }
                            background: Rectangle { color: "transparent"; radius: 12; border.width: 0 }
                            popup: Popup {
                                y: adapterCombo.height + 4
                                width: adapterCombo.width
                                implicitHeight: Math.min(contentItem.implicitHeight + 8, 260)
                                padding: 4
                                background: Rectangle { color: app.surfaceHighest; radius: 14; border.width: 1; border.color: app.outline }
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: adapterCombo.popup.visible ? adapterCombo.delegateModel : null
                                    currentIndex: adapterCombo.highlightedIndex
                                }
                            }
                        }
                    }

                    GlassCard {
                        Layout.preferredWidth: 230
                        Layout.fillHeight: true
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline
                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            StatusDot { dotColor: app.inspectingProtected ? app.warning : (app.status.present ? app.success : app.warning); pulse: !app.inspectingProtected && app.status.selected && !app.status.present }
                            Column {
                                Text { text: app.inspectingProtected ? "System protected" : (app.status.present ? "Selected device matched" : "Selected device absent"); color: app.inspectingProtected ? app.warning : (app.status.present ? app.success : app.warning); font.pixelSize: 13; font.bold: true }
                                Text { text: app.inspectingProtected ? "Mutation controls disabled" : (app.status.present ? "Persistent physical identity" : "Auto-retry is active"); color: app.textMuted; font.pixelSize: 11 }
                            }
                        }
                    }

                    GlassCard {
                        Layout.preferredWidth: 260
                        Layout.fillHeight: true
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline
                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            Text { text: "shield"; color: app.success; font.family: "Material Symbols Rounded"; font.pixelSize: 25 }
                            Column {
                                Text { text: "System link protected"; color: app.success; font.pixelSize: 13; font.bold: true }
                                Text { text: "Connected/default-route guard"; color: app.textMuted; font.pixelSize: 11 }
                            }
                            StatusDot { dotColor: app.success }
                        }
                    }

                    GlassCard {
                        Layout.preferredWidth: 94
                        Layout.fillHeight: true
                        fillColor: app.surfaceHigh
                        outlineColor: app.outline
                        Text { anchors.centerIn: parent; text: "REG: " + (app.status.regdomain || "—"); color: app.status.regdomain ? app.success : app.textMuted; font.bold: true }
                    }
                }

                // Device-absent state
                GlassCard {
                    visible: !app.inspectingProtected && app.status.selected && !app.status.present
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fillColor: Qt.rgba(app.warning.r, app.warning.g, app.warning.b, 0.07)
                    outlineColor: Qt.rgba(app.warning.r, app.warning.g, app.warning.b, 0.55)

                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "usb_off"; color: app.warning; font.family: "Material Symbols Rounded"; font.pixelSize: 46 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Selected adapter not present"; color: app.textPrimary; font.pixelSize: 20; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "WiFiLab is watching for the saved physical identity and will recover automatically after replug."; color: app.textMuted; font.pixelSize: 12 }
                        Button {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Choose another adapter"
                            onClicked: adapterCombo.popup.open()
                        }
                    }
                }

                // Main tab content
                StackLayout {
                    visible: app.inspectingProtected || !app.status.selected || app.status.present
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: app.activeTab

                    // CONTROL TAB
                    Item {
                        RowLayout {
                            anchors.fill: parent
                            spacing: 14

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 12

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 190
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.monitorMode && !app.protectedView ? app.monitorAccent : app.outline

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 18
                                        spacing: 12
                                        Text { text: "MODE"; color: app.textMuted; font.pixelSize: 11; font.bold: true }
                                        Rectangle {
                                            width: parent.width
                                            height: 82
                                            radius: 28
                                            color: Qt.rgba(0, 0, 0, 0.25)
                                            border.width: 1
                                            border.color: app.outline
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 5
                                                spacing: 4
                                                Button {
                                                    width: (parent.width - 4) / 2; height: parent.height
                                                    enabled: !app.actionBusy && app.helperReady && !app.protectedView && app.status.present
                                                    onClicked: if (app.monitorMode) app.runAction("restore", 0)
                                                    contentItem: Text { text: "MAN"; color: !app.monitorMode ? app.textPrimary : app.textMuted; font.pixelSize: 22; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                    background: Rectangle { radius: 24; color: !app.monitorMode ? Qt.rgba(app.dmsPrimary.r, app.dmsPrimary.g, app.dmsPrimary.b, 0.13) : "transparent"; border.width: !app.monitorMode ? 1 : 0; border.color: app.dmsPrimary }
                                                }
                                                Button {
                                                    width: (parent.width - 4) / 2; height: parent.height
                                                    enabled: !app.actionBusy && app.helperReady && !app.protectedView && app.status.present
                                                    onClicked: if (!app.monitorMode) app.requestMonitor()
                                                    contentItem: Text { text: "MON"; color: app.monitorMode ? app.monitorAccent : app.textMuted; font.pixelSize: 22; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                    background: Rectangle { radius: 24; color: app.monitorMode ? Qt.rgba(app.monitorAccent.r, app.monitorAccent.g, app.monitorAccent.b, 0.14) : "transparent"; border.width: app.monitorMode ? 1 : 0; border.color: app.monitorAccent }
                                                }
                                            }
                                        }
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 8
                                            StatusDot { dotColor: app.protectedView ? app.warning : (app.monitorMode ? app.monitorAccent : app.dmsPrimary); pulse: app.monitorMode }
                                            Text { text: app.protectedView ? "Protected adapter — mutation disabled" : (app.monitorMode ? "Monitor mode active • NetworkManager unmanaged" : "Managed mode • NetworkManager " + app.currentNmState); color: app.protectedView ? app.warning : (app.monitorMode ? app.monitorAccent : app.textMuted); font.pixelSize: 12 }
                                        }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 205
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 18
                                        spacing: 9
                                        Row {
                                            width: parent.width
                                            Text { text: "CHANNEL  •  " + (app.radio.band || "unknown"); color: app.textMuted; font.pixelSize: 11; font.bold: true }
                                            Item { width: parent.width - 260; height: 1 }
                                            Text { text: app.radio.channel > 0 ? ("CH " + app.radio.channel + "  •  " + app.radio.frequency_mhz + " MHz") : "No fixed channel"; color: app.textPrimary; font.pixelSize: 12 }
                                        }
                                        Row {
                                            width: parent.width
                                            spacing: 10
                                            Button { width: 44; height: 40; text: "−"; enabled: app.monitorMode && !app.protectedView; onClicked: app.stepChannel(-1) }
                                            Slider {
                                                id: channelSlider
                                                width: parent.width - 108
                                                from: 0
                                                to: Math.max(0, app.currentBandChannels().length - 1)
                                                stepSize: 1
                                                snapMode: Slider.SnapAlways
                                                value: app.currentChannelIndex()
                                                enabled: app.monitorMode && !app.protectedView && app.currentBandChannels().length > 0
                                                onPressedChanged: if (!pressed) app.commitChannel(Math.round(value))
                                            }
                                            Button { width: 44; height: 40; text: "+"; enabled: app.monitorMode && !app.protectedView; onClicked: app.stepChannel(1) }
                                        }
                                        Row {
                                            spacing: 8
                                            Repeater {
                                                model: app.currentBandChannels().length > 0 ? [app.currentBandChannels()[Math.round(channelSlider.value)]] : []
                                                delegate: Row {
                                                    required property var modelData
                                                    spacing: 7
                                                    Rectangle { visible: modelData.radar; width: 56; height: 25; radius: 9; color: Qt.rgba(app.warning.r, app.warning.g, app.warning.b, 0.12); Text { anchors.centerIn: parent; text: "DFS"; color: app.warning; font.pixelSize: 10; font.bold: true } }
                                                    Rectangle { visible: modelData.no_ir; width: 62; height: 25; radius: 9; color: Qt.rgba(app.warning.r, app.warning.g, app.warning.b, 0.12); Text { anchors.centerIn: parent; text: "NO IR"; color: app.warning; font.pixelSize: 10; font.bold: true } }
                                                    Rectangle { visible: modelData.disabled; width: 72; height: 25; radius: 9; color: Qt.rgba(app.error.r, app.error.g, app.error.b, 0.12); Text { anchors.centerIn: parent; text: "BLOCKED"; color: app.error; font.pixelSize: 10; font.bold: true } }
                                                    Text { text: modelData.disabled ? "Kernel/regulatory disabled" : "Kernel-advertised channel"; color: app.textMuted; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                                }
                                            }
                                        }
                                        Text { text: "Future: fixed / channel-hop policy"; color: app.textMuted; font.pixelSize: 10; opacity: 0.7 }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 8
                                        Row {
                                            width: parent.width
                                            Text { text: "DETAILS"; color: app.textMuted; font.bold: true; font.pixelSize: 11 }
                                            Item { width: parent.width - 130; height: 1 }
                                            IconButton { width: 32; height: 28; symbol: app.detailsExpanded ? "expand_less" : "expand_more"; tip: "Toggle adapter details"; onClicked: app.detailsExpanded = !app.detailsExpanded }
                                        }
                                        GridLayout {
                                            visible: app.detailsExpanded
                                            columns: 2
                                            columnSpacing: 20
                                            rowSpacing: 6
                                            Text { text: "Runtime"; color: app.textMuted } Text { text: app.currentInterface + " / " + app.currentPhy; color: app.textPrimary }
                                            Text { text: "Driver"; color: app.textMuted } Text { text: app.currentDriver; color: app.textPrimary }
                                            Text { text: "Bus / ID"; color: app.textMuted } Text { text: (app.inspectingProtected ? app.inspectedAdapter.bus : app.status.bus) + "  " + (app.inspectingProtected ? (app.inspectedAdapter.vendor_id + ":" + app.inspectedAdapter.model_id) : ((app.status.vendor_id || "") + ":" + (app.status.model_id || ""))); color: app.textPrimary }
                                            Text { text: "MAC (runtime)"; color: app.textMuted } Text { text: app.inspectingProtected ? (app.inspectedAdapter.mac || "—") : (app.status.mac || "—"); color: app.textPrimary }
                                            Text { text: "Identity"; color: app.textMuted } Text { text: app.inspectingProtected ? "system/protected" : "persistent physical match"; color: app.inspectingProtected ? app.warning : app.success }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 370
                                Layout.fillHeight: true
                                spacing: 12

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 150
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.monitorMode ? app.monitorAccent : app.outline
                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 18
                                        spacing: 18
                                        Column {
                                            width: parent.width - 115
                                            spacing: 7
                                            Text { text: "RUNTIME INTERFACE"; color: app.textMuted; font.pixelSize: 11; font.bold: true }
                                            Text { text: app.currentInterface + "  •  " + app.currentPhy; color: app.textPrimary; font.pixelSize: 22; font.bold: true }
                                            Text { text: "Link: " + (app.inspectingProtected ? (app.inspectedAdapter.operstate || "unknown") : (app.status.operstate || "unknown")); color: app.textMuted; font.pixelSize: 11 }
                                            Text { text: "Driver: " + app.currentDriver; color: app.textMuted; font.pixelSize: 11 }
                                        }
                                        Item {
                                            width: 88; height: 88
                                            Text { anchors.centerIn: parent; text: "cell_tower"; color: app.monitorMode ? app.monitorAccent : app.dmsPrimary; font.family: "Material Symbols Rounded"; font.pixelSize: 54 }
                                            StatusDot { anchors.right: parent.right; anchors.top: parent.top; dotColor: app.monitorMode ? app.monitorAccent : app.dmsPrimary; pulse: app.monitorMode }
                                        }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: app.monitorMode ? 126 : 92
                                    fillColor: app.monitorMode ? Qt.rgba(app.error.r, app.error.g, app.error.b, 0.07) : app.surfaceHigh
                                    outlineColor: app.monitorMode ? Qt.rgba(app.error.r, app.error.g, app.error.b, 0.50) : app.outline
                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 8
                                        Text { text: app.monitorMode ? "RESTORE / ROLLBACK" : "SAFETY"; color: app.monitorMode ? app.error : app.success; font.pixelSize: 11; font.bold: true }
                                        Button {
                                            visible: app.monitorMode
                                            width: parent.width; height: 48
                                            enabled: app.helperReady && !app.actionBusy && !app.protectedView
                                            text: "Restore to Managed"
                                            onClicked: app.runAction("restore", 0)
                                            contentItem: Text { text: parent.text; color: app.error; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                            background: Rectangle { radius: 12; color: Qt.rgba(app.error.r, app.error.g, app.error.b, 0.12); border.width: 1; border.color: app.error }
                                        }
                                        Text { visible: !app.monitorMode; text: app.helperReady ? "Privileged helper ready • default-route guard active" : "Install UI helper to enable state changes"; color: app.helperReady ? app.success : app.warning; font.pixelSize: 11; wrapMode: Text.Wrap }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline
                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 7
                                        Row {
                                            width: parent.width
                                            Text { text: "DIAGNOSTICS"; color: app.textMuted; font.bold: true; font.pixelSize: 11 }
                                            Item { width: parent.width - 180; height: 1 }
                                            IconButton { width: 32; height: 28; symbol: app.diagnosticsExpanded ? "expand_less" : "expand_more"; tip: "Toggle diagnostics"; onClicked: app.diagnosticsExpanded = !app.diagnosticsExpanded }
                                        }
                                        Column {
                                            visible: app.diagnosticsExpanded
                                            spacing: 6
                                            Text { text: "iw / radio: " + (app.status.present || app.inspectingProtected ? "available" : "waiting"); color: app.status.present || app.inspectingProtected ? app.success : app.warning; font.pixelSize: 11 }
                                            Text { text: "NetworkManager: " + app.currentNmState; color: app.textPrimary; font.pixelSize: 11 }
                                            Text { text: "monitor capability: " + (app.inspectingProtected ? app.inspectedAdapter.monitor_supported : app.status.monitor_supported); color: app.textPrimary; font.pixelSize: 11 }
                                            Text { text: "polkit helper: " + (app.helperReady ? "ready" : "not installed"); color: app.helperReady ? app.success : app.warning; font.pixelSize: 11 }
                                            Text { visible: doctorOut.text.length > 0; text: doctorOut.text; color: app.textMuted; font.family: "monospace"; font.pixelSize: 9; wrapMode: Text.Wrap; width: 320 }
                                        }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 150
                                    fillColor: app.surfaceHigh
                                    outlineColor: app.outline
                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 6
                                        Text { text: "ACTIVITY"; color: app.textMuted; font.bold: true; font.pixelSize: 11 }
                                        Repeater {
                                            model: app.activity
                                            delegate: Row {
                                                required property string modelData
                                                spacing: 7
                                                StatusDot { dotColor: index === 0 ? app.accent : app.info }
                                                Text { text: modelData; color: index === 0 ? app.textPrimary : app.textMuted; font.pixelSize: 9; elide: Text.ElideRight; width: 315 }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // TRAFFIC TAB
                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 88
                                spacing: 12
                                Repeater {
                                    model: [
                                        { label: "RX", value: app.formatRate(app.rxRate), detail: app.formatPacketRate(app.rxPacketRate), color: app.info },
                                        { label: "TX", value: app.formatRate(app.txRate), detail: app.formatPacketRate(app.txPacketRate), color: "#B98AFF" },
                                        { label: "MODE", value: app.currentMode.toUpperCase(), detail: app.currentInterface, color: app.monitorMode ? app.monitorAccent : app.dmsPrimary },
                                        { label: "PROTOCOL SAMPLE", value: String(app.protocolSamplePackets), detail: "frames / short sample", color: app.protocolPermitted ? app.success : app.warning }
                                    ]
                                    delegate: GlassCard {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        fillColor: app.surfaceHigh
                                        outlineColor: app.outline
                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 10
                                            StatusDot { anchors.verticalCenter: parent.verticalCenter; dotColor: modelData.color }
                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text { text: modelData.label; color: app.textMuted; font.pixelSize: 9; font.bold: true }
                                                Text { text: modelData.value; color: modelData.color; font.pixelSize: 18; font.bold: true }
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
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 8
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "LIVE INTERFACE TRAFFIC"; color: app.textMuted; font.pixelSize: 11; font.bold: true }
                                        Item { Layout.fillWidth: true }
                                        Row { spacing: 14; Text { text: "● RX"; color: app.info; font.pixelSize: 10 } Text { text: "● TX"; color: "#B98AFF"; font.pixelSize: 10 } }
                                    }
                                    TrafficGraph {
                                        id: trafficGraph
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        rxColor: app.info
                                        txColor: "#B98AFF"
                                        gridColor: Qt.rgba(app.outline.r, app.outline.g, app.outline.b, 0.28)
                                    }
                                    Text { text: "Source: kernel interface counters • 1 second samples • no root/capture required"; color: app.textMuted; font.pixelSize: 9 }
                                }
                            }

                            GlassCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                fillColor: app.surfaceHigh
                                outlineColor: app.outline
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 16
                                    ColumnLayout {
                                        Layout.preferredWidth: 230
                                        Text { text: "PROTOCOL MIX"; color: app.textMuted; font.pixelSize: 11; font.bold: true }
                                        Text {
                                            text: !app.protocolAvailable ? "tshark not installed" : (!app.protocolPermitted ? "Capture permission unavailable" : "Passive short sample")
                                            color: app.protocolPermitted ? app.success : app.warning
                                            font.pixelSize: 11
                                        }
                                        Text { text: "No privilege escalation is performed for protocol sampling."; color: app.textMuted; font.pixelSize: 9; wrapMode: Text.Wrap; Layout.fillWidth: true }
                                    }
                                    Rectangle { Layout.fillHeight: true; width: 1; color: app.outline }
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Repeater {
                                            model: app.protocols
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: protocolText.implicitWidth + 20; height: 32; radius: 11
                                                color: Qt.rgba(app.info.r, app.info.g, app.info.b, 0.08)
                                                border.width: 1; border.color: Qt.rgba(app.info.r, app.info.g, app.info.b, 0.28)
                                                Text { id: protocolText; anchors.centerIn: parent; text: modelData.name + "  " + modelData.count; color: app.textPrimary; font.pixelSize: 10 }
                                            }
                                        }
                                        Text { visible: app.protocols.length === 0; text: app.protocolPermitted ? "No protocol frames observed in this sample." : "Protocol details will appear here when tshark/dumpcap permissions allow passive capture."; color: app.textMuted; font.pixelSize: 10; width: 500; wrapMode: Text.Wrap }
                                    }
                                }
                            }
                        }
                    }
                }

                // Footer
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 10
                    StatusDot { dotColor: app.status.present ? app.success : app.warning }
                    Text { text: app.status.present ? "Backend ready" : "Waiting for selected adapter"; color: app.textMuted; font.pixelSize: 10 }
                    Item { Layout.fillWidth: true }
                    StatusDot { dotColor: app.helperReady ? app.success : app.warning }
                    Text { text: app.helperReady ? "Polkit helper ready" : "Read-only mode"; color: app.textMuted; font.pixelSize: 10 }
                    Item { Layout.fillWidth: true }
                    Text { text: "AI-ready contract: JSON discovery/status/telemetry + guarded actions"; color: app.textMuted; font.pixelSize: 9 }
                }
            }
        }

        Dialog {
            id: riskDialog
            modal: true
            anchors.centerIn: parent
            title: "Confirm monitor-mode transition"
            standardButtons: Dialog.Ok | Dialog.Cancel
            onAccepted: app.runAction("monitor", 0)
            background: Rectangle { color: app.surfaceHighest; radius: 18; border.width: 1; border.color: app.warning }
            contentItem: Text {
                width: 420
                text: "This adapter is not classified as the known idle USB lab-candidate. The backend will still revalidate live wireless state and default-route ownership before mutation. Continue?"
                color: app.textPrimary
                wrapMode: Text.Wrap
                padding: 16
            }
        }
    }
}
