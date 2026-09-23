#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly distro_alias="ubuntu-gnome-2404"
readonly marker_name=".sanders-gnome-shell-2404"
readonly termux_prefix="/data/data/com.termux/files/usr"
readonly rootfs_dir="${termux_prefix}/var/lib/proot-distro/installed-rootfs/${distro_alias}"
readonly plugin_file="${termux_prefix}/etc/proot-distro/${distro_alias}.sh"
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

for required_file in \
    proot-distro-ubuntu-gnome-2404.sh \
    gnome-shell-ubuntu-2404-start.sh \
    gnome-shell-ubuntu-2404-stop.sh \
    gnome-shell-ubuntu-2404-remove.sh; do
    if [ ! -f "$script_dir/$required_file" ]; then
        printf '%s\n' "Missing required file: $script_dir/$required_file" >&2
        exit 1
    fi
done

available_kb=$(df -Pk "$termux_prefix" | awk 'NR == 2 { print $4 }')
if [ -z "$available_kb" ] || [ "$available_kb" -lt 6291456 ]; then
    printf '%s\n' \
        "At least 6 GiB of free storage is required for this isolated setup." >&2
    exit 1
fi

if [ -d "$rootfs_dir" ] && [ ! -f "$rootfs_dir/$marker_name" ]; then
    printf '%s\n' \
        "Refusing to modify existing unrecognized environment: $rootfs_dir" >&2
    exit 1
fi

install -m 600 \
    "$script_dir/proot-distro-ubuntu-gnome-2404.sh" \
    "$plugin_file"

if [ ! -d "$rootfs_dir" ]; then
    printf '%s\n' \
        "Installing isolated Ubuntu 24.04.5 environment: $distro_alias" \
        "The existing ubuntu environment is not being modified."
    proot-distro install "$distro_alias"
    : >"$rootfs_dir/$marker_name"
else
    printf '%s\n' "Resuming recognized environment: $distro_alias"
fi

printf '%s\n' "Installing GNOME Shell 46 and TigerVNC inside $distro_alias"
proot-distro login "$distro_alias" --shared-tmp -- /bin/bash -s <<'GUEST_ROOT'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

dpkg --configure -a
apt-get update
apt-get install -y --no-install-recommends \
    at-spi2-core \
    dbus-x11 \
    dconf-cli \
    fonts-dejavu-core \
    gnome-backgrounds \
    gnome-control-center \
    gnome-keyring \
    gnome-session \
    gnome-shell \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-ubuntu-dock \
    gnome-terminal \
    libgl1-mesa-dri \
    mesa-utils \
    nautilus \
    tigervnc-standalone-server \
    tigervnc-tools \
    ubuntu-session \
    x11-xserver-utils \
    xdg-user-dirs \
    yaru-theme-gnome-shell \
    yaru-theme-gtk \
    yaru-theme-icon

id desktop >/dev/null 2>&1 || \
    adduser --disabled-password --gecos '' desktop

install -d -o desktop -g desktop -m 700 \
    /home/desktop/.vnc \
    /home/desktop/.local/bin \
    /home/desktop/.runtime-gnome-shell
GUEST_ROOT

printf '%s\n' "Configuring the GNOME Shell VNC session"
proot-distro login "$distro_alias" --shared-tmp --user desktop -- /bin/bash -s <<'GUEST_USER'
set -euo pipefail

mkdir -p \
    "$HOME/.vnc" \
    "$HOME/.local/bin" \
    "$HOME/.runtime-gnome-shell"
chmod 700 \
    "$HOME/.vnc" \
    "$HOME/.local/bin" \
    "$HOME/.runtime-gnome-shell"

cat >"$HOME/.local/bin/gnome-shell-proot-session" <<'SESSION'
#!/bin/bash
set -u

# A normal GNOME session expects a systemd user manager and a system D-Bus.
# PRoot provides neither, so start GNOME Shell and its essential settings
# components directly inside the VNC session's private D-Bus.
child_pids=()
cleaned_up=0

start_component() {
    if [ -x "$1" ]; then
        "$@" &
        child_pids+=("$!")
    fi
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

# Several GNOME Shell components create proxies on the system bus even when
# their services are optional. Provide an empty private bus so proxy creation
# succeeds and unavailable services fail normally instead of aborting the UI.
system_bus_socket="$XDG_RUNTIME_DIR/gnome-proot-system-bus"
rm -f "$system_bus_socket"
system_bus_pid=$(dbus-daemon \
    --session \
    --address="unix:path=$system_bus_socket" \
    --fork \
    --nopidfile \
    --print-pid=1)
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$system_bus_socket"
child_pids+=("$system_bus_pid")

gsettings set org.gnome.mutter dynamic-workspaces true >/dev/null 2>&1 || true
gsettings set org.gnome.shell.extensions.dash-to-dock isolate-workspaces true \
    >/dev/null 2>&1 || true

start_component /usr/libexec/gsd-xsettings
start_component /usr/libexec/gsd-keyboard
start_component /usr/libexec/gsd-media-keys

gnome-shell --x11 --replace
SESSION
chmod 700 "$HOME/.local/bin/gnome-shell-proot-session"

cat >"$HOME/.vnc/xstartup" <<'XSTARTUP'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="$HOME/.runtime-gnome-shell"
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP="ubuntu:GNOME"
export XDG_SESSION_DESKTOP=ubuntu
export DESKTOP_SESSION=ubuntu
export GNOME_SHELL_SESSION_MODE=ubuntu
export GDK_BACKEND=x11
if [ "${GNOME_GFX_MODE:-software}" = virgl ]; then
    unset LIBGL_ALWAYS_SOFTWARE
    export GALLIUM_DRIVER=virpipe
    export MESA_GL_VERSION_OVERRIDE=4.0
    export MESA_GLSL_VERSION_OVERRIDE=400
else
    unset GALLIUM_DRIVER
    unset MESA_GL_VERSION_OVERRIDE
    unset MESA_GLSL_VERSION_OVERRIDE
    export LIBGL_ALWAYS_SOFTWARE=1
fi
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
exec dbus-run-session -- "$HOME/.local/bin/gnome-shell-proot-session"
XSTARTUP
chmod 700 "$HOME/.vnc/xstartup"
GUEST_USER

guest_passwd_file="$rootfs_dir/home/desktop/.vnc/passwd"
if [ ! -s "$guest_passwd_file" ]; then
    printf '%s\n' \
        "Create a 6-8 character password for the isolated GNOME VNC server." \
        "Input is read by native Termux because PRoot cannot access /dev/tty directly."

    while true; do
        IFS= read -r -s -p "VNC password: " vnc_password
        printf '\n'
        IFS= read -r -s -p "Confirm password: " vnc_password_confirm
        printf '\n'

        if [ "$vnc_password" != "$vnc_password_confirm" ]; then
            printf '%s\n' "Passwords do not match; try again." >&2
            continue
        fi

        if [ "${#vnc_password}" -lt 6 ] || [ "${#vnc_password}" -gt 8 ]; then
            printf '%s\n' "Use between 6 and 8 characters." >&2
            continue
        fi

        break
    done

    printf '%s\n' "$vnc_password" | \
        proot-distro login "$distro_alias" \
            --shared-tmp \
            --user desktop \
            -- /bin/bash -c \
                'umask 077; tigervncpasswd -f >"$HOME/.vnc/passwd"'
    unset vnc_password vnc_password_confirm
fi

install -m 700 \
    "$script_dir/gnome-shell-ubuntu-2404-start.sh" \
    "$termux_prefix/bin/ugnomefull"
install -m 700 \
    "$script_dir/gnome-shell-ubuntu-2404-stop.sh" \
    "$termux_prefix/bin/ugnomefullstop"
install -m 700 \
    "$script_dir/gnome-shell-ubuntu-2404-remove.sh" \
    "$termux_prefix/bin/ugnomefullremove"

printf '%s\n' \
    "Isolated GNOME Shell setup is ready." \
    "Start it from native Termux with: ugnomefull" \
    "Stop it with: ugnomefullstop" \
    "It listens only on localhost:5903."
