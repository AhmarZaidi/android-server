#!/data/data/com.termux/files/usr/bin/bash
set -u

timeout 15 proot-distro login ubuntu \
    --shared-tmp \
    --user desktop \
    -- tigervncserver -kill :2 >/dev/null 2>&1 || true

sleep 2
if timeout 2 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5902' >/dev/null 2>&1; then
    printf '%s\n' "GNOME Flashback is still listening on localhost:5902" >&2
    exit 1
fi

printf '%s\n' "GNOME Flashback stopped"
