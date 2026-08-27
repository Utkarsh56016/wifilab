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

wifilab_capture_manifest_path() {
    local capture_file=$1
    printf '%s.json\n' "${capture_file%.pcapng}"
}

wifilab_capture_write_manifest() {
    local capture_file=$1
    local capture_id=$2
    local created_at_utc=$3
    local iface=$4
    local phy=$5
    local driver=$6
    local channel=$7
    local frequency_mhz=$8
    local regdomain=$9
    local duration_limit=${10}
    local size_limit_kib=${11}
    local bytes=${12}
    local sha256=${13}
    local manifest tmp

    manifest=$(wifilab_capture_manifest_path "$capture_file")

    if ! tmp=$(mktemp "$WIFILAB_CAPTURE_DIR/.manifest.XXXXXX"); then
        return 1
    fi

    if ! {
        printf '{'
        printf '"schema_version":1,'
        printf '"capture_id":"%s",' "$(wifilab_json_escape "$capture_id")"
        printf '"created_at_utc":"%s",' "$(wifilab_json_escape "$created_at_utc")"
        printf '"file":"%s",' "$(wifilab_json_escape "$capture_file")"
        printf '"interface":"%s",' "$(wifilab_json_escape "$iface")"
        printf '"phy":"%s",' "$(wifilab_json_escape "$phy")"
        printf '"driver":"%s",' "$(wifilab_json_escape "$driver")"
        printf '"channel":%s,' "${channel:-0}"
        printf '"frequency_mhz":%s,' "${frequency_mhz:-0}"
        printf '"regdomain":"%s",' "$(wifilab_json_escape "$regdomain")"
        printf '"duration_limit_seconds":%s,' "$duration_limit"
        printf '"size_limit_kib":%s,' "$size_limit_kib"
        printf '"bytes":%s,' "${bytes:-0}"
        printf '"sha256":"%s"' "$(wifilab_json_escape "$sha256")"
        printf '}\n'
    } >"$tmp"; then
        rm -f -- "$tmp"
        return 1
    fi

    chmod 600 "$tmp" 2>/dev/null || true

    if ! mv -f -- "$tmp" "$manifest"; then
        rm -f -- "$tmp"
        return 1
    fi

    printf '%s\n' "$manifest"
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
    local capture_id created_at_utc phy driver channel frequency_mhz regdomain
    local sha256='' manifest='' metadata_state='missing' metadata_warning=''

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
    created_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    outfile="$WIFILAB_CAPTURE_DIR/capture-${stamp}-$$.pcapng"
    capture_id=${outfile##*/}

    phy=$(wifilab_phy_for_iface "$iface")
    driver=$(wifilab_driver_for_iface "$iface")
    channel=$(wifilab_iface_channel "$iface")
    frequency_mhz=$(wifilab_iface_frequency_mhz "$iface")
    regdomain=$(wifilab_regdomain)

    channel=${channel:-0}
    frequency_mhz=${frequency_mhz:-0}

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

    if sha256=$(sha256sum -- "$outfile" 2>/dev/null | awk '{print $1}') && \
       [[ $sha256 =~ ^[0-9a-fA-F]{64}$ ]]; then
        if manifest=$(wifilab_capture_write_manifest \
            "$outfile" \
            "$capture_id" \
            "$created_at_utc" \
            "$iface" \
            "$phy" \
            "$driver" \
            "$channel" \
            "$frequency_mhz" \
            "$regdomain" \
            "$duration" \
            "$max_kib" \
            "$bytes" \
            "$sha256"); then
            metadata_state='complete'
        else
            metadata_warning='capture saved but manifest creation failed'
        fi
    else
        sha256=''
        metadata_warning='capture saved but SHA-256 calculation failed'
    fi

    printf '{'
    printf '"ok":true,'
    printf '"interface":"%s",' "$(wifilab_json_escape "$iface")"
    printf '"duration_seconds":%s,' "$duration"
    printf '"max_kib":%s,' "$max_kib"
    printf '"bytes":%s,' "${bytes:-0}"
    printf '"file":"%s",' "$(wifilab_json_escape "$outfile")"
    printf '"metadata_state":"%s",' "$(wifilab_json_escape "$metadata_state")"
    printf '"manifest":"%s",' "$(wifilab_json_escape "$manifest")"
    printf '"metadata_warning":"%s"' "$(wifilab_json_escape "$metadata_warning")"
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
