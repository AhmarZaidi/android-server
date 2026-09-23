#!/data/data/com.termux/files/usr/bin/bash
set -u

readonly vnc_port="5901"

timeout 15 proot-distro login ubuntu \
    --shared-tmp \
    --user desktop \
    -- tigervncserver -kill :1 >/dev/null 2>&1 || true

sleep 2
if timeout 2 bash -c \
    "exec 3<>/dev/tcp/127.0.0.1/${vnc_port}" >/dev/null 2>&1; then
    printf '%s\n' "Ubuntu XFCE is still listening on localhost:$vnc_port" >&2
    exit 1
fi

printf '%s\n' "Ubuntu XFCE stopped"
