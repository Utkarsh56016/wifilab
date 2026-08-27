#!/usr/bin/env bash

# WiFiLab saved-capture viewer/reveal backend.
# This layer launches only validated WiFiLab-owned capture files/directories.
# It never escalates privileges and never accepts arbitrary filesystem paths.

set -o pipefail

wifilab_graphical_session_available() {
    [[ -n ${WAYLAND_DISPLAY-} || -n ${DISPLAY-} ]]
}

wifilab_capture_viewer_command() {
    command -v wireshark 2>/dev/null || true
}

wifilab_capture_reveal_command() {
    if command -v xdg-open >/dev/null 2>&1; then
        printf 'xdg-open\n'
        return 0
    fi
    if command -v gio >/dev/null 2>&1; then
        printf 'gio\n'
        return 0
    fi
    return 1
}

wifilab_capture_launch_detached() {
    local command_path=$1
    shift

    if command -v setsid >/dev/null 2>&1; then
        setsid -f "$command_path" "$@" </dev/null >/dev/null 2>&1
        return $?
    fi

    if command -v nohup >/dev/null 2>&1; then
        nohup "$command_path" "$@" </dev/null >/dev/null 2>&1 &
        return 0
    fi

    return 127
}

wifilab_capture_viewer_status_json() {
    local viewer='' reveal='' graphical=false
    local viewer_available=false reveal_available=false

    viewer=$(wifilab_capture_viewer_command)
    [[ -n $viewer ]] && viewer_available=true

    reveal=$(wifilab_capture_reveal_command 2>/dev/null || true)
    [[ -n $reveal ]] && reveal_available=true

    if wifilab_graphical_session_available; then
        graphical=true
    fi

    printf '{'
    printf '"ok":true,'
    printf '"graphical_session":%s,' "$graphical"
    printf '"viewer":{'
    printf '"available":%s,' "$viewer_available"
    printf '"name":"wireshark",'
    printf '"command":"%s"' "$(wifilab_json_escape "$viewer")"
    printf '},'
    printf '"reveal":{'
    printf '"available":%s,' "$reveal_available"
    printf '"command":"%s"' "$(wifilab_json_escape "$reveal")"
    printf '},'
    printf '"capture_dir":"%s"' "$(wifilab_json_escape "$WIFILAB_CAPTURE_DIR")"
    printf '}\n'
}

wifilab_capture_viewer_resolve() {
    local selector=${1:-latest}
    local target='' rc=0

    target=$(wifilab_capture_analysis_target "$selector") || {
        rc=$?
        case $rc in
            10)
                printf '{"ok":false,"error":"capture_not_found","message":"no WiFiLab capture is available"}\n'
                return 4
                ;;
            11)
                printf '{"ok":false,"error":"invalid_capture_id","message":"capture identifier is invalid"}\n'
                return 2
                ;;
            12)
                printf '{"ok":false,"error":"capture_path_refused","message":"capture path is a symbolic link and was refused"}\n'
                return 4
                ;;
            13)
                printf '{"ok":false,"error":"capture_not_found","message":"requested WiFiLab capture does not exist"}\n'
                return 4
                ;;
            14)
                printf '{"ok":false,"error":"capture_unreadable","message":"requested WiFiLab capture is not readable"}\n'
                return 4
                ;;
            *)
                printf '{"ok":false,"error":"capture_resolution_failed","message":"capture could not be resolved safely"}\n'
                return 4
                ;;
        esac
    }

    printf '%s\n' "$target"
}

wifilab_capture_open() {
    local selector=${1:-latest}
    local target='' capture_id='' path='' viewer='' rc=0

    target=$(wifilab_capture_viewer_resolve "$selector") || {
        rc=$?
        printf '%s\n' "$target"
        return "$rc"
    }
    IFS=$'\t' read -r capture_id path <<<"$target"

    if ! wifilab_graphical_session_available; then
        printf '{"ok":false,"error":"graphical_session_unavailable","message":"no Wayland/X11 graphical session is available"}\n'
        return 4
    fi

    viewer=$(wifilab_capture_viewer_command)
    if [[ -z $viewer ]]; then
        printf '{"ok":false,"error":"viewer_unavailable","message":"Wireshark GUI is not installed or not in PATH"}\n'
        return 4
    fi

    if ! wifilab_capture_launch_detached "$viewer" -r "$path"; then
        printf '{"ok":false,"error":"viewer_launch_failed","message":"Wireshark could not be launched"}\n'
        return 4
    fi

    printf '{"ok":true,"action":"open","capture_id":"%s","file":"%s","viewer":"wireshark"}\n' \
        "$(wifilab_json_escape "$capture_id")" \
        "$(wifilab_json_escape "$path")"
}

wifilab_capture_reveal() {
    local selector=${1:-latest}
    local target='' capture_id='' path='' opener=''
    local opener_path='' rc=0

    target=$(wifilab_capture_viewer_resolve "$selector") || {
        rc=$?
        printf '%s\n' "$target"
        return "$rc"
    }
    IFS=$'\t' read -r capture_id path <<<"$target"

    if ! wifilab_graphical_session_available; then
        printf '{"ok":false,"error":"graphical_session_unavailable","message":"no Wayland/X11 graphical session is available"}\n'
        return 4
    fi

    opener=$(wifilab_capture_reveal_command 2>/dev/null || true)
    case $opener in
        xdg-open)
            opener_path=$(command -v xdg-open)
            wifilab_capture_launch_detached "$opener_path" "$WIFILAB_CAPTURE_DIR" || {
                printf '{"ok":false,"error":"reveal_failed","message":"capture directory could not be opened"}\n'
                return 4
            }
            ;;
        gio)
            opener_path=$(command -v gio)
            wifilab_capture_launch_detached "$opener_path" open "$WIFILAB_CAPTURE_DIR" || {
                printf '{"ok":false,"error":"reveal_failed","message":"capture directory could not be opened"}\n'
                return 4
            }
            ;;
        *)
            printf '{"ok":false,"error":"reveal_unavailable","message":"no desktop file opener is available"}\n'
            return 4
            ;;
    esac

    printf '{"ok":true,"action":"reveal","capture_id":"%s","file":"%s","capture_dir":"%s","opener":"%s"}\n' \
        "$(wifilab_json_escape "$capture_id")" \
        "$(wifilab_json_escape "$path")" \
        "$(wifilab_json_escape "$WIFILAB_CAPTURE_DIR")" \
        "$(wifilab_json_escape "$opener")"
}
