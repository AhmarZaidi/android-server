#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly distro_alias="ubuntu-gnome-2404"
readonly marker_name=".sanders-gnome-shell-2404"
readonly termux_prefix="/data/data/com.termux/files/usr"
readonly rootfs_dir="${termux_prefix}/var/lib/proot-distro/installed-rootfs/${distro_alias}"
readonly plugin_file="${termux_prefix}/etc/proot-distro/${distro_alias}.sh"

if [ "${PREFIX:-}" != "$termux_prefix" ]; then
    printf '%s\n' "Run this command from native Termux." >&2
    exit 1
fi

if [ "${1:-}" != "--confirm" ]; then
    printf '%s\n' \
        "This removes only the isolated $distro_alias environment and all data inside it." \
        "Run: ugnomefullremove --confirm" >&2
    exit 2
fi

if [ -d "$rootfs_dir" ] && [ ! -f "$rootfs_dir/$marker_name" ]; then
    printf '%s\n' "Refusing to remove an unrecognized rootfs: $rootfs_dir" >&2
    exit 1
fi

"${termux_prefix}/bin/ugnomefullstop" >/dev/null 2>&1 || true

if [ -d "$rootfs_dir" ]; then
    proot-distro remove "$distro_alias"
fi

rm -f "$plugin_file"
rm -rf "$HOME/.local/state/gnome-shell-ubuntu-2404"
rm -f \
    "${termux_prefix}/bin/ugnomefull" \
    "${termux_prefix}/bin/ugnomefullstop" \
    "${termux_prefix}/bin/ugnomefullremove"

printf '%s\n' \
    "Removed the isolated GNOME Shell environment." \
    "The existing ubuntu environment was not changed."
