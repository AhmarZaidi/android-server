#!/data/data/com.termux/files/usr/bin/bash
set -u

readonly distro_alias="ubuntu-gnome-2404"
readonly display_number="3"
readonly vnc_port="5903"

timeout 20 proot-distro login "$distro_alias" \
    --shared-tmp \
    --user desktop \
    -- tigervncserver -kill ":${display_number}" >/dev/null 2>&1 || true

sleep 2

if timeout 2 bash -c \
    "exec 3<>/dev/tcp/127.0.0.1/${vnc_port}" >/dev/null 2>&1; then
    printf '%s\n' "GNOME Shell is still listening on localhost:$vnc_port" >&2
    exit 1
fi

printf '%s\n' "GNOME Shell stopped"
