#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly distro_alias="ubuntu-gnome-2404"
readonly marker_name=".sanders-gnome-shell-2404"
readonly termux_prefix="/data/data/com.termux/files/usr"
readonly rootfs_dir="${termux_prefix}/var/lib/proot-distro/installed-rootfs/${distro_alias}"
readonly script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"

tracer_pid=$(awk '/^TracerPid:/ { print $2 }' "/proc/$$/status")
if [ "${tracer_pid:-0}" != 0 ]; then
    tracer_name=$(awk '/^Name:/ { print $2 }' "/proc/${tracer_pid}/status")
    if [ "$tracer_name" = "proot" ]; then
        printf '%s\n' "Run this script from native Termux." >&2
        exit 1
    fi
fi

if [ "${PREFIX:-}" != "$termux_prefix" ]; then
    printf '%s\n' "Run this script from native Termux." >&2
    exit 1
fi

if [ ! -f "$rootfs_dir/$marker_name" ]; then
    printf '%s\n' "The recognized $distro_alias environment is missing." >&2
    exit 1
fi

for command_name in proot-distro termux-x11 termux-x11-preference \
    virgl_test_server_android; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '%s\n' "Missing native Termux command: $command_name" >&2
        exit 1
    fi
done

if ! /system/bin/pm list packages 2>/dev/null | grep -qx 'package:com.termux.x11'; then
    printf '%s\n' "The Termux:X11 Android app is not installed." >&2
    exit 1
fi

printf '%s\n' "Verifying X11 diagnostics inside $distro_alias"
proot-distro login "$distro_alias" --shared-tmp -- /bin/bash -s <<'GUEST_ROOT'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
dpkg --configure -a
apt-get update
apt-get install -y --no-install-recommends x11-utils
GUEST_ROOT

install -m 700 \
    "$script_dir/gnome-shell-termux-x11-start.sh" \
    "$termux_prefix/bin/ugnomex11"
install -m 700 \
    "$script_dir/gnome-shell-termux-x11-stop.sh" \
    "$termux_prefix/bin/ugnomex11stop"

printf '%s\n' \
    "Accelerated Termux:X11 mode is ready." \
    "Start it from native Termux with: ugnomex11" \
    "Stop it with: ugnomex11stop" \
    "View the Termux:X11 Android surface from Windows with scrcpy."
