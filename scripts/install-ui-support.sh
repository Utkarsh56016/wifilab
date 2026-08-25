#!/usr/bin/env bash

# Install/remove the root-owned WiFiLab helper and polkit policy.
# Default mode is inspection-only; mutation requires --apply or --remove.

set -euo pipefail

SOURCE=${BASH_SOURCE[0]}
SCRIPT_DIR=$(cd -P -- "$(dirname -- "$SOURCE")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

LIB_DST=/usr/lib/wifilab
HELPER_DST=$LIB_DST/wifilab-helper
POLICY_DST=/usr/share/polkit-1/actions/io.github.utkarsh56016.wifilab.policy

show_plan() {
    cat <<EOF
WiFiLab UI privileged-support plan

Source repository:
  $ROOT_DIR

Will install root-owned files:
  $LIB_DST/discover.sh
  $LIB_DST/state.sh
  $LIB_DST/select.sh
  $HELPER_DST
  $POLICY_DST

The Quickshell UI remains unprivileged. Mutating requests use pkexec and the
allowlisted helper. No NetworkManager service restart or global interface
mutation is performed by this installer.

Apply:
  $0 --apply

Rollback:
  $0 --remove
EOF
}

apply_install() {
    command -v sudo >/dev/null 2>&1 || { echo 'install-ui-support: sudo is required' >&2; exit 1; }
    command -v pkexec >/dev/null 2>&1 || { echo 'install-ui-support: pkexec/polkit is required' >&2; exit 1; }

    for path in \
        "$ROOT_DIR/lib/wifilab/discover.sh" \
        "$ROOT_DIR/lib/wifilab/state.sh" \
        "$ROOT_DIR/lib/wifilab/select.sh" \
        "$ROOT_DIR/libexec/wifilab-helper" \
        "$ROOT_DIR/polkit/io.github.utkarsh56016.wifilab.policy"; do
        [[ -r $path ]] || { echo "install-ui-support: missing source file: $path" >&2; exit 1; }
    done

    sudo install -d -o root -g root -m 0755 "$LIB_DST"
    sudo install -o root -g root -m 0644 "$ROOT_DIR/lib/wifilab/discover.sh" "$LIB_DST/discover.sh"
    sudo install -o root -g root -m 0644 "$ROOT_DIR/lib/wifilab/state.sh" "$LIB_DST/state.sh"
    sudo install -o root -g root -m 0644 "$ROOT_DIR/lib/wifilab/select.sh" "$LIB_DST/select.sh"
    sudo install -o root -g root -m 0755 "$ROOT_DIR/libexec/wifilab-helper" "$HELPER_DST"
    sudo install -o root -g root -m 0644 \
        "$ROOT_DIR/polkit/io.github.utkarsh56016.wifilab.policy" "$POLICY_DST"

    echo 'WiFiLab UI privileged support installed.'
    echo
    echo 'Validation:'
    ls -ld "$LIB_DST"
    ls -l "$HELPER_DST" "$POLICY_DST"
    if command -v pkaction >/dev/null 2>&1; then
        pkaction --action-id io.github.utkarsh56016.wifilab.control --verbose 2>/dev/null || true
    fi
}

remove_install() {
    command -v sudo >/dev/null 2>&1 || { echo 'install-ui-support: sudo is required' >&2; exit 1; }
    sudo rm -f "$POLICY_DST" "$HELPER_DST" \
        "$LIB_DST/discover.sh" "$LIB_DST/state.sh" "$LIB_DST/select.sh"
    sudo rmdir "$LIB_DST" 2>/dev/null || true
    echo 'WiFiLab UI privileged support removed.'
}

case ${1-} in
    '') show_plan ;;
    --apply) apply_install ;;
    --remove) remove_install ;;
    *) echo "usage: $0 [--apply|--remove]" >&2; exit 2 ;;
esac
