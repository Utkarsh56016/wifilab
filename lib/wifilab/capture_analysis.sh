#!/usr/bin/env bash

# WiFiLab offline capture analysis.
# This layer never opens a live interface. Protocol analysis is performed only
# against WiFiLab-owned saved PCAPNG files using tshark -r.

set -o pipefail

wifilab_capture_analysis_target() {
    local selector=${1:-latest}
    local capture_id path
    local -a capture_names=()

    if [[ $selector == latest ]]; then
        mapfile -t capture_names < <(wifilab_capture_names)
        (( ${#capture_names[@]} > 0 )) || return 10
        capture_id=${capture_names[0]}
    else
        wifilab_capture_id_valid "$selector" || return 11
        capture_id=$selector
    fi

    path="$WIFILAB_CAPTURE_DIR/$capture_id"

    [[ ! -L $path ]] || return 12
    [[ -f $path ]] || return 13
    [[ -r $path ]] || return 14

    printf '%s\t%s\n' "$capture_id" "$path"
}

wifilab_capture_protocols_json() {
    local selector=${1:-latest}
    local tshark_path='' timeout_path='' target='' capture_id='' path=''
    local sample='' total=0 first=1 count protocol rc=0
    local available=false permitted=false present=false

    if tshark_path=$(command -v tshark 2>/dev/null); then
        available=true
    fi

    target=$(wifilab_capture_analysis_target "$selector") || {
        rc=$?
        case $rc in
            10)
                # Empty inventory is a normal state. Keep legacy fields friendly
                # to the current TRAFFIC UI while exposing present=false.
                [[ $available == true ]] && permitted=true
                printf '{"ok":true,"source":"saved_capture","capture_id":"","file":"","present":false,"available":%s,"permitted":%s,"sample_packets":0,"protocols":[]}\n' \
                    "$available" "$permitted"
                return 0
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

    IFS=$'\t' read -r capture_id path <<<"$target"
    present=true

    if [[ $available != true ]]; then
        printf '{"ok":true,"source":"saved_capture","capture_id":"%s","file":"%s","present":true,"available":false,"permitted":false,"sample_packets":0,"protocols":[]}\n' \
            "$(wifilab_json_escape "$capture_id")" "$(wifilab_json_escape "$path")"
        return 0
    fi

    if ! timeout_path=$(command -v timeout 2>/dev/null); then
        printf '{"ok":false,"error":"analysis_unavailable","message":"timeout command is unavailable for bounded offline analysis"}\n'
        return 4
    fi

    if sample=$("$timeout_path" 15s "$tshark_path" -n -r "$path" -T fields -e _ws.col.Protocol 2>/dev/null); then
        permitted=true
    else
        rc=$?
        if (( rc == 124 )); then
            printf '{"ok":false,"error":"analysis_timeout","exit_code":124,"message":"offline tshark analysis exceeded 15 seconds"}\n'
        else
            printf '{"ok":false,"error":"analysis_failed","exit_code":%s,"message":"tshark could not analyze the saved capture"}\n' "$rc"
        fi
        return "$rc"
    fi

    total=$(printf '%s\n' "$sample" | awk 'NF {n++} END {print n+0}')

    printf '{'
    printf '"ok":true,'
    printf '"source":"saved_capture",'
    printf '"capture_id":"%s",' "$(wifilab_json_escape "$capture_id")"
    printf '"file":"%s",' "$(wifilab_json_escape "$path")"
    printf '"present":%s,' "$present"
    printf '"available":%s,' "$available"
    printf '"permitted":%s,' "$permitted"
    printf '"sample_packets":%s,' "$total"
    printf '"protocols":['

    while read -r count protocol; do
        [[ -n $protocol ]] || continue
        (( first )) || printf ','
        first=0
        printf '{"name":"%s","count":%s}' \
            "$(wifilab_json_escape "$protocol")" "$count"
    done < <(printf '%s\n' "$sample" | awk 'NF' | sort | uniq -c | sort -nr | head -8)

    printf ']}\n'
}

# Backward-compatible TRAFFIC/UI command. The old live sampler is intentionally
# gone: this always analyzes the newest saved WiFiLab capture offline.
wifilab_protocols_json() {
    wifilab_capture_protocols_json latest
}
