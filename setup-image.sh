#!/bin/sh

dbg() { printf '\e[37m\e[37m%s\e[m\n' "$*"; }
msg() { printf '\e[37m\e[32m%s\e[m\n' "$*"; }
err() { printf '\e[37m\e[31m%s\e[m\n' "$*"; }

check_bin() {
    type "$@" >/dev/null 2>&1
}

usage() {
    echo "Usage: $0 image-filename [target-arch]"
    echo
    echo "Create makerspace.lt PC image."
    echo
    if [ "$1" ]; then
        err "$@"
    fi
    exit 1
}

cleanup() {
    msg "Cleanup & exit"

    trap - EXIT
    umount -q "$rootfsmnt"
    rm -fr "$rootfsmnt"
    losetup -d "$loopdev"
}

apt_install() {
    DEBIAN_FRONTEND=noninteractive chr apt-get -qq install "$@"
}

do_image_create_disk() {
    msg "Creating disk image $imgfn with a bootable partition"

    qemu-img create "$imgfn" +5G
    echo "type=linux bootable" | sfdisk --quiet --label dos "$imgfn"
}

do_image_setup_loopdev() {
  msg "Creating loopdevice $loopdev from $imgfn"

  losetup --partscan "$loopdev" "$imgfn"
}

do_image_create_partition() {
    msg "Creating ext4 partition inside $loopdevp1"

    mkfs.ext4 -L rootfs -qF "$loopdevp1"
}

do_image_mount() {
    msg "Mounting $loopdevp1 on $rootfsmnt"

    mount "$loopdevp1" "$rootfsmnt"
}

do_image_rootfs() {
    msg "Bootstrapping system on $rootfsmnt"
    
    # shellcheck disable=SC2016
    mmdebstrap \
        --skip=download/empty --skip=essential/unlink \
        --setup-hook='mkdir -p ./cache "$1"/var/cache/apt/archives/' \
        --setup-hook='sync-in ./cache /var/cache/apt/archives/' \
        --customize-hook='sync-out /var/cache/apt/archives ./cache' \
        \
        --variant=important \
        --aptopt='Acquire::Languages "none"' \
        --aptopt='Apt::Install-Recommends "false"' \
        --components=main,contrib,non-free \
        --arch="$arch" \
        stable "$rootfsmnt" http://deb.debian.org/debian 
}

do_image_bootloader() {
    msg "Setting up bootloader on $rootfsmnt"

    dd if=/usr/lib/EXTLINUX/mbr.bin of="$imgfn" conv=notrunc

    cat <<EOF > "$rootfsmnt/extlinux.conf"
default linux
timeout 10
prompt 1

label linux
kernel /vmlinuz
append initrd=/initrd.img root=LABEL=rootfs ro

label memtest
kernel /boot/memtest86+x64.efi
EOF

    extlinux --install "$rootfsmnt"
}

do_system_setup() {
  msg "Running /root/$setup_script inside chroot ($rootfsmnt)"
  
  echo "127.0.0.1 localhost $hostname" > "$rootfsmnt/etc/hosts"
  echo "$hostname" > "$rootfsmnt/etc/hostname"

  install -o root -g root -m0700 -d "$rootfsmnt/root/setup"
  install -o root -g root -m0700 "$script_d/$setup_script" "$rootfsmnt/root/setup/"
  ARCH="$arch" chroot "$rootfsmnt" "/root/setup/$setup_script"
}

script_d="$(dirname "$0")"

imgfn="$1"
arch="$2"
hostname=pc
setup_script=setup-xfce-workstation.sh

if [ "$(id -u)" != "0" ]; then
    usage "This script must be run as root"
fi

if [ ! "$imgfn" ]; then
    usage "image-filename parameter required"
fi

missing_pkgs=
for cmd_pkg in extlinux:extlinux mmdebstrap:mmdebstrap qemu-img:qemu-utils sfdisk:fdisk; do
    cmd=${cmd_pkg%:*}
    pkg=${cmd_pkg#*:}
    if ! check_bin "$cmd"; then
        missing_pkgs="$missing_pkgs $pkg"
    fi
done

if [ "$missing_pkgs" ]; then
    usage "Missing required packages: $missing_pkgs"
fi

if [ ! "$arch" ]; then
    arch=amd64
    msg "Using default architecture: $arch"
fi

set -eu

loopdev=$(losetup -f)
loopdevp1="${loopdev}p1"

rootfsmnt="$(mktemp -d --suffix=rootfs)"

trap cleanup EXIT

if [ -f "$imgfn" ]; then
    msg "Re-using already existing image: $imgfn"
    do_image_setup_loopdev
    do_image_mount
else
    do_image_create_disk
    do_image_setup_loopdev
    do_image_create_partition
    do_image_mount
    do_image_rootfs
    do_image_bootloader
fi

do_system_setup
