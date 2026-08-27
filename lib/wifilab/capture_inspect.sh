#!/usr/bin/env bash

# WiFiLab on-demand saved-capture inspection.
# Deep metadata extraction is intentionally explicit and never part of the
# lightweight inventory polling path. capinfos reads only validated WiFiLab
# capture files; this layer never opens a live wireless interface.

set -o pipefail

wifilab_capinfos_field() {
    local report=$1 key=$2

    printf '%s\n' "$report" | awk -v key="$key" '
        {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            if (index(line, key ":") == 1) {
                sub(/^[^:]*:[[:space:]]*/, "", line)
                print line
                exit
            }
        }
    '
}

wifilab_capture_inspect_json() {
    local selector=${1:-latest}
    local target='' capture_id='' path='' rc=0
    local capinfos_path='' timeout_path='' report=''
    local file_type='' encapsulation='' packet_count=0 file_bytes=0
    local duration_seconds=0 start_epoch=0 end_epoch=0
    local actual_sha256='' manifest_sha256='' metadata_state='' integrity_state='unavailable'
    local capinfos_available=false

    target=$(wifilab_capture_analysis_target "$selector") || {
        rc=$?
        case $rc in
            10)
                printf '{"ok":true,"source":"saved_capture","capture":null,"pcap":{"available":false}}\n'
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

    metadata_state=$(wifilab_capture_manifest_state "$path")
    if actual_sha256=$(sha256sum -- "$path" 2>/dev/null | awk '{print $1}') && \
       [[ $actual_sha256 =~ ^[0-9a-fA-F]{64}$ ]]; then
        case $metadata_state in
            complete)
                manifest_sha256=$(wifilab_capture_manifest_string_field "${path%.pcapng}.json" sha256)
                if [[ $manifest_sha256 == "$actual_sha256" ]]; then
                    integrity_state='verified'
                else
                    integrity_state='mismatch'
                fi
                ;;
            legacy) integrity_state='untracked' ;;
            invalid) integrity_state='invalid_manifest' ;;
            *) integrity_state='unavailable' ;;
        esac
    else
        actual_sha256=''
    fi

    if capinfos_path=$(command -v capinfos 2>/dev/null); then
        capinfos_available=true
    fi

    if [[ $capinfos_available == true ]]; then
        if ! timeout_path=$(command -v timeout 2>/dev/null); then
            printf '{"ok":false,"error":"inspection_unavailable","message":"timeout command is unavailable for bounded capture inspection"}\n'
            return 4
        fi

        if report=$(LC_ALL=C "$timeout_path" 15s "$capinfos_path" \
            -M -t -E -c -s -u -a -e -S "$path" 2>/dev/null); then
            :
        else
            rc=$?
            if (( rc == 124 )); then
                printf '{"ok":false,"error":"inspection_timeout","exit_code":124,"message":"capinfos inspection exceeded 15 seconds"}\n'
            else
                printf '{"ok":false,"error":"capture_invalid","exit_code":%s,"message":"capinfos could not read the saved capture"}\n' "$rc"
            fi
            return "$rc"
        fi

        file_type=$(wifilab_capinfos_field "$report" 'File type')
        encapsulation=$(wifilab_capinfos_field "$report" 'File encapsulation')
        packet_count=$(wifilab_capinfos_field "$report" 'Number of packets')
        file_bytes=$(wifilab_capinfos_field "$report" 'File size')
        duration_seconds=$(wifilab_capinfos_field "$report" 'Capture duration')
        start_epoch=$(wifilab_capinfos_field "$report" 'First packet time')
        end_epoch=$(wifilab_capinfos_field "$report" 'Last packet time')

        packet_count=${packet_count%% *}
        file_bytes=${file_bytes%% *}
        duration_seconds=${duration_seconds%% *}
        start_epoch=${start_epoch%% *}
        end_epoch=${end_epoch%% *}

        [[ $packet_count =~ ^[0-9]+$ ]] || packet_count=0
        [[ $file_bytes =~ ^[0-9]+$ ]] || file_bytes=0
        [[ $duration_seconds =~ ^[0-9]+([.][0-9]+)?$ ]] || duration_seconds=0
        [[ $start_epoch =~ ^[0-9]+([.][0-9]+)?$ ]] || start_epoch=0
        [[ $end_epoch =~ ^[0-9]+([.][0-9]+)?$ ]] || end_epoch=0
    fi

    printf '{'
    printf '"ok":true,'
    printf '"source":"saved_capture",'
    printf '"capture":'
    wifilab_capture_emit_item_json "$path"
    printf ','
    printf '"integrity":{'
    printf '"state":"%s",' "$(wifilab_json_escape "$integrity_state")"
    printf '"sha256":"%s",' "$(wifilab_json_escape "$actual_sha256")"
    printf '"manifest_sha256":"%s"' "$(wifilab_json_escape "$manifest_sha256")"
    printf '},'
    printf '"pcap":{'
    printf '"available":%s,' "$capinfos_available"
    printf '"file_type":"%s",' "$(wifilab_json_escape "$file_type")"
    printf '"encapsulation":"%s",' "$(wifilab_json_escape "$encapsulation")"
    printf '"packet_count":%s,' "$packet_count"
    printf '"file_bytes":%s,' "$file_bytes"
    printf '"duration_seconds":%s,' "$duration_seconds"
    printf '"start_epoch":%s,' "$start_epoch"
    printf '"end_epoch":%s' "$end_epoch"
    printf '}'
    printf '}\n'
}
