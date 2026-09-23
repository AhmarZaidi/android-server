#!/data/data/com.termux/files/usr/bin/bash
set -u

readonly distro_alias="ubuntu-gnome-2404"
readonly rfb_port="5904"
readonly state_dir="$HOME/.local/state/gnome-shell-termux-x11"

timeout 15 proot-distro login "$distro_alias" \
    --shared-tmp \
    --user desktop \
    -- /bin/bash -c \
        "pkill -f 'x11vnc.*-rfbport ${rfb_port}' 2>/dev/null || true; pkill -f gnome-shell-proot-session 2>/dev/null || true" \
    >/dev/null 2>&1 || true

for pid_file in "$state_dir/x11vnc.pid" "$state_dir/gnome.pid" \
    "$state_dir/termux-x11.pid"; do
    [ -s "$pid_file" ] || continue
    pid=$(cat "$pid_file")
    kill "$pid" >/dev/null 2>&1 || true
done

am force-stop --user 0 com.termux.x11 >/dev/null 2>&1 || true

if [ -s "$state_dir/preferences.before" ]; then
    termux-x11-preference <"$state_dir/preferences.before" >/dev/null 2>&1 || true
    rm -f "$state_dir/preferences.before"
fi

sleep 2
if timeout 2 bash -c \
    "exec 3<>/dev/tcp/127.0.0.1/${rfb_port}" >/dev/null 2>&1; then
    printf '%s\n' "Accelerated GNOME is still listening on localhost:$rfb_port" >&2
    exit 1
fi

printf '%s\n' "Accelerated Termux:X11 GNOME stopped"
