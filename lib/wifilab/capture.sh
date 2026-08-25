#!/usr/bin/env bash

# WiFiLab bounded passive capture backend.
# Capture always resolves the persisted physical adapter at operation time.
# No capture command escalates privilege; dumpcap must already be executable
# by the calling user through the host's normal Wireshark permission model.

set -o pipefail

WIFILAB_DATA_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/wifilab
WIFILAB_CAPTURE_DIR=$WIFILAB_DATA_DIR/captures

wifilab_capture_stack_state() {
    local dumpcap_path=''
    WIFILAB_CAPTURE_AVAILABLE=false
    WIFILAB_CAPTURE_PERMITTED=false

    if dumpcap_path=$(command -v dumpcap 2>/dev/null); then
        WIFILAB_CAPTURE_AVAILABLE=true
        [[ -x $dumpcap_path ]] && WIFILAB_CAPTURE_PERMITTED=true
    fi
}

wifilab_capture_status_json() {
    local iface='' present=false protected=false mode='' ready=false

    wifilab_capture_stack_state

    if iface=$(wifilab_resolve_selected 2>/dev/null); then
        present=true
        mode=$(wifilab_iface_type "$iface")
        if wifilab_iface_is_protected "$iface"; then
            protected=true
        fi
    fi

    if [[ $present == true && $protected == false && $mode == monitor && \
          $WIFILAB_CAPTURE_AVAILABLE == true && $WIFILAB_CAPTURE_PERMITTED == true ]]; then
        ready=true
    fi

    printf '{'
    printf '"present":%s,' "$present"
    printf '"available":%s,' "$WIFILAB_CAPTURE_AVAILABLE"
    printf '"permitted":%s,' "$WIFILAB_CAPTURE_PERMITTED"
    printf '"protected":%s,' "$protected"
    printf '"ready":%s,' "$ready"
    printf '"interface":"%s",' "$(wifilab_json_escape "$iface")"
    printf '"mode":"%s",' "$(wifilab_json_escape "$mode")"
    printf '"capture_dir":"%s"' "$(wifilab_json_escape "$WIFILAB_CAPTURE_DIR")"
    printf '}\n'
}

wifilab_capture_run_json() {
    local duration=${1:-10}
    local max_kib=${2:-10240}
    local iface mode dumpcap_path stamp outfile errfile bytes=0 rc=0 err_msg=''

    [[ $duration =~ ^[0-9]+$ ]] && (( duration >= 1 && duration <= 300 )) || {
        printf '{"ok":false,"error":"invalid_duration","message":"duration must be an integer from 1 to 300 seconds"}\n'
        return 2
    }
    [[ $max_kib =~ ^[0-9]+$ ]] && (( max_kib >= 256 && max_kib <= 102400 )) || {
        printf '{"ok":false,"error":"invalid_size_limit","message":"max_kib must be an integer from 256 to 102400"}\n'
        return 2
    }

    if ! dumpcap_path=$(command -v dumpcap 2>/dev/null); then
        printf '{"ok":false,"error":"capture_unavailable","message":"dumpcap is not installed"}\n'
        return 4
    fi
    if [[ ! -x $dumpcap_path ]]; then
        printf '{"ok":false,"error":"capture_not_permitted","message":"dumpcap is not executable by the current user"}\n'
        return 4
    fi

    if ! iface=$(wifilab_resolve_selected 2>/dev/null); then
        printf '{"ok":false,"error":"adapter_unavailable","message":"selected physical adapter is not currently present"}\n'
        return 4
    fi
    wifilab_require_wireless_iface "$iface" >/dev/null 2>&1 || {
        printf '{"ok":false,"error":"adapter_invalid","message":"selected adapter is not a live wireless interface"}\n'
        return 4
    }
    if wifilab_iface_is_protected "$iface"; then
        printf '{"ok":false,"error":"protected_interface","message":"capture refused on an active/default-route wireless interface"}\n'
        return 3
    fi

    mode=$(wifilab_iface_type "$iface")
    if [[ $mode != monitor ]]; then
        printf '{"ok":false,"error":"monitor_required","message":"capture is allowed only while the selected adapter is in monitor mode"}\n'
        return 4
    fi

    umask 077
    mkdir -p "$WIFILAB_CAPTURE_DIR" || {
        printf '{"ok":false,"error":"capture_dir_failed","message":"could not create the WiFiLab capture directory"}\n'
        return 1
    }
    chmod 700 "$WIFILAB_CAPTURE_DIR" 2>/dev/null || true

    stamp=$(date -u +%Y%m%dT%H%M%SZ)
    outfile="$WIFILAB_CAPTURE_DIR/capture-${stamp}-$$.pcapng"
    if ! errfile=$(mktemp "${TMPDIR:-/tmp}/wifilab-dumpcap.XXXXXX"); then
        printf '{"ok":false,"error":"temporary_file_failed","message":"could not create dumpcap error buffer"}\n'
        return 1
    fi

    if "$dumpcap_path" -q -i "$iface" \
        -a "duration:$duration" \
        -a "filesize:$max_kib" \
        -w "$outfile" 2>"$errfile"; then
        rc=0
    else
        rc=$?
    fi

    if (( rc != 0 )); then
        err_msg=$(tail -n 1 "$errfile" 2>/dev/null || true)
        rm -f "$errfile" "$outfile"
        printf '{"ok":false,"error":"capture_failed","exit_code":%s,"message":"%s"}\n' \
            "$rc" "$(wifilab_json_escape "$err_msg")"
        return "$rc"
    fi

    rm -f "$errfile"
    bytes=$(stat -c '%s' "$outfile" 2>/dev/null || printf '0')
    printf '{'
    printf '"ok":true,'
    printf '"interface":"%s",' "$(wifilab_json_escape "$iface")"
    printf '"duration_seconds":%s,' "$duration"
    printf '"max_kib":%s,' "$max_kib"
    printf '"bytes":%s,' "${bytes:-0}"
    printf '"file":"%s"' "$(wifilab_json_escape "$outfile")"
    printf '}\n'
}

wifilab_captures_json() {
    local path name bytes first=1

    printf '{"capture_dir":"%s","captures":[' "$(wifilab_json_escape "$WIFILAB_CAPTURE_DIR")"

    if [[ -d $WIFILAB_CAPTURE_DIR ]]; then
        while IFS= read -r name; do
            [[ -n $name ]] || continue
            path="$WIFILAB_CAPTURE_DIR/$name"
            bytes=$(stat -c '%s' "$path" 2>/dev/null || printf '0')
            (( first )) || printf ','
            first=0
            printf '{"name":"%s","bytes":%s,"file":"%s"}' \
                "$(wifilab_json_escape "$name")" "${bytes:-0}" "$(wifilab_json_escape "$path")"
        done < <(find "$WIFILAB_CAPTURE_DIR" -maxdepth 1 -type f -name 'capture-*.pcapng' -printf '%f\n' 2>/dev/null | sort -r)
    fi

    printf ']}\n'
}
