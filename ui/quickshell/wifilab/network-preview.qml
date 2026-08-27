//@ pragma AppId io.github.utkarsh56016.wifilab.networkpreview
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: preview

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
        console.log("WiFiLab NETWORK preview: " + message)
    }

    Process {
        id: themeProcess
        stdout: StdioCollector { onStreamFinished: preview.applyDmsTheme(preview.parseJson(text, {})) }
        Component.onCompleted: exec(["cat", Quickshell.env("HOME") + "/.cache/DankMaterialShell/dms-colors.json"])
    }

    FloatingWindow {
        id: win
        visible: true
        title: "WiFiLab NETWORK Preview"
        implicitWidth: 1040
        implicitHeight: 620
        minimumSize: Qt.size(1040, 620)
        maximumSize: Qt.size(1040, 620)
        color: "transparent"
        surfaceFormat.opaque: false
        onClosed: Qt.quit()

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: Qt.rgba(preview.surface.r, preview.surface.g, preview.surface.b, 0.972)
            border.width: 1
            border.color: preview.outline

            Item {
                x: 14
                y: 14
                width: parent.width - 28
                height: parent.height - 28

                Row {
                    x: 0
                    y: 0
                    spacing: 8
                    Text { text: "radar"; color: preview.info; font.family: "Material Symbols Rounded"; font.pixelSize: 23 }
                    Text { text: "WiFiLab NETWORK"; color: preview.textPrimary; font.pixelSize: 18; font.bold: true }
                    Text { text: "8I isolated preview"; color: preview.textMuted; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                }

                Text {
                    anchors.right: parent.right
                    y: 5
                    text: "READ-ONLY • NetworkManager scan • no radio mutation"
                    color: preview.success
                    font.pixelSize: 8
                    font.bold: true
                }

                NetworkDashboard {
                    x: 0
                    y: 42
                    width: parent.width
                    height: parent.height - 42
                    backend: preview
                }
            }
        }
    }
}