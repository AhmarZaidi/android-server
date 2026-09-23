#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly termux_prefix="/data/data/com.termux/files/usr"
readonly script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly target_dir="$HOME/.local/bin"
readonly backup_dir="$HOME/.local/state/ubuntu-gui/launcher-backup"

if [ "${PREFIX:-}" != "$termux_prefix" ]; then
    printf '%s\n' "Run this script from native Termux." >&2
    exit 1
fi

for required_file in xfce-vnc-start.sh xfce-vnc-stop.sh; do
    [ -f "$script_dir/$required_file" ] || {
        printf '%s\n' "Missing required file: $script_dir/$required_file" >&2
        exit 1
    }
done

mkdir -p "$target_dir" "$backup_dir"
for existing_file in ubuntu-gui-start ubuntu-gui-stop; do
    if [ -f "$target_dir/$existing_file" ] \
        && [ ! -f "$backup_dir/$existing_file.original" ]; then
        cp -p "$target_dir/$existing_file" "$backup_dir/$existing_file.original"
    fi
done

install -m 700 "$script_dir/xfce-vnc-start.sh" "$target_dir/ubuntu-gui-start"
install -m 700 "$script_dir/xfce-vnc-stop.sh" "$target_dir/ubuntu-gui-stop"

printf '%s\n' \
    "XFCE VNC profiles installed." \
    "Use: ugui ultra" \
    "     ugui smooth" \
    "     ugui balanced" \
    "     ugui quality"
