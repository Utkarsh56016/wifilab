import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var backend

    readonly property real leftWidth: 302
    readonly property real midWidth: 320

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Row 1: adapter inventory / mode / runtime interface
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 170
            spacing: 10

            GlassCard {
                Layout.preferredWidth: root.leftWidth
                Layout.fillHeight: true
                fillColor: backend.surfaceHigh
                outlineColor: backend.outline

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 7

                    Row {
                        width: parent.width
                        Text { text: "ADAPTERS"; color: backend.textMuted; font.pixelSize: 9; font.bold: true }
                        Item { width: Math.max(8, parent.width - 130); height: 1 }
                        Text { text: backend.adapters.length + " detected"; color: backend.textMuted; font.pixelSize: 8 }
                    }

                    Repeater {
                        model: backend.adapters

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 57
                            radius: 13
                            readonly property bool protectedAdapter: backend.adapterIsProtected(modelData)
                            readonly property bool currentAdapter: index === backend.inspectedIndex
                            color: currentAdapter
                                   ? Qt.rgba((protectedAdapter ? backend.warning : backend.success).r,
                                             (protectedAdapter ? backend.warning : backend.success).g,
                                             (protectedAdapter ? backend.warning : backend.success).b, 0.085)
                                   : rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(0, 0, 0, 0.12)
                            border.width: 1
                            border.color: currentAdapter
                                          ? Qt.rgba((protectedAdapter ? backend.warning : backend.success).r,
                                                    (protectedAdapter ? backend.warning : backend.success).g,
                                                    (protectedAdapter ? backend.warning : backend.success).b, 0.34)
                                          : Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.66)

                            Row {
                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 9

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.parent.protectedAdapter ? "wifi_lock" : "usb"
                                    color: parent.parent.protectedAdapter ? backend.warning : backend.success
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 20
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 102
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: modelData.device_name || modelData.interface
                                        color: backend.textPrimary
                                        font.pixelSize: 9
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: (modelData.interface || "—") + "  •  " + (modelData.driver || "unknown")
                                        color: backend.textMuted
                                        font.pixelSize: 8
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.parent.protectedAdapter ? "SYSTEM" : (modelData.role === "lab-candidate" ? "LAB" : "IDLE")
                                    color: parent.parent.protectedAdapter ? backend.warning : backend.success
                                    font.pixelSize: 7
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.inspectAdapter(index)
                            }
                        }
                    }
                }
            }

            GlassCard {
                Layout.preferredWidth: root.midWidth
                Layout.fillHeight: true
                fillColor: backend.surfaceHigh
                outlineColor: backend.monitorMode && !backend.protectedView ? backend.monitorAccent : backend.outline

                Column {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 8

                    Text { text: "MODE"; color: backend.textMuted; font.pixelSize: 9; font.bold: true }

                    Rectangle {
                        width: parent.width
                        height: 78
                        radius: 27
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.width: 1
                        border.color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.86)

                        Row {
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: 4

                            Rectangle {
                                width: (parent.width - 4) / 2
                                height: parent.height
                                radius: 22
                                color: !backend.monitorMode ? Qt.rgba(backend.dmsPrimary.r, backend.dmsPrimary.g, backend.dmsPrimary.b, 0.13) : "transparent"
                                border.width: !backend.monitorMode ? 1 : 0
                                border.color: backend.dmsPrimary
                                opacity: backend.helperReady && !backend.protectedView ? 1 : 0.68

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text { text: "wifi"; color: !backend.monitorMode ? backend.dmsPrimary : backend.textMuted; font.family: "Material Symbols Rounded"; font.pixelSize: 24 }
                                    Text { text: "MAN"; color: !backend.monitorMode ? backend.textPrimary : backend.textMuted; font.pixelSize: 19; font.bold: true }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: backend.helperReady && !backend.actionBusy && !backend.protectedView && backend.status.present
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (backend.monitorMode) backend.runAction("restore", 0)
                                }
                            }

                            Rectangle {
                                width: (parent.width - 4) / 2
                                height: parent.height
                                radius: 22
                                color: backend.monitorMode ? Qt.rgba(backend.monitorAccent.r, backend.monitorAccent.g, backend.monitorAccent.b, 0.16) : "transparent"
                                border.width: backend.monitorMode ? 1 : 0
                                border.color: backend.monitorAccent
                                opacity: backend.helperReady && !backend.protectedView ? 1 : 0.68

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text { text: "cell_tower"; color: backend.monitorMode ? backend.monitorAccent : backend.textMuted; font.family: "Material Symbols Rounded"; font.pixelSize: 24 }
                                    Text { text: "MON"; color: backend.monitorMode ? backend.monitorAccent : backend.textMuted; font.pixelSize: 19; font.bold: true }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: backend.helperReady && !backend.actionBusy && !backend.protectedView && backend.status.present
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (!backend.monitorMode) backend.requestMonitor()
                                }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 7
                        StatusDot {
                            dotColor: backend.protectedView ? backend.warning : (backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary)
                            pulse: backend.monitorMode
                        }
                        Text {
                            text: backend.protectedView
                                  ? "Protected adapter • mutation disabled"
                                  : backend.monitorMode ? "Monitor active • NetworkManager unmanaged" : "Managed • NetworkManager " + backend.currentNmState
                            color: backend.protectedView ? backend.warning : (backend.monitorMode ? backend.monitorAccent : backend.textMuted)
                            font.pixelSize: 9
                        }
                    }
                }
            }

            GlassCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                fillColor: backend.surfaceHigh
                outlineColor: backend.monitorMode ? backend.monitorAccent : backend.outline

                Row {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 14

                    Column {
                        width: parent.width - 108
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text { text: "RUNTIME INTERFACE"; color: backend.textMuted; font.pixelSize: 9; font.bold: true }
                        Text { text: backend.currentInterface + "  •  " + backend.currentPhy; color: backend.textPrimary; font.pixelSize: 21; font.bold: true }
                        Text { text: "Link  " + (backend.inspectingProtected ? (backend.inspectedAdapter.operstate || "unknown") : (backend.status.operstate || "unknown")); color: backend.textMuted; font.pixelSize: 9 }
                        Text { text: "MAC   " + (backend.inspectingProtected ? (backend.inspectedAdapter.mac || "—") : (backend.status.mac || "—")); color: backend.textMuted; font.pixelSize: 8; elide: Text.ElideRight; width: parent.width }
                        Text { text: "Driver  " + backend.currentDriver; color: backend.textMuted; font.pixelSize: 9 }
                    }

                    Item {
                        width: 92
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            text: "cell_tower"
                            color: backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 62
                            opacity: 0.88
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 72
                            height: 72
                            radius: 36
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba((backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary).r,
                                                 (backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary).g,
                                                 (backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary).b, 0.20)
                        }
                    }
                }
            }
        }

        // Row 2: channel / state / rollback
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            spacing: 10

            GlassCard {
                Layout.preferredWidth: root.leftWidth
                Layout.fillHeight: true
                fillColor: backend.surfaceHigh
                outlineColor: backend.outline

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Row {
                        width: parent.width
                        Text { text: "CHANNEL  (" + (backend.radio.band || "unknown") + ")"; color: backend.textMuted; font.pixelSize: 9; font.bold: true }
                        Item { width: Math.max(8, parent.width - 170); height: 1 }
                        Text { text: backend.radio.channel > 0 ? "CH " + backend.radio.channel : "—"; color: backend.monitorMode ? backend.monitorAccent : backend.textPrimary; font.pixelSize: 18; font.bold: true }
                    }

                    Row {
                        width: parent.width
                        height: 40
                        spacing: 8

                        CyberButton {
                            width: 40; height: 38; compact: true; label: ""; icon: "remove"
                            accentColor: backend.accent; textColor: backend.textPrimary; mutedColor: backend.textMuted
                            enabled: backend.monitorMode && !backend.protectedView && backend.helperReady
                            onClicked: backend.stepChannel(-1)
                        }

                        Item {
                            id: channelTrack
                            width: parent.width - 96
                            height: 38
                            readonly property var list: backend.bandChannels()
                            readonly property int idx: backend.currentChannelIndex()
                            readonly property real fraction: list.length > 1 ? idx / (list.length - 1) : 0

                            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 4; radius: 2; color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.72) }
                            Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: Math.max(5, (parent.width - 14) * channelTrack.fraction + 7); height: 4; radius: 2; color: backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary }
                            Rectangle { width: 15; height: 15; radius: 7.5; y: (parent.height - height) / 2; x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * channelTrack.fraction)); color: backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary; border.width: 2; border.color: Qt.rgba(1,1,1,0.22) }

                            MouseArea {
                                anchors.fill: parent
                                enabled: backend.monitorMode && !backend.protectedView && backend.helperReady && channelTrack.list.length > 0
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: function(mouse) {
                                    var raw = Math.round((mouse.x / Math.max(1, width)) * Math.max(0, channelTrack.list.length - 1))
                                    backend.commitChannel(Math.max(0, Math.min(channelTrack.list.length - 1, raw)))
                                }
                            }
                        }

                        CyberButton {
                            width: 40; height: 38; compact: true; label: ""; icon: "add"
                            accentColor: backend.accent; textColor: backend.textPrimary; mutedColor: backend.textMuted
                            enabled: backend.monitorMode && !backend.protectedView && backend.helperReady
                            onClicked: backend.stepChannel(1)
                        }
                    }

                    Text {
                        property var selectedChannel: backend.bandChannels().length > 0 ? backend.bandChannels()[backend.currentChannelIndex()] : ({})
                        width: parent.width
                        text: selectedChannel.channel
                              ? selectedChannel.frequency_mhz + " MHz  •  CH " + selectedChannel.channel + (selectedChannel.radar ? "  •  DFS" : "") + (selectedChannel.no_ir ? "  •  NO IR" : "") + (selectedChannel.disabled ? "  •  BLOCKED" : "")
                              : "No fixed channel while managed/disconnected"
                        color: selectedChannel.disabled ? backend.error : ((selectedChannel.radar || selectedChannel.no_ir) ? backend.warning : backend.textMuted)
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 6
                        Repeater {
                            model: [1, 6, 11, 36, 149]
                            delegate: Rectangle {
                                required property int modelData
                                width: 34; height: 23; radius: 7
                                color: Number(backend.radio.channel) === modelData ? Qt.rgba(backend.accent.r, backend.accent.g, backend.accent.b, 0.15) : Qt.rgba(0,0,0,0.16)
                                border.width: 1
                                border.color: Number(backend.radio.channel) === modelData ? backend.accent : backend.outline
                                Text { anchors.centerIn: parent; text: modelData; color: Number(backend.radio.channel) === modelData ? backend.accent : backend.textMuted; font.pixelSize: 8 }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: backend.monitorMode && backend.helperReady && !backend.protectedView
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        var list = backend.bandChannels()
                                        for (var i = 0; i < list.length; ++i) if (Number(list[i].channel) === modelData) { backend.commitChannel(i); break }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            GlassCard {
                Layout.preferredWidth: root.midWidth
                Layout.fillHeight: true
                fillColor: backend.surfaceHigh
                outlineColor: backend.outline

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: "STATE"; color: backend.textMuted; font.pixelSize: 9; font.bold: true }

                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 8

                        Repeater {
                            model: [
                                { icon: "settings_ethernet", label: "Mode", value: backend.currentMode, color: backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary },
                                { icon: "sync_alt", label: "NM", value: backend.currentNmState, color: backend.currentNmState === "unmanaged" ? backend.warning : backend.success },
                                { icon: "visibility", label: "Monitor", value: String(backend.inspectingProtected ? backend.inspectedAdapter.monitor_supported : backend.status.monitor_supported), color: backend.success },
                                { icon: "public", label: "Regdomain", value: backend.status.regdomain || "unknown", color: backend.success },
                                { icon: "fingerprint", label: "Identity", value: backend.inspectingProtected ? "protected" : "matched", color: backend.inspectingProtected ? backend.warning : backend.success },
                                { icon: "update", label: "Refresh", value: "2 s", color: backend.info }
                            ]

                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 7
                                Text { text: modelData.icon; color: backend.textMuted; font.family: "Material Symbols Rounded"; font.pixelSize: 16 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text { text: modelData.label; color: backend.textMuted; font.pixelSize: 7 }
                                    Text { text: modelData.value; color: modelData.color; font.pixelSize: 9; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }
            }

            GlassCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                fillColor: backend.surfaceHigh
                outlineColor: backend.monitorMode ? backend.error : backend.outline

                Column {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 8

                    Text { text: backend.monitorMode ? "RESTORE / ROLLBACK" : "PRIVILEGE BOUNDARY"; color: backend.monitorMode ? backend.error : backend.success; font.pixelSize: 9; font.bold: true }

                    CyberButton {
                        visible: backend.monitorMode
                        width: parent.width
                        height: 48
                        label: "Restore to Managed"
                        icon: "settings_backup_restore"
                        accentColor: backend.error
                        textColor: backend.textPrimary
                        mutedColor: backend.textMuted
                        enabled: backend.helperReady && !backend.actionBusy && !backend.protectedView
                        onClicked: backend.runAction("restore", 0)
                    }

                    Row {
                        visible: !backend.monitorMode
                        spacing: 10
                        Text { text: backend.helperReady ? "verified_user" : "lock"; color: backend.helperReady ? backend.success : backend.warning; font.family: "Material Symbols Rounded"; font.pixelSize: 30 }
                        Column {
                            width: parent.parent.width - 60
                            spacing: 4
                            Text { text: backend.helperReady ? "Guarded mutation path ready" : "Read-only mode"; color: backend.helperReady ? backend.success : backend.warning; font.pixelSize: 11; font.bold: true }
                            Text { width: parent.width; text: backend.helperReady ? "Root-owned helper + polkit. Every mutation is revalidated live." : "Privileged helper intentionally not installed during visual validation."; color: backend.textMuted; font.pixelSize: 8; wrapMode: Text.Wrap }
                        }
                    }

                    Text {
                        width: parent.width
                        text: backend.monitorMode ? "Emergency restore remains available from any tab. Closing the UI does not change radio state." : "System Wi-Fi remains protected by NetworkManager and IPv4/IPv6 default-route guards."
                        color: backend.textMuted
                        font.pixelSize: 8
                        wrapMode: Text.Wrap
                    }
                }
            }
        }

        // Row 3: activity / diagnostics / future expansion
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            GlassCard {
                Layout.preferredWidth: root.leftWidth
                Layout.fillHeight: true
                fillColor: backend.surfaceHigh
                outlineColor: backend.outline

                Column {
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 6

                    Row {
                        width: parent.width
                        Text { text: "ACTIVITY LOG"; color: backend.textMuted; font.pixelSize: 9; font.bold: true }
                        Item { width: Math.max(8, parent.width - 140); height: 1 }
                        Text { text: "LIVE"; color: backend.success; font.pixelSize: 7; font.bold: true }
                    }

                    Repeater {
                        model: backend.activity
                        delegate: Row {
                            required property string modelData
                            required property int index
                            width: parent.width
                            spacing: 7
                            StatusDot { dotColor: index === 0 ? backend.success : backend.outline }
                            Text { width: parent.width - 20; text: modelData; color: index === 0 ? backend.textPrimary : backend.textMuted; font.pixelSize: 8; elide: Text.ElideRight }
                        }
                    }
                }
            }

            GlassCard {
                Layout.preferredWidth: root.midWidth
                Layout.fillHeight: true
                fillColor: backend.surfaceHigh
                outlineColor: backend.outline

                Column {
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 7

                    Row {
                        width: parent.width
                        Text { text: "DIAGNOSTICS"; color: backend.textMuted; font.pixelSize: 9; font.bold: true }
                        Item { width: Math.max(8, parent.width - 150); height: 1 }
                        Text { text: backend.diagnosticsExpanded ? "EXPANDED" : "COLLAPSED"; color: backend.success; font.pixelSize: 7 }
                    }

                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 7

                        Repeater {
                            model: [
                                { label: "iw", ok: true },
                                { label: "regdomain " + (backend.status.regdomain || "?"), ok: !!backend.status.regdomain },
                                { label: "nmcli", ok: true },
                                { label: "monitor capability", ok: String(backend.inspectingProtected ? backend.inspectedAdapter.monitor_supported : backend.status.monitor_supported) === "true" },
                                { label: "driver", ok: backend.currentDriver !== "—" },
                                { label: "selected adapter", ok: backend.status.present === true }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 29
                                radius: 9
                                color: Qt.rgba(0,0,0,0.12)
                                border.width: 1
                                border.color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.55)
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 6
                                    Text { text: modelData.label; color: backend.textMuted; font.pixelSize: 8; width: parent.width - 28; elide: Text.ElideRight }
                                    Text { text: modelData.ok ? "check_circle" : "warning"; color: modelData.ok ? backend.success : backend.warning; font.family: "Material Symbols Rounded"; font.pixelSize: 14 }
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 8
                        CyberButton {
                            compact: true
                            width: 36; height: 30
                            label: ""; icon: "health_and_safety"
                            accentColor: backend.success; textColor: backend.textPrimary; mutedColor: backend.textMuted
                            onClicked: backend.runDoctor()
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Run doctor for dependency-level validation"; color: backend.textMuted; font.pixelSize: 8 }
                    }
                }
            }

            GlassCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                fillColor: backend.surfaceHigh
                outlineColor: backend.outline

                Column {
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 7

                    Text { text: "FUTURE EXPANSION"; color: backend.textMuted; font.pixelSize: 9; font.bold: true }

                    Canvas {
                        width: parent.width
                        height: 36
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = Qt.rgba(backend.success.r, backend.success.g, backend.success.b, 0.42)
                            ctx.lineWidth = 1
                            ctx.beginPath()
                            for (var x = 0; x < width; x += 4) {
                                var y = height / 2 + Math.sin(x / 11) * 5 + Math.sin(x / 4.7) * 2
                                if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                            }
                            ctx.stroke()
                        }
                    }

                    Repeater {
                        model: ["Start Capture", "Save PCAP", "Open in Wireshark", "Channel hopping", "Agent control API"]
                        delegate: Row {
                            required property string modelData
                            width: parent.width
                            spacing: 7
                            StatusDot { dotColor: backend.outline }
                            Text { width: parent.width - 42; text: modelData; color: backend.textMuted; font.pixelSize: 8 }
                            Text { text: "lock"; color: backend.textMuted; font.family: "Material Symbols Rounded"; font.pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }
}
