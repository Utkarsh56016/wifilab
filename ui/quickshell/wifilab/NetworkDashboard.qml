import QtQuick
import Quickshell.Io

Item {
    id: root
    required property var backend
    clip: true

    property var roles: ({ interfaces: [], role_index: { PRIMARY: [], LAB: [], AUXILIARY: [], VIRTUAL: [], TUNNEL: [] }, selected_lab: {} })
    property var context: ({ default_route_owners: { ipv4: [], ipv6: [] }, interfaces: [] })
    property var labPath: ({ lab: {}, primary: {}, separation: {} })
    property var wifiScan: ({ scan: { ready: false, blocked_reasons: [], access_point_count: 0 }, access_points: [], interface: {} })
    property var wirelessIfaces: []
    property string selectedWifiIface: ""
    property int selectedApIndex: -1
    property bool scanBusy: false
    property string scanMessage: ""

    readonly property var accessPoints: wifiScan.access_points || []
    readonly property var selectedAp: selectedApIndex >= 0 && selectedApIndex < accessPoints.length ? accessPoints[selectedApIndex] : ({})
    readonly property var selectedRole: roleFor(selectedWifiIface)
    readonly property bool selectedScanReady: wifiScan.scan && wifiScan.scan.ready === true
    readonly property string ipv4DefaultOwner: ((context.default_route_owners || {}).ipv4 || []).join(", ") || "none"
    readonly property string labIface: ((roles.selected_lab || {}).interface || "")
    readonly property string labState: ((labPath.lab || {}).state || "unknown")
    readonly property string separationState: ((labPath.separation || {}).state || "unknown")

    readonly property real gap: 10
    readonly property real metricsH: 78
    readonly property real lowerY: metricsH + gap
    readonly property real lowerH: height - lowerY
    readonly property real adaptersW: 260
    readonly property real radarW: 470
    readonly property real detailW: width - adaptersW - radarW - gap * 2

    function parseJson(text, fallback) {
        try { return JSON.parse(text) } catch (e) { return fallback }
    }

    function roleFor(name) {
        var list = roles.interfaces || []
        for (var i = 0; i < list.length; ++i) {
            if (list[i].name === name) return list[i]
        }
        return ({})
    }

    function roleColor(role) {
        if (role === "PRIMARY") return backend.success
        if (role === "LAB") return backend.monitorAccent
        if (role === "TUNNEL") return backend.violet
        if (role === "VIRTUAL") return backend.info
        return backend.textMuted
    }

    function bandColor(band) {
        if (band === "2.4GHz") return backend.info
        if (band === "5GHz") return backend.violet
        if (band === "6GHz") return backend.warning
        return backend.textMuted
    }

    function blockedSummary() {
        var reasons = ((wifiScan.scan || {}).blocked_reasons || [])
        if (reasons.length === 0) return ""
        if (reasons.indexOf("wireless_mode_not_managed") >= 0 || reasons.indexOf("networkmanager_not_managing_interface") >= 0)
            return "Restore this adapter through CONTROL before NETWORK scanning."
        return reasons.join(" • ")
    }

    function applyRoles(payload) {
        roles = payload
        var old = selectedWifiIface
        var wireless = []
        var list = payload.interfaces || []
        for (var i = 0; i < list.length; ++i) {
            if (list[i].wireless === true) wireless.push(list[i])
        }
        wirelessIfaces = wireless

        var stillPresent = false
        for (var j = 0; j < wireless.length; ++j) {
            if (wireless[j].name === old) stillPresent = true
        }
        if (!stillPresent) {
            var primary = ((payload.role_index || {}).PRIMARY || [])
            if (primary.length > 0) selectedWifiIface = primary[0]
            else if (wireless.length > 0) selectedWifiIface = wireless[0].name
            else selectedWifiIface = ""
        }

        if (selectedWifiIface !== old && selectedWifiIface.length > 0)
            refreshScan()
    }

    function applyScan(payload) {
        wifiScan = payload
        scanBusy = false
        var aps = payload.access_points || []
        if (aps.length === 0) selectedApIndex = -1
        else if (selectedApIndex < 0 || selectedApIndex >= aps.length) selectedApIndex = 0
        scanMessage = payload.ok === false ? (payload.message || "scan failed")
                    : ((payload.scan || {}).ready === true ? aps.length + " APs visible" : blockedSummary())
        radarCanvas.requestPaint()
    }

    function selectWifi(name) {
        if (!name || selectedWifiIface === name) return
        selectedWifiIface = name
        selectedApIndex = -1
        wifiScan = ({ scan: { ready: false, blocked_reasons: [], access_point_count: 0 }, access_points: [], interface: {} })
        refreshScan()
    }

    function refreshBase() {
        if (!rolesProcess.running) rolesProcess.exec(["wifilab", "network", "roles", "--json"])
        if (!contextProcess.running) contextProcess.exec(["wifilab", "network", "context", "--json"])
        if (!labPathProcess.running) labPathProcess.exec(["wifilab", "network", "lab-path", "--json"])
    }

    function refreshScan() {
        if (!visible || selectedWifiIface.length === 0 || scanProcess.running) return
        scanBusy = true
        scanMessage = "Refreshing NetworkManager scan…"
        scanProcess.exec(["wifilab", "network", "wifi-scan", selectedWifiIface, "--json"])
    }

    function signalRadius(ap, maxRadius) {
        var signal = Math.max(0, Math.min(100, Number(ap.signal_percent) || 0))
        return maxRadius * (0.22 + (100 - signal) / 100.0 * 0.72)
    }

    function angleDegrees(ap) {
        var band = ap.band || "unknown"
        var ch = Number(ap.channel) || 0
        if (band === "2.4GHz") return 5 + Math.max(0, Math.min(14, ch)) / 14.0 * 105
        if (band === "5GHz") return 125 + Math.max(0, Math.min(129, ch - 36)) / 129.0 * 105
        if (band === "6GHz") return 245 + Math.max(0, Math.min(232, ch - 1)) / 232.0 * 105
        return 355
    }

    function radarX(ap, w, h) {
        var maxR = Math.min(w, h) * 0.42
        var r = signalRadius(ap, maxR)
        var a = angleDegrees(ap) * Math.PI / 180.0
        return w / 2 + Math.cos(a) * r
    }

    function radarY(ap, w, h) {
        var maxR = Math.min(w, h) * 0.42
        var r = signalRadius(ap, maxR)
        var a = angleDegrees(ap) * Math.PI / 180.0
        return h / 2 + Math.sin(a) * r
    }

    Process {
        id: rolesProcess
        stdout: StdioCollector {
            onStreamFinished: root.applyRoles(root.parseJson(text, { interfaces: [], role_index: {} }))
        }
    }

    Process {
        id: contextProcess
        stdout: StdioCollector {
            onStreamFinished: root.context = root.parseJson(text, { default_route_owners: { ipv4: [], ipv6: [] }, interfaces: [] })
        }
    }

    Process {
        id: labPathProcess
        stdout: StdioCollector {
            onStreamFinished: root.labPath = root.parseJson(text, { lab: {}, primary: {}, separation: {} })
        }
    }

    Process {
        id: scanProcess
        stdout: StdioCollector { id: scanOut }
        stderr: StdioCollector { id: scanErr }
        onExited: function(code, status) {
            var parsed = root.parseJson(scanOut.text, {})
            if (Object.keys(parsed).length === 0 && code !== 0) {
                root.scanBusy = false
                root.scanMessage = scanErr.text.trim() || "scan failed"
                return
            }
            root.applyScan(parsed)
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.refreshBase()
    }

    Timer {
        interval: 12000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.refreshScan()
    }

    Repeater {
        model: [
            { label: "PRIMARY", value: (((root.roles.role_index || {}).PRIMARY || []).join(", ") || "none"), detail: "default path role", color: backend.success },
            { label: "LAB", value: root.labIface || "none", detail: root.labState.replace(/_/g, " "), color: backend.monitorAccent },
            { label: "DEFAULT IPv4", value: root.ipv4DefaultOwner, detail: root.separationState.replace(/_/g, " "), color: backend.dmsPrimary },
            { label: "NETWORK SCAN", value: root.scanBusy ? "SCANNING" : (root.selectedScanReady ? String(root.accessPoints.length) + " APs" : "BLOCKED"), detail: root.selectedWifiIface || "no wireless iface", color: root.selectedScanReady ? backend.info : backend.warning }
        ]

        delegate: GlassCard {
            required property var modelData
            required property int index
            x: index * ((root.width - root.gap * 3) / 4 + root.gap)
            y: 0
            width: (root.width - root.gap * 3) / 4
            height: root.metricsH
            fillColor: backend.surfaceHigh
            outlineColor: backend.outline

            Row {
                anchors.centerIn: parent
                spacing: 9
                StatusDot { dotColor: modelData.color }
                Column {
                    spacing: 2
                    Text { text: modelData.label; color: backend.textMuted; font.pixelSize: 9; font.bold: true }
                    Text { text: modelData.value; color: modelData.color; font.pixelSize: 15; font.bold: true; width: 175; elide: Text.ElideRight }
                    Text { text: modelData.detail; color: backend.textMuted; font.pixelSize: 8; width: 175; elide: Text.ElideRight }
                }
            }
        }
    }

    GlassCard {
        x: 0
        y: root.lowerY
        width: root.adaptersW
        height: root.lowerH
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text { x: 14; y: 12; text: "ADAPTERS / ROLES"; color: backend.textMuted; font.pixelSize: 10; font.bold: true }

        Flickable {
            x: 10
            y: 34
            width: parent.width - 20
            height: parent.height - 44
            contentHeight: adapterColumn.height
            clip: true

            Column {
                id: adapterColumn
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.roles.interfaces || []
                    delegate: Rectangle {
                        required property var modelData
                        width: adapterColumn.width
                        height: 45
                        radius: 10
                        color: modelData.name === root.selectedWifiIface ? Qt.rgba(backend.dmsPrimary.r, backend.dmsPrimary.g, backend.dmsPrimary.b, 0.10) : Qt.rgba(0,0,0,0.14)
                        border.width: 1
                        border.color: modelData.name === root.selectedWifiIface ? backend.dmsPrimary : Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.72)

                        Rectangle {
                            x: 8; anchors.verticalCenter: parent.verticalCenter
                            width: 7; height: 27; radius: 4
                            color: root.roleColor(modelData.role)
                        }
                        Column {
                            x: 24; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 88
                            spacing: 1
                            Text { text: modelData.name + "  " + modelData.role; color: backend.textPrimary; font.pixelSize: 9; font.bold: true; width: parent.width; elide: Text.ElideRight }
                            Text { text: (modelData.wireless ? ((modelData.mode || "?") + " / " + (modelData.nm_state || "?")) : (modelData.kind || modelData.nm_type || "netdev")); color: backend.textMuted; font.pixelSize: 8; width: parent.width; elide: Text.ElideRight }
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.wireless ? "wifi" : (modelData.virtual ? "hub" : "lan")
                            color: modelData.wireless ? backend.info : backend.textMuted
                            font.family: "Material Symbols Rounded"; font.pixelSize: 17
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: modelData.wireless === true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.selectWifi(modelData.name)
                        }
                    }
                }
            }
        }
    }

    GlassCard {
        x: root.adaptersW + root.gap
        y: root.lowerY
        width: root.radarW
        height: root.lowerH
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text { x: 14; y: 12; text: "WIFI RADAR"; color: backend.textMuted; font.pixelSize: 10; font.bold: true }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 14; y: 12
            text: "signal proxy • stronger = nearer center"
            color: backend.textMuted; font.pixelSize: 8
        }

        Item {
            id: radarPlot
            x: 14
            y: 36
            width: parent.width - 28
            height: parent.height - 68

            Canvas {
                id: radarCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var cx = width / 2
                    var cy = height / 2
                    var maxR = Math.min(width, height) * 0.42
                    ctx.lineWidth = 1
                    ctx.strokeStyle = Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.55)
                    for (var i = 1; i <= 4; ++i) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, maxR * i / 4, 0, Math.PI * 2)
                        ctx.stroke()
                    }
                    ctx.strokeStyle = Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.34)
                    for (var d = 0; d < 360; d += 30) {
                        var a = d * Math.PI / 180
                        ctx.beginPath()
                        ctx.moveTo(cx, cy)
                        ctx.lineTo(cx + Math.cos(a) * maxR, cy + Math.sin(a) * maxR)
                        ctx.stroke()
                    }
                }
            }

            Rectangle {
                width: 10; height: 10; radius: 5
                anchors.centerIn: parent
                color: backend.success
            }

            Repeater {
                model: root.accessPoints
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: 28; height: 28
                    x: root.radarX(modelData, radarPlot.width, radarPlot.height) - width / 2
                    y: root.radarY(modelData, radarPlot.width, radarPlot.height) - height / 2

                    Rectangle {
                        anchors.centerIn: parent
                        width: index === root.selectedApIndex ? 14 : 10
                        height: width
                        radius: width / 2
                        color: root.bandColor(modelData.band)
                        border.width: index === root.selectedApIndex ? 2 : 0
                        border.color: backend.textPrimary
                    }
                    Text {
                        visible: index === root.selectedApIndex || Number(modelData.signal_percent) >= 70
                        y: 18; anchors.horizontalCenter: parent.horizontalCenter
                        width: 92
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.hidden ? "<hidden>" : (modelData.ssid || "<hidden>")
                        color: backend.textPrimary; font.pixelSize: 7; elide: Text.ElideRight
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedApIndex = index }
                }
            }

            Column {
                visible: !root.selectedScanReady
                anchors.centerIn: parent
                width: parent.width - 56
                spacing: 7
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "wifi_off"; color: backend.warning; font.family: "Material Symbols Rounded"; font.pixelSize: 34 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Connectable scan unavailable"; color: backend.textPrimary; font.pixelSize: 12; font.bold: true }
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: root.blockedSummary() || root.scanMessage || "Select a NetworkManager-managed wireless adapter."; color: backend.textMuted; font.pixelSize: 9 }
            }
        }

        Row {
            x: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            spacing: 14
            Text { text: "● 2.4 GHz"; color: backend.info; font.pixelSize: 8 }
            Text { text: "● 5 GHz"; color: backend.violet; font.pixelSize: 8 }
            Text { text: "● 6 GHz"; color: backend.warning; font.pixelSize: 8 }
            Text { text: root.scanMessage; color: backend.textMuted; font.pixelSize: 8; width: 170; elide: Text.ElideRight }
        }
    }

    GlassCard {
        x: root.adaptersW + root.gap + root.radarW + root.gap
        y: root.lowerY
        width: root.detailW
        height: root.lowerH
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text { x: 14; y: 12; text: "NETWORK DETAIL"; color: backend.textMuted; font.pixelSize: 10; font.bold: true }

        Column {
            x: 14; y: 36
            width: parent.width - 28
            spacing: 9

            Rectangle {
                width: parent.width; height: 60; radius: 10
                color: Qt.rgba(0,0,0,0.16); border.width: 1; border.color: backend.outline
                Column {
                    x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20; spacing: 2
                    Text { text: root.selectedWifiIface || "No wireless adapter"; color: backend.textPrimary; font.pixelSize: 12; font.bold: true }
                    Text { text: (root.selectedRole.role || "UNKNOWN") + " • " + (root.selectedRole.mode || "unknown") + " • NM " + (root.selectedRole.nm_state || "unknown"); color: root.roleColor(root.selectedRole.role); font.pixelSize: 8; width: parent.width; elide: Text.ElideRight }
                    Text { text: (root.selectedRole.driver || "driver ?") + " / " + (root.selectedRole.phy || "phy ?"); color: backend.textMuted; font.pixelSize: 8 }
                }
            }

            CyberButton {
                width: parent.width; height: 34
                label: root.scanBusy ? "SCANNING" : "REFRESH WIFI"
                icon: "radar"
                compact: true
                enabled: !root.scanBusy && root.selectedWifiIface.length > 0
                accentColor: backend.info
                textColor: backend.textPrimary
                mutedColor: backend.textMuted
                onClicked: root.refreshScan()
            }

            Rectangle {
                width: parent.width; height: 112; radius: 10
                color: Qt.rgba(0,0,0,0.16); border.width: 1; border.color: backend.outline
                Column {
                    x: 10; y: 9; width: parent.width - 20; spacing: 3
                    Text { text: root.selectedApIndex >= 0 ? (root.selectedAp.ssid || "<hidden>") : "No AP selected"; color: backend.textPrimary; font.pixelSize: 11; font.bold: true; width: parent.width; elide: Text.ElideRight }
                    Text { text: root.selectedApIndex >= 0 ? ((root.selectedAp.signal_percent || 0) + "% • ch " + (root.selectedAp.channel || "?") + " • " + (root.selectedAp.band || "?")) : "Select a radar point"; color: root.selectedApIndex >= 0 ? root.bandColor(root.selectedAp.band) : backend.textMuted; font.pixelSize: 8 }
                    Text { text: root.selectedApIndex >= 0 ? (root.selectedAp.security || "open") : ""; color: backend.textMuted; font.pixelSize: 8; width: parent.width; elide: Text.ElideRight }
                    Text { text: root.selectedApIndex >= 0 ? (root.selectedAp.saved_profile ? "Saved profile" : "Unsaved network") + (root.selectedAp.connected ? " • connected" : "") : ""; color: root.selectedAp.saved_profile ? backend.success : backend.warning; font.pixelSize: 8 }
                    Text { text: root.selectedApIndex >= 0 ? (root.selectedAp.bssid || "") : ""; color: backend.textMuted; font.pixelSize: 7; width: parent.width; elide: Text.ElideRight }
                }
            }

            Rectangle {
                width: parent.width; height: 92; radius: 10
                color: Qt.rgba(0,0,0,0.16); border.width: 1; border.color: backend.outline
                Column {
                    x: 10; y: 9; width: parent.width - 20; spacing: 3
                    Text { text: "LAB PATH"; color: backend.textMuted; font.pixelSize: 8; font.bold: true }
                    Text { text: root.labIface || "LAB not configured"; color: backend.monitorAccent; font.pixelSize: 10; font.bold: true }
                    Text { text: root.labState.replace(/_/g, " "); color: backend.textPrimary; font.pixelSize: 8; width: parent.width; elide: Text.ElideRight }
                    Text { text: "default: " + root.ipv4DefaultOwner; color: backend.success; font.pixelSize: 8; width: parent.width; elide: Text.ElideRight }
                    Text { text: root.separationState.replace(/_/g, " "); color: backend.textMuted; font.pixelSize: 8; width: parent.width; elide: Text.ElideRight }
                }
            }

            Text {
                width: parent.width
                text: "Connection mutations stay disabled in this surface until the remaining 8H positive-auth hardware gate is validated. NETWORK does not bypass CONTROL radio state."
                color: backend.textMuted
                font.pixelSize: 8
                wrapMode: Text.Wrap
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            refreshBase()
            if (selectedWifiIface.length > 0) refreshScan()
        }
    }
}