# Custom proot-distro plug-in for the isolated GNOME Shell environment.
# Ubuntu Base is intentionally minimal, so bootstrap the utilities that the
# standard Ubuntu plug-in expects before the desktop setup runs.

DISTRO_NAME="Ubuntu 24.04.5 LTS - isolated GNOME Shell"
DISTRO_COMMENT="Official Ubuntu Base 24.04.5 LTS (Noble), ARM64."

TARBALL_URL['aarch64']="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-arm64.tar.gz"
TARBALL_SHA256['aarch64']="a91d5a93010193712d346d761372b7c9db6dfcf093893161c64ca107f05914f2"
TARBALL_STRIP_OPT=0

distro_setup() {
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt-get update
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y \
		adduser ca-certificates locales sudo

	sed -i -E 's/#[[:space:]]?(en_US.UTF-8[[:space:]]+UTF-8)/\1/g' ./etc/locale.gen
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales
}
