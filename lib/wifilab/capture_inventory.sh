#!/usr/bin/env bash

# WiFiLab capture inventory and latest-capture helpers.
# This layer is read-only: it never captures packets, mutates radio state,
# rewrites legacy PCAPs, or trusts a runtime wlanX name as persistent identity.

set -o pipefail

wifilab_capture_id_valid() {
    local capture_id=${1-}
    [[ $capture_id =~ ^capture-[0-9]{8}T[0-9]{6}Z-[0-9]+\.pcapng$ ]]
}

wifilab_capture_created_at_from_id() {
    local capture_id=$1 stamp

    wifilab_capture_id_valid "$capture_id" || return 1
    stamp=${capture_id#capture-}
    stamp=${stamp%%-*}

    printf '%s-%s-%sT%s:%s:%sZ\n' \
        "${stamp:0:4}" "${stamp:4:2}" "${stamp:6:2}" \
        "${stamp:9:2}" "${stamp:11:2}" "${stamp:13:2}"
}

wifilab_capture_manifest_string_field() {
    local manifest=$1 key=$2 value=''
    value=$(grep -o '"'"$key"'":"[^"]*"' "$manifest" 2>/dev/null | head -n 1 | cut -d'"' -f4 || true)
    printf '%s\n' "$value"
}

wifilab_capture_manifest_uint_field() {
    local manifest=$1 key=$2 value=''
    value=$(grep -o '"'"$key"'":[0-9][0-9]*' "$manifest" 2>/dev/null | head -n 1 | cut -d: -f2 || true)
    printf '%s\n' "$value"
}

wifilab_capture_manifest_state() {
    local path=$1 name manifest schema manifest_id sha256

    name=${path##*/}
    manifest=${path%.pcapng}.json

    if [[ -L $manifest ]]; then
        printf 'invalid\n'
        return 0
    fi
    if [[ ! -e $manifest ]]; then
        printf 'legacy\n'
        return 0
    fi
    if [[ ! -f $manifest || ! -r $manifest ]]; then
        printf 'invalid\n'
        return 0
    fi

    schema=$(wifilab_capture_manifest_uint_field "$manifest" schema_version)
    manifest_id=$(wifilab_capture_manifest_string_field "$manifest" capture_id)
    sha256=$(wifilab_capture_manifest_string_field "$manifest" sha256)

    if [[ $schema == 1 && $manifest_id == "$name" && $sha256 =~ ^[0-9a-fA-F]{64}$ ]]; then
        printf 'complete\n'
    else
        printf 'invalid\n'
    fi
}

wifilab_capture_emit_item_json() {
    local path=$1 name bytes created_at metadata_state manifest=''
    local iface='' phy='' driver='' channel=0 frequency_mhz=0 regdomain=''
    local duration_limit=0 size_limit_kib=0 sha256=''

    name=${path##*/}
    bytes=$(stat -c '%s' "$path" 2>/dev/null || printf '0')
    created_at=$(wifilab_capture_created_at_from_id "$name" 2>/dev/null || true)
    metadata_state=$(wifilab_capture_manifest_state "$path")

    if [[ $metadata_state == complete || $metadata_state == invalid ]]; then
        manifest=${path%.pcapng}.json
    fi

    if [[ $metadata_state == complete ]]; then
        iface=$(wifilab_capture_manifest_string_field "$manifest" interface)
        phy=$(wifilab_capture_manifest_string_field "$manifest" phy)
        driver=$(wifilab_capture_manifest_string_field "$manifest" driver)
        channel=$(wifilab_capture_manifest_uint_field "$manifest" channel)
        frequency_mhz=$(wifilab_capture_manifest_uint_field "$manifest" frequency_mhz)
        regdomain=$(wifilab_capture_manifest_string_field "$manifest" regdomain)
        duration_limit=$(wifilab_capture_manifest_uint_field "$manifest" duration_limit_seconds)
        size_limit_kib=$(wifilab_capture_manifest_uint_field "$manifest" size_limit_kib)
        sha256=$(wifilab_capture_manifest_string_field "$manifest" sha256)

        [[ $channel =~ ^[0-9]+$ ]] || channel=0
        [[ $frequency_mhz =~ ^[0-9]+$ ]] || frequency_mhz=0
        [[ $duration_limit =~ ^[0-9]+$ ]] || duration_limit=0
        [[ $size_limit_kib =~ ^[0-9]+$ ]] || size_limit_kib=0
    fi

    printf '{'
    printf '"id":"%s",' "$(wifilab_json_escape "$name")"
    printf '"name":"%s",' "$(wifilab_json_escape "$name")"
    printf '"created_at_utc":"%s",' "$(wifilab_json_escape "$created_at")"
    printf '"bytes":%s,' "${bytes:-0}"
    printf '"file":"%s",' "$(wifilab_json_escape "$path")"
    printf '"manifest":"%s",' "$(wifilab_json_escape "$manifest")"
    printf '"metadata_state":"%s",' "$(wifilab_json_escape "$metadata_state")"
    printf '"interface":"%s",' "$(wifilab_json_escape "$iface")"
    printf '"phy":"%s",' "$(wifilab_json_escape "$phy")"
    printf '"driver":"%s",' "$(wifilab_json_escape "$driver")"
    printf '"channel":%s,' "$channel"
    printf '"frequency_mhz":%s,' "$frequency_mhz"
    printf '"regdomain":"%s",' "$(wifilab_json_escape "$regdomain")"
    printf '"duration_limit_seconds":%s,' "$duration_limit"
    printf '"size_limit_kib":%s,' "$size_limit_kib"
    printf '"sha256":"%s"' "$(wifilab_json_escape "$sha256")"
    printf '}'
}

wifilab_capture_names() {
    [[ -d $WIFILAB_CAPTURE_DIR ]] || return 0
    find "$WIFILAB_CAPTURE_DIR" -maxdepth 1 -type f -name 'capture-*.pcapng' -printf '%f\n' 2>/dev/null | sort -r
}

# Overrides the Phase 6 minimal inventory function after capture.sh is sourced.
# Existing fields (name, bytes, file) remain present for UI compatibility.
wifilab_captures_json() {
    local first=1 name path latest=''
    local -a capture_names=()

    mapfile -t capture_names < <(wifilab_capture_names)
    if (( ${#capture_names[@]} > 0 )); then
        latest=${capture_names[0]}
    fi

    printf '{'
    printf '"ok":true,'
    printf '"capture_dir":"%s",' "$(wifilab_json_escape "$WIFILAB_CAPTURE_DIR")"
    printf '"count":%s,' "${#capture_names[@]}"
    printf '"latest":"%s",' "$(wifilab_json_escape "$latest")"
    printf '"captures":['

    for name in "${capture_names[@]}"; do
        wifilab_capture_id_valid "$name" || continue
        path="$WIFILAB_CAPTURE_DIR/$name"
        (( first )) || printf ','
        first=0
        wifilab_capture_emit_item_json "$path"
    done

    printf ']}\n'
}

wifilab_capture_latest_json() {
    local name='' path
    local -a capture_names=()

    mapfile -t capture_names < <(wifilab_capture_names)
    if (( ${#capture_names[@]} == 0 )); then
        printf '{"ok":true,"capture":null}\n'
        return 0
    fi

    name=${capture_names[0]}
    wifilab_capture_id_valid "$name" || {
        printf '{"ok":false,"error":"capture_invalid","message":"latest WiFiLab capture identifier is invalid"}\n'
        return 4
    }

    path="$WIFILAB_CAPTURE_DIR/$name"
    printf '{"ok":true,"capture":'
    wifilab_capture_emit_item_json "$path"
    printf '}\n'
}
