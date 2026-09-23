#!/data/data/com.termux/files/usr/bin/bash
set -u

readonly distro_alias="ubuntu"
readonly display_number="5"
readonly vnc_port="5905"
readonly state_dir="$HOME/.local/state/ubuntu-turbovnc"

timeout 20 proot-distro login "$distro_alias" \
    --shared-tmp \
    --user desktop \
    -- /opt/TurboVNC/bin/vncserver -kill ":$display_number" \
    >/dev/null 2>&1 || true

for _attempt in $(seq 1 10); do
    if ! timeout 2 bash -c \
        "exec 3<>/dev/tcp/127.0.0.1/${vnc_port}" \
        >/dev/null 2>&1; then
        rm -f "$state_dir/wrapper.pid"
        printf '%s\n' "TurboVNC XFCE stopped"
        exit 0
    fi
    sleep 1
done

printf '%s\n' \
    "TurboVNC is still listening on localhost:$vnc_port" \
    "The TigerVNC session on port 5901 was not touched." >&2
exit 1
