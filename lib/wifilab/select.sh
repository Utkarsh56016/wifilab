#!/usr/bin/env bash

# WiFiLab persistent adapter selection.
# Stores physical identity metadata, never a transient wlanX/phyX name.

set -o pipefail

WIFILAB_CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/wifilab
WIFILAB_SELECTION_FILE=$WIFILAB_CONFIG_DIR/selected-adapter

wifilab_selection_field() {
    local key=$1
    [[ -r $WIFILAB_SELECTION_FILE ]] || return 0
    awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$WIFILAB_SELECTION_FILE"
}

wifilab_write_selection() {
    local iface=$1 bus vendor_id model_id driver path

    bus=$(wifilab_udev_property "$iface" ID_BUS)
    vendor_id=$(wifilab_udev_property "$iface" ID_VENDOR_ID)
    model_id=$(wifilab_udev_property "$iface" ID_MODEL_ID)
    driver=$(wifilab_driver_for_iface "$iface")
    path=$(wifilab_udev_property "$iface" ID_PATH)

    mkdir -p "$WIFILAB_CONFIG_DIR"
    umask 077
    cat >"$WIFILAB_SELECTION_FILE" <<EOF
bus=$bus
vendor_id=$vendor_id
model_id=$model_id
driver=$driver
path=$path
EOF
}

wifilab_candidate_ifaces() {
    local iface state connection bus
    while IFS= read -r iface; do
        [[ -n $iface ]] || continue
        state=$(wifilab_nm_state "$iface")
        connection=$(wifilab_nm_connection "$iface")
        bus=$(wifilab_udev_property "$iface" ID_BUS)
        [[ $state == connected && -n $connection ]] && continue
        [[ $bus == usb ]] || continue
        printf '%s\n' "$iface"
    done < <(wifilab_wireless_ifaces)
}

wifilab_select() {
    local iface=${1-}
    local -a candidates=()

    if [[ -z $iface ]]; then
        mapfile -t candidates < <(wifilab_candidate_ifaces)
        case ${#candidates[@]} in
            0)
                printf 'wifilab: no idle USB wireless adapter is available for automatic selection\n' >&2
                return 4
                ;;
            1)
                iface=${candidates[0]}
                ;;
            *)
                printf 'wifilab: multiple lab candidates found; select one explicitly:\n' >&2
                printf '  %s\n' "${candidates[@]}" >&2
                printf 'usage: wifilab select <iface>\n' >&2
                return 4
                ;;
        esac
    fi

    wifilab_require_wireless_iface "$iface" || return
    wifilab_refuse_system_iface "$iface" || return
    wifilab_write_selection "$iface"

    printf 'WiFiLab selected adapter\n'
    printf '  interface : %s\n' "$iface"
    printf '  device    : %s\n' "$(wifilab_human_device_name "$iface" "$(wifilab_udev_property "$iface" ID_BUS)" "$(wifilab_udev_property "$iface" ID_VENDOR_ID)" "$(wifilab_udev_property "$iface" ID_MODEL_ID)")"
    printf '  driver    : %s\n' "$(wifilab_driver_for_iface "$iface")"
    printf '  identity  : %s:%s / %s\n' \
        "${bus:-$(wifilab_udev_property "$iface" ID_BUS)}" \
        "$(wifilab_udev_property "$iface" ID_VENDOR_ID):$(wifilab_udev_property "$iface" ID_MODEL_ID)" \
        "$(wifilab_driver_for_iface "$iface")"
}

wifilab_resolve_selected() {
    local wanted_bus wanted_vendor wanted_model wanted_driver wanted_path
    local iface bus vendor model driver path
    local -a matches=() path_matches=()

    [[ -r $WIFILAB_SELECTION_FILE ]] || {
        printf 'wifilab: no adapter selected; run `wifilab select` or `wifilab select <iface>` first\n' >&2
        return 4
    }

    wanted_bus=$(wifilab_selection_field bus)
    wanted_vendor=$(wifilab_selection_field vendor_id)
    wanted_model=$(wifilab_selection_field model_id)
    wanted_driver=$(wifilab_selection_field driver)
    wanted_path=$(wifilab_selection_field path)

    while IFS= read -r iface; do
        [[ -n $iface ]] || continue
        bus=$(wifilab_udev_property "$iface" ID_BUS)
        vendor=$(wifilab_udev_property "$iface" ID_VENDOR_ID)
        model=$(wifilab_udev_property "$iface" ID_MODEL_ID)
        driver=$(wifilab_driver_for_iface "$iface")
        path=$(wifilab_udev_property "$iface" ID_PATH)

        [[ $bus == "$wanted_bus" ]] || continue
        [[ $vendor == "$wanted_vendor" ]] || continue
        [[ $model == "$wanted_model" ]] || continue
        [[ $driver == "$wanted_driver" ]] || continue
        matches+=("$iface")
        [[ -n $wanted_path && $path == "$wanted_path" ]] && path_matches+=("$iface")
    done < <(wifilab_wireless_ifaces)

    if (( ${#matches[@]} == 1 )); then
        printf '%s\n' "${matches[0]}"
        return 0
    fi

    if (( ${#path_matches[@]} == 1 )); then
        printf '%s\n' "${path_matches[0]}"
        return 0
    fi

    if (( ${#matches[@]} == 0 )); then
        printf 'wifilab: selected physical adapter is not currently present\n' >&2
    else
        printf 'wifilab: selected adapter identity matches multiple interfaces; select one explicitly\n' >&2
    fi
    return 4
}

wifilab_status() {
    local iface
    if ! iface=$(wifilab_resolve_selected); then
        return $?
    fi

    printf 'WiFiLab selected adapter status\n'
    printf '  interface      : %s\n' "$iface"
    printf '  device         : %s\n' "$(wifilab_human_device_name "$iface" "$(wifilab_udev_property "$iface" ID_BUS)" "$(wifilab_udev_property "$iface" ID_VENDOR_ID)" "$(wifilab_udev_property "$iface" ID_MODEL_ID)")"
    printf '  PHY            : %s\n' "$(wifilab_phy_for_iface "$iface")"
    printf '  driver         : %s\n' "$(wifilab_driver_for_iface "$iface")"
    printf '  mode           : %s\n' "$(wifilab_iface_type "$iface")"
    printf '  NetworkManager : %s\n' "$(wifilab_nm_state "$iface")"
    printf '  monitor        : %s\n' "$(wifilab_monitor_supported "$(wifilab_phy_for_iface "$iface")")"
    printf '  regdomain      : %s\n' "$(wifilab_regdomain)"
}
