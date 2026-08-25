import QtQuick

Item {
    id: root
    required property var backend
    clip: true

    readonly property real gap: 10
    readonly property real leftW: 302
    readonly property real midW: 320
    readonly property real rightX: leftW + midW + gap * 2
    readonly property real rightW: width - rightX

    readonly property real row1H: 165
    readonly property real row2Y: 175
    readonly property real row2H: 150
    readonly property real row3Y: 335
    readonly property real row3H: height - row3Y

    // ------------------------------------------------------------------
    // Row 1 / ADAPTERS
    // ------------------------------------------------------------------
    GlassCard {
        x: 0; y: 0
        width: root.leftW; height: root.row1H
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text {
            x: 13; y: 11
            text: "ADAPTERS"
            color: backend.textMuted
            font.pixelSize: 10
            font.bold: true
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 13
            y: 11
            text: backend.adapters.length + " detected"
            color: backend.textMuted
            font.pixelSize: 9
        }

        Flickable {
            x: 10; y: 34
            width: parent.width - 20
            height: parent.height - 44
            contentWidth: width
            contentHeight: adapterColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: adapterColumn
                width: parent.width
                spacing: 6

                Repeater {
                    model: backend.adapters
                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: adapterColumn.width
                        height: 50
                        radius: 12
                        readonly property bool protectedAdapter: backend.adapterIsProtected(modelData)
                        readonly property bool currentAdapter: index === backend.inspectedIndex

                        color: currentAdapter
                               ? Qt.rgba((protectedAdapter ? backend.warning : backend.success).r,
                                         (protectedAdapter ? backend.warning : backend.success).g,
                                         (protectedAdapter ? backend.warning : backend.success).b, 0.09)
                               : mouse.containsMouse ? Qt.rgba(1,1,1,0.04) : Qt.rgba(0,0,0,0.14)
                        border.width: 1
                        border.color: currentAdapter
                                      ? Qt.rgba((protectedAdapter ? backend.warning : backend.success).r,
                                                (protectedAdapter ? backend.warning : backend.success).g,
                                                (protectedAdapter ? backend.warning : backend.success).b, 0.38)
                                      : Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.70)

                        Text {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: protectedAdapter ? "wifi_lock" : "usb"
                            color: protectedAdapter ? backend.warning : backend.success
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20
                        }

                        Column {
                            x: 40
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 105
                            spacing: 1
                            Text {
                                width: parent.width
                                text: modelData.device_name || modelData.interface
                                color: backend.textPrimary
                                font.pixelSize: 10
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
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: protectedAdapter ? "SYSTEM" : (modelData.role === "lab-candidate" ? "LAB" : "IDLE")
                            color: protectedAdapter ? backend.warning : backend.success
                            font.pixelSize: 8
                            font.bold: true
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.inspectAdapter(index)
                        }
                    }
                }
            }
        }
    }

    // Row 1 / MODE
    GlassCard {
        x: root.leftW + root.gap; y: 0
        width: root.midW; height: root.row1H
        fillColor: backend.surfaceHigh
        outlineColor: backend.monitorMode && !backend.protectedView ? backend.monitorAccent : backend.outline

        Text {
            x: 14; y: 11
            text: "MODE"
            color: backend.textMuted
            font.pixelSize: 10
            font.bold: true
        }

        Rectangle {
            x: 13; y: 38
            width: parent.width - 26
            height: 78
            radius: 27
            color: Qt.rgba(0,0,0,0.26)
            border.width: 1
            border.color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.88)

            Rectangle {
                x: 5; y: 5
                width: (parent.width - 14) / 2
                height: parent.height - 10
                radius: 22
                color: !backend.monitorMode ? Qt.rgba(backend.dmsPrimary.r, backend.dmsPrimary.g, backend.dmsPrimary.b, 0.14) : "transparent"
                border.width: !backend.monitorMode ? 1 : 0
                border.color: backend.dmsPrimary
                opacity: backend.helperReady && !backend.protectedView ? 1.0 : 0.70

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "wifi"; color: !backend.monitorMode ? backend.dmsPrimary : backend.textMuted; font.family: "Material Symbols Rounded"; font.pixelSize: 24 }
                    Text { text: "MAN"; color: !backend.monitorMode ? backend.textPrimary : backend.textMuted; font.pixelSize: 20; font.bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: backend.helperReady && !backend.actionBusy && !backend.protectedView && backend.status.present
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (backend.monitorMode) backend.runAction("restore", 0)
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 5
                y: 5
                width: (parent.width - 14) / 2
                height: parent.height - 10
                radius: 22
                color: backend.monitorMode ? Qt.rgba(backend.monitorAccent.r, backend.monitorAccent.g, backend.monitorAccent.b, 0.16) : "transparent"
                border.width: backend.monitorMode ? 1 : 0
                border.color: backend.monitorAccent
                opacity: backend.helperReady && !backend.protectedView ? 1.0 : 0.70

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "cell_tower"; color: backend.monitorMode ? backend.monitorAccent : backend.textMuted; font.family: "Material Symbols Rounded"; font.pixelSize: 24 }
                    Text { text: "MON"; color: backend.monitorMode ? backend.monitorAccent : backend.textMuted; font.pixelSize: 20; font.bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: backend.helperReady && !backend.actionBusy && !backend.protectedView && backend.status.present
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (!backend.monitorMode) backend.requestMonitor()
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 132
            spacing: 7
            StatusDot {
                dotColor: backend.protectedView ? backend.warning : (backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary)
                pulse: backend.monitorMode
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: backend.protectedView
                      ? "Protected adapter • mutation disabled"
                      : backend.monitorMode ? "Monitor active • NM unmanaged" : "Managed • NM " + backend.currentNmState
                color: backend.protectedView ? backend.warning : (backend.monitorMode ? backend.monitorAccent : backend.textMuted)
                font.pixelSize: 9
            }
        }
    }

    // Row 1 / RUNTIME
    GlassCard {
        x: root.rightX; y: 0
        width: root.rightW; height: root.row1H
        fillColor: backend.surfaceHigh
        outlineColor: backend.monitorMode ? backend.monitorAccent : backend.outline

        Column {
            x: 15
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 116
            spacing: 6
            Text { text: "RUNTIME INTERFACE"; color: backend.textMuted; font.pixelSize: 10; font.bold: true }
            Text { text: backend.currentInterface + "  •  " + backend.currentPhy; color: backend.textPrimary; font.pixelSize: 22; font.bold: true }
            Text { text: "Link      " + (backend.inspectingProtected ? (backend.inspectedAdapter.operstate || "unknown") : (backend.status.operstate || "unknown")); color: backend.textMuted; font.pixelSize: 9 }
            Text { text: "Driver    " + backend.currentDriver; color: backend.textMuted; font.pixelSize: 9 }
            Text {
                width: parent.width
                text: "MAC       " + (backend.inspectingProtected ? (backend.inspectedAdapter.mac || "—") : (backend.status.mac || "—"))
                color: backend.textMuted
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }

        Rectangle {
            width: 78; height: 78; radius: 39
            anchors.right: parent.right
            anchors.rightMargin: 19
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba((backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary).r,
                           (backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary).g,
                           (backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary).b, 0.055)
            border.width: 1
            border.color: Qt.rgba((backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary).r,
                                  (backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary).g,
                                  (backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary).b, 0.24)
            Text {
                anchors.centerIn: parent
                text: "cell_tower"
                color: backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary
                font.family: "Material Symbols Rounded"
                font.pixelSize: 51
            }
        }
    }

    // ------------------------------------------------------------------
    // Row 2 / CHANNEL
    // ------------------------------------------------------------------
    GlassCard {
        x: 0; y: root.row2Y
        width: root.leftW; height: root.row2H
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text { x: 13; y: 11; text: "CHANNEL  •  " + (backend.radio.band || "unknown"); color: backend.textMuted; font.pixelSize: 10; font.bold: true }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 13; y: 9
            text: backend.radio.channel > 0 ? "CH " + backend.radio.channel : "—"
            color: backend.monitorMode ? backend.monitorAccent : backend.textPrimary
            font.pixelSize: 18; font.bold: true
        }

        CyberButton {
            x: 13; y: 45; width: 39; height: 38
            compact: true; label: ""; icon: "remove"
            accentColor: backend.accent; textColor: backend.textPrimary; mutedColor: backend.textMuted
            enabled: backend.monitorMode && !backend.protectedView && backend.helperReady
            onClicked: backend.stepChannel(-1)
        }

        Item {
            id: channelTrack
            x: 61; y: 45
            width: parent.width - 122
            height: 38
            readonly property var list: backend.bandChannels()
            readonly property int idx: backend.currentChannelIndex()
            readonly property real fraction: list.length > 1 ? idx / (list.length - 1) : 0

            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 4; radius: 2; color: Qt.rgba(backend.outline.r, backend.outline.g, backend.outline.b, 0.75) }
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
            anchors.right: parent.right; anchors.rightMargin: 13; y: 45; width: 39; height: 38
            compact: true; label: ""; icon: "add"
            accentColor: backend.accent; textColor: backend.textPrimary; mutedColor: backend.textMuted
            enabled: backend.monitorMode && !backend.protectedView && backend.helperReady
            onClicked: backend.stepChannel(1)
        }

        Text {
            x: 13; y: 92; width: parent.width - 26
            property var selectedChannel: backend.bandChannels().length > 0 ? backend.bandChannels()[backend.currentChannelIndex()] : ({})
            text: selectedChannel.channel
                  ? selectedChannel.frequency_mhz + " MHz  •  CH " + selectedChannel.channel + (selectedChannel.radar ? "  •  DFS" : "") + (selectedChannel.no_ir ? "  •  NO IR" : "") + (selectedChannel.disabled ? "  •  BLOCKED" : "")
                  : "No fixed channel while managed/disconnected"
            color: selectedChannel.disabled ? backend.error : ((selectedChannel.radar || selectedChannel.no_ir) ? backend.warning : backend.textMuted)
            font.pixelSize: 9
            elide: Text.ElideRight
        }

        Row {
            x: 13; y: 116; spacing: 6
            Repeater {
                model: [1, 6, 11, 36, 149]
                delegate: Rectangle {
                    required property int modelData
                    width: 34; height: 22; radius: 7
                    color: Number(backend.radio.channel) === modelData ? Qt.rgba(backend.accent.r, backend.accent.g, backend.accent.b, 0.15) : Qt.rgba(0,0,0,0.17)
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

    // Row 2 / STATE
    GlassCard {
        x: root.leftW + root.gap; y: root.row2Y
        width: root.midW; height: root.row2H
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text { x: 13; y: 11; text: "STATE"; color: backend.textMuted; font.pixelSize: 10; font.bold: true }

        Repeater {
            model: [
                { x: 13,  y: 41, icon: "settings_ethernet", label: "Mode",    value: backend.currentMode, color: backend.monitorMode ? backend.monitorAccent : backend.dmsPrimary },
                { x: 166, y: 41, icon: "sync_alt",          label: "NM",      value: backend.currentNmState, color: backend.currentNmState === "unmanaged" ? backend.warning : backend.success },
                { x: 13,  y: 91, icon: "visibility",        label: "Monitor", value: String(backend.inspectingProtected ? backend.inspectedAdapter.monitor_supported : backend.status.monitor_supported), color: backend.success },
                { x: 166, y: 91, icon: "public",            label: "REG",     value: backend.status.regdomain || "—", color: backend.status.regdomain ? backend.success : backend.warning }
            ]
            delegate: Item {
                required property var modelData
                x: modelData.x; y: modelData.y
                width: 140; height: 42
                Text { x: 0; y: 5; text: modelData.icon; color: modelData.color; font.family: "Material Symbols Rounded"; font.pixelSize: 20 }
                Column {
                    x: 29; y: 1; spacing: 1
                    Text { text: modelData.label; color: backend.textMuted; font.pixelSize: 8 }
                    Text { text: modelData.value; color: modelData.color; font.pixelSize: 11; font.bold: true }
                }
            }
        }
    }

    // Row 2 / RESTORE + privilege boundary
    GlassCard {
        x: root.rightX; y: root.row2Y
        width: root.rightW; height: root.row2H
        fillColor: backend.surfaceHigh
        outlineColor: backend.monitorMode ? backend.error : backend.outline

        Text {
            x: 14; y: 11
            text: backend.monitorMode ? "RESTORE / ROLLBACK" : "PRIVILEGE BOUNDARY"
            color: backend.monitorMode ? backend.error : backend.success
            font.pixelSize: 10
            font.bold: true
        }

        Text {
            x: 14; y: 39
            width: parent.width - 28
            text: backend.monitorMode
                  ? "The selected adapter is in monitor mode. Restore remains available from every control state."
                  : backend.helperReady
                    ? "Root-owned helper ready. Mutations require polkit authentication and are revalidated live."
                    : "Read-only UI. Privileged helper is intentionally not installed during visual validation."
            color: backend.helperReady ? backend.textMuted : backend.warning
            font.pixelSize: 9
            wrapMode: Text.Wrap
        }

        CyberButton {
            visible: backend.monitorMode
            x: 14; y: 88
            width: parent.width - 28; height: 44
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
            x: 14; y: 102
            spacing: 7
            StatusDot { dotColor: backend.success }
            Text { text: "System Wi-Fi protected by NM + default-route guards"; color: backend.success; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ------------------------------------------------------------------
    // Row 3 / ACTIVITY
    // ------------------------------------------------------------------
    GlassCard {
        x: 0; y: root.row3Y
        width: root.leftW; height: root.row3H
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text { x: 13; y: 11; text: "ACTIVITY"; color: backend.textMuted; font.pixelSize: 10; font.bold: true }
        Column {
            x: 13; y: 36
            width: parent.width - 26
            spacing: 7
            Repeater {
                model: backend.activity
                delegate: Row {
                    required property string modelData
                    required property int index
                    width: parent.width
                    spacing: 7
                    StatusDot { dotColor: index === 0 ? backend.success : backend.outline }
                    Text { width: parent.width - 20; text: modelData; color: index === 0 ? backend.textPrimary : backend.textMuted; font.pixelSize: 9; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    // Row 3 / DIAGNOSTICS
    GlassCard {
        x: root.leftW + root.gap; y: root.row3Y
        width: root.midW; height: root.row3H
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text { x: 13; y: 11; text: "DIAGNOSTICS"; color: backend.textMuted; font.pixelSize: 10; font.bold: true }
        CyberButton {
            anchors.right: parent.right; anchors.rightMargin: 12; y: 8
            width: 86; height: 32
            label: "Doctor"; icon: "health_and_safety"
            accentColor: backend.success; textColor: backend.textPrimary; mutedColor: backend.textMuted
            onClicked: backend.runDoctor()
        }

        Column {
            x: 14; y: 51
            spacing: 9
            Row { spacing: 8; StatusDot { dotColor: backend.success } Text { text: "Discovery backend healthy"; color: backend.textPrimary; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter } }
            Row { spacing: 8; StatusDot { dotColor: backend.status.regdomain ? backend.success : backend.warning } Text { text: "Regdomain  " + (backend.status.regdomain || "unknown"); color: backend.textPrimary; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter } }
            Row { spacing: 8; StatusDot { dotColor: backend.helperReady ? backend.success : backend.warning } Text { text: backend.helperReady ? "Guarded mutation path ready" : "Mutation path intentionally disabled"; color: backend.textPrimary; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter } }
            Row { spacing: 8; StatusDot { dotColor: backend.status.present ? backend.success : backend.warning } Text { text: backend.status.present ? "Selected physical identity present" : "Selected adapter absent"; color: backend.textPrimary; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter } }
        }
    }

    // Row 3 / future expansion and agent boundary
    GlassCard {
        x: root.rightX; y: root.row3Y
        width: root.rightW; height: root.row3H
        fillColor: backend.surfaceHigh
        outlineColor: backend.outline

        Text { x: 14; y: 11; text: "EXTENSION BOUNDARY"; color: backend.textMuted; font.pixelSize: 10; font.bold: true }

        Column {
            x: 14; y: 42
            width: parent.width - 28
            spacing: 9
            Row {
                spacing: 9
                Text { text: "smart_toy"; color: backend.dmsPrimary; font.family: "Material Symbols Rounded"; font.pixelSize: 24 }
                Column {
                    spacing: 2
                    Text { text: "Agent-ready control contract"; color: backend.textPrimary; font.pixelSize: 11; font.bold: true }
                    Text { text: "Same validated JSON + guarded mutation boundary"; color: backend.textMuted; font.pixelSize: 9 }
                }
            }
            Row {
                spacing: 9
                Text { text: "graphic_eq"; color: backend.info; font.family: "Material Symbols Rounded"; font.pixelSize: 24 }
                Column {
                    spacing: 2
                    Text { text: "Future capture workspace"; color: backend.textPrimary; font.pixelSize: 11; font.bold: true }
                    Text { text: "PCAP / capture controls can live here later"; color: backend.textMuted; font.pixelSize: 9 }
                }
            }
            Text {
                width: parent.width
                text: "Quickshell stays presentation-only. Neither future capture tools nor an AI agent may bypass WiFiLab's safety controller."
                color: backend.textMuted
                font.pixelSize: 9
                wrapMode: Text.Wrap
            }
        }
    }
}
