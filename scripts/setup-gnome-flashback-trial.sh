#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly distro_alias="ubuntu-gnome-flashback"
readonly marker_name=".sanders-gnome-flashback-trial"
readonly termux_prefix="/data/data/com.termux/files/usr"
readonly rootfs_dir="${termux_prefix}/var/lib/proot-distro/installed-rootfs/${distro_alias}"
readonly script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"

tracer_pid=$(awk '/^TracerPid:/ { print $2 }' "/proc/$$/status")
if [ "${tracer_pid:-0}" != 0 ]; then
    tracer_name=$(awk '/^Name:/ { print $2 }' "/proc/${tracer_pid}/status")
    if [ "$tracer_name" = "proot" ]; then
        printf '%s\n' \
            "Run this script from native Termux, outside every PRoot environment." >&2
        exit 1
    fi
fi

if [ "${PREFIX:-}" != "$termux_prefix" ]; then
    printf '%s\n' \
        "Run this script from native Termux, outside every PRoot environment." >&2
    exit 1
fi

if ! command -v proot-distro >/dev/null 2>&1; then
    printf '%s\n' "proot-distro is not installed in Termux." >&2
    exit 1
fi

available_kb=$(df -Pk "$termux_prefix" | awk 'NR == 2 { print $4 }')
if [ -z "$available_kb" ] || [ "$available_kb" -lt 6291456 ]; then
    printf '%s\n' \
        "At least 6 GiB of free storage is required for this isolated trial." >&2
    exit 1
fi

if [ -d "$rootfs_dir" ] && [ ! -f "$rootfs_dir/$marker_name" ]; then
    printf '%s\n' \
        "Refusing to modify existing unrecognized environment: $rootfs_dir" >&2
    exit 1
fi

if [ ! -d "$rootfs_dir" ]; then
    printf '%s\n' "Installing isolated Ubuntu environment: $distro_alias"
    proot-distro install --override-alias "$distro_alias" ubuntu
    : >"$rootfs_dir/$marker_name"
else
    printf '%s\n' "Resuming setup of recognized environment: $distro_alias"
fi

printf '%s\n' "Installing GNOME Flashback and TigerVNC inside $distro_alias"
proot-distro login "$distro_alias" --shared-tmp -- /bin/bash -s <<'GUEST_ROOT'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

dpkg --configure -a

# The PRoot-Distro plug-in enables this browser PPA by default. The desktop
# trial does not need it, and excluding it keeps APT limited to Ubuntu sources.
for ppa_file in /etc/apt/sources.list.d/mozillateam-ubuntu-ppa-*.sources; do
    [ -f "$ppa_file" ] || continue
    mv "$ppa_file" "$ppa_file.disabled"
done

apt-get update
apt-get install -y --no-install-recommends \
    adwaita-icon-theme \
    dbus-x11 \
    fonts-dejavu-core \
    gnome-session-flashback \
    gnome-terminal \
    tigervnc-standalone-server \
    tigervnc-tools \
    x11-xserver-utils

id desktop >/dev/null 2>&1 || useradd -m -s /bin/bash desktop
install -d -o desktop -g desktop -m 700 \
    /home/desktop/.config/tigervnc \
    /home/desktop/.local/bin \
    /home/desktop/.runtime
GUEST_ROOT

printf '%s\n' "Configuring the GNOME Flashback VNC session"
proot-distro login "$distro_alias" --shared-tmp --user desktop -- /bin/bash -s <<'GUEST_USER'
set -euo pipefail

mkdir -p "$HOME/.config/tigervnc" "$HOME/.local/bin" "$HOME/.runtime"
chmod 700 "$HOME/.config/tigervnc" "$HOME/.local/bin" "$HOME/.runtime"

# GNOME 49 normally starts these components through a systemd user manager.
# PRoot has no such manager, so this wrapper starts the small essential set
# directly within one D-Bus session.
tee "$HOME/.local/bin/gnome-flashback-proot-session" >/dev/null <<'SESSION'
#!/bin/bash
set -u

child_pids=()
cleaned_up=0

start_component() {
    "$@" &
    child_pids+=("$!")
}

cleanup() {
    [ "$cleaned_up" -eq 0 ] || return 0
    cleaned_up=1
    if [ "${#child_pids[@]}" -gt 0 ]; then
        kill "${child_pids[@]}" >/dev/null 2>&1 || true
        wait "${child_pids[@]}" >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT HUP INT TERM

start_component /usr/libexec/gsd-xsettings
start_component /usr/libexec/gsd-keyboard
start_component gnome-flashback
sleep 1
start_component metacity --replace
sleep 1

gnome-panel &
panel_pid=$!
child_pids+=("$panel_pid")
wait "$panel_pid"
SESSION

chmod 700 "$HOME/.local/bin/gnome-flashback-proot-session"

tee "$HOME/.config/tigervnc/xstartup" >/dev/null <<'XSTARTUP'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="$HOME/.runtime"
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP="GNOME-Flashback:GNOME"
export XDG_SESSION_DESKTOP=gnome-flashback-metacity
export DESKTOP_SESSION=gnome-flashback-metacity
export GDK_BACKEND=x11
export LIBGL_ALWAYS_SOFTWARE=1
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
exec dbus-launch --exit-with-session \
    "$HOME/.local/bin/gnome-flashback-proot-session"
XSTARTUP

chmod 700 "$HOME/.config/tigervnc/xstartup"

if [ ! -s "$HOME/.config/tigervnc/passwd" ]; then
    printf '%s\n' "Create a password for the GNOME trial VNC server."
    tigervncpasswd
fi
GUEST_USER

install -d -m 700 "$HOME/.local/bin"
install -m 700 "$script_dir/gnome-flashback-start.sh" "$HOME/.local/bin/ugnome"
install -m 700 "$script_dir/gnome-flashback-stop.sh" "$HOME/.local/bin/ugnomestop"

printf '%s\n' \
    "GNOME Flashback trial setup is ready." \
    "Start it from native Termux with: ugnome" \
    "Stop it with: ugnomestop"
