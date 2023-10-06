#!/bin/sh

. "$(dirname "$0")/_lib"

if [ "$(id -u)" != "0" ]; then
    usage "This script must be run as root"
fi

set -eu

# Repo URL for automatic self updates
REPO_URL="https://github.com/makerspacelt/pc-installer.git"

chroot_cleanup() {
    msg "Chroot cleanup"

    trap - EXIT
    umount /proc
}

chroot_mounts() {
  trap chroot_cleanup EXIT
  mount -t proc none /proc
}

apt_install() {
    DEBIAN_FRONTEND=noninteractive apt-get -qq install "$@"
}

do_self_update() {
  if [ -f "$script_dir/branch" ]; then
    branch="$(cat "$script_dir/branch")"
  else
    branch=master
  fi
  rm -fr "${script_dir}-new"
  if git clone -b "$branch" "$REPO_URL" "${script_dir}-new"; then
    msg "Self update successful. Restarting."
    rm -fr "$script_dir"
    mv "${script_dir}-new" "$script_dir"
    cd .
    NO_UPDATE=1 exec "$script_path"
  else
    err "Update failed."
  fi
}

do_maybe_apt_update() {
  # Update the package cache if it wasn't updated in the last 24 hours
  if [ ! -f "/var/lib/apt/periodic/update-success-stamp" ] || [ $(($(date +%s) - $(stat -c %Y "/var/lib/apt/periodic/update-success-stamp"))) -gt 86400 ]; then
    msg "Updating APT package cache (relax, might take a while)"
    apt-get update && touch "/var/lib/apt/periodic/update-success-stamp"
    return 0
  fi
  return 1
}

do_system_base() {
    msg "Base system configuration"

    # User
    groups="sudo,dialout,plugdev,video,audio,cdrom,lp,games,kvm"
    if grep -q ^user: /etc/passwd; then
      usermod -U -G "$groups" -s /bin/bash user
    else
      useradd -m -U -G "$groups" -s /bin/bash user
    fi
    usermod -s /bin/bash root
    echo "user:user" | chpasswd
    echo "root:root" | chpasswd

    # APT
    echo 'Acquire::Languages "none";' > "/etc/apt/apt.conf.d/99no-languages"

    cat <<EOF >/etc/apt/sources.list
deb http://deb.debian.org/debian/ bullseye main contrib non-free
deb http://deb.debian.org/debian/ bullseye-updates main contrib non-free
deb http://deb.debian.org/debian/ bullseye-backports main contrib non-free
deb http://deb.debian.org/debian-security/ bullseye-security main contrib non-free
EOF

    # fstab (root)
    echo 'LABEL=rootfs / ext4 defaults,discard,noatime 1 1' > /etc/fstab
    # fstab (nas)
    mkdir -p /media/nas
    echo '//nas.lan/share /media/nas cifs users,uid=1000,gid=1000,user=user,pass=user,vers=3.0' >> /etc/fstab

    # Set timezone
    ln -sf ../usr/share/zoneinfo/Europe/Vilnius /etc/localtime
    
    # Wireless country
    echo REGDOMAIN=LT > /etc/default/crda
}

do_enlarge_partition() {
  msg "Growing partition"
  
  if growpart /dev/sda 1; then
    resize2fs /dev/sda1
  fi
}

do_packages_base() {
  msg "Installing basic packages"

  apt_install \
    dosfstools \
    dpkg-dev \
    firmware-amd-graphics \
    firmware-ath9k-htc \
    firmware-atheros \
    firmware-brcm80211 \
    firmware-intel-sound \
    firmware-iwlwifi \
    firmware-libertas \
    firmware-linux \
    firmware-misc-nonfree \
    firmware-realtek \
    htop \
    iproute2 \
    locales \
    "linux-image-$ARCH" \
    "linux-headers-$ARCH" \
    ntfs-3g \
    openssh-client \
    openssh-server \
    python-is-python3 \
    usbutils \
    sudo \
    vim \

}

do_packages_desktop() {
  msg "Installing desktop packages (this will take a while...)"

  apt_install \
    bash-completion \
    bluetooth \
    pulseaudio-module-bluetooth \
    cifs-utils \
    cloud-guest-utils \
    curl \
    eject \
    ffmpeg \
    file \
    fonts-cantarell \
    fonts-dejavu \
    fonts-freefont-ttf \
    fonts-hack \
    fonts-liberation2 \
    fonts-noto \
    fonts-terminus \
    fonts-ubuntu \
    git \
    gvfs \
    i3-wm \
    ncat \
    network-manager-gnome \
    nmap \
    mc \
    pciutils \
    rsync \
    screen \
    task-xfce-desktop \
    tcpdump \
    thunar-archive-plugin \
    thunar-gtkhash \
    thunar-volman \
    tmux \
    vim-gtk3 \
    xarchiver \
    xfce4-terminal \
    xserver-xorg-video-intel \
    xserver-xorg-video-all \

    usermod -a -G bluetooth user
}

do_packages_extra() {
  msg "Installing extra packages (this will take a while...)"
  
  apt_install -t bullseye-backports \
    build-essential \
    chromium webext-ublock-origin-chromium \
    evince \
    geeqie \
    gimp \
    inkscape \
    libreoffice \
    pavucontrol \
    pulseaudio \
    ttf-mscorefonts-installer \
    vlc \
    wireshark \
    x11vnc \
    xfce4-power-manager \

}

do_packages_makerspace() {
  msg "Installing makerspace packages (this will take a while...)"

  apt_install -t bullseye-backports \
    arduino \
    cura \
    docker-compose \
    docker.io \
    obs-studio \
    openarena openarena-oacmp1 \
    v4l-utils \
 
    usermod -a -G docker user
}

do_setup_kicad() {
  msg "Installing kicad (this will take a while...)"

  apt_install -t bullseye-backports \
    kicad \
    kicad-libraries \
    kicad-packages3d \

}

do_improve_life() {
  msg "Improving life"
 
  # Set locale
  echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
  echo 'lt_LT.UTF-8 UTF-8' >> /etc/locale.gen
  echo 'LANG=en_US.UTF-8' > /etc/default/locale
  echo 'LC_TIME=lt_LT.UTF-8' > /etc/default/locale
  echo 'LC_PAPER=lt_LT.UTF-8' >> /etc/default/locale
  echo 'LC_MEASUREMENT=lt_LT.UTF-8' >> /etc/default/locale
  locale-gen
    
  # X11 keyboard layout
  sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="lt(us),lt"/' /etc/default/keyboard
  sed -i 's/^XKBOPTIONS=.*/XKBOPTIONS="grp:alt_shift_toggle"/' /etc/default/keyboard

  # Bash completion for all bashers
  if ! grep -q '^\. /etc/bash_completion' /etc/bash.bashrc; then
    echo '. /etc/bash_completion' >> /etc/bash.bashrc 
  fi

  # PgUp/PgDown to go through search history
  sed -ir 's/.*history-search-backward.*/"\\e[5~": history-search-backward/' /etc/inputrc
  sed -ir 's/.*history-search-forward.*/"\\e[6~": history-search-forward/' /etc/inputrc

  # Disable pc speaker beeps
  echo 'blacklist pcspkr' > /etc/modprobe.d/pcspkr-blacklist.conf

  # Autologin
  sed -i 's/^#autologin-user=.*/autologin-user=user/' /etc/lightdm/lightdm.conf

  # Force systemd+networkmanager to wait for internet
  mkdir /etc/systemd/system/NetworkManager-wait-online.service.d
  cat <<EOF > /etc/systemd/system/NetworkManager-wait-online.service.d/override.conf
[Service]
ExecStart=/usr/bin/nm-online -q
EOF

  # makerspace.lt wifi
  cat <<EOF > /etc/NetworkManager/system-connections/makerspace.lt.nmconnection
[connection]
id=makerspace.lt
type=wifi
permissions=user:user:;

[wifi]
mode=infrastructure
ssid=makerspace.lt

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=100 decibelu

[ipv4]
method=auto
EOF
  chmod 600 /etc/NetworkManager/system-connections/makerspace.lt.nmconnection

  # Add auto update
  touch /etc/rc.local
  chmod +x /etc/rc.local
  echo '#!/bin/sh' > /etc/rc.local

  cmd_setup='/root/setup/setup-xfce-workstation.sh | logger --skip-empty --stderr --tag pc-installer-setup'
  sed -i '/setup-xfce-workstation/d; /^exit 0/d' /etc/rc.local
  echo "$cmd_setup" >> /etc/rc.local

  if [ -x "$script_dir/hosts/all/setup.sh" ]; then
    cd "$script_dir/hosts/all"
    "$script_dir/hosts/all/setup.sh"
    cd "$current_dir"
  fi

  for host in $(hostname -A|tr ' ' '\n'|sort -u); do
    if [ -x "$script_dir/hosts/$host/setup.sh" ]; then
      cd "$script_dir/hosts/$host"
      "$script_dir/hosts/$host/setup.sh"
      cd "$current_dir"
    fi
  done
  
  echo 'exit 0' >> /etc/rc.local
}

do_setup_printing() {
  msg "Setting up printing"
  
  apt_install \
    cups \
    cups-browsed \
    system-config-printer system-config-printer-udev cups-pk-helper \
    printer-driver-hpcups printer-driver-hpijs printer-driver-splix hplip hpijs-ppds printer-driver-postscript-hp \
    ipp-usb \

  sed -i 's/^# CreateIPPPrinterQueues All/CreateIPPPrinterQueues All/g' /etc/cups/cups-browsed.conf

  usermod -a -G lpadmin user
  systemctl restart cups-browsed
}

current_dir="$(pwd)"
script_name=$(basename "$0")
script_dir=$(readlink -f "$(dirname "$0")")
script_path="$script_dir/$script_name"

NO_UPDATE=${NO_UPDATE:-}
ARCH=${ARCH:-$(dpkg-architecture -q DEB_HOST_ARCH)}

chroot=0
if [ ! -f /proc/uptime ]; then
  # guessing that we are running from chroot started by setup-image.sh
  chroot=1
fi

if [ $chroot -eq 1 ]; then
  chroot_mounts
elif [ ! "$NO_UPDATE" ]; then
  do_self_update
fi

if do_maybe_apt_update; then
  apt-get -y upgrade
fi
do_system_base
do_packages_base
do_packages_desktop
do_improve_life

if [ $chroot -eq 0 ]; then
  do_enlarge_partition
  # install more packages once we are running from the actual computer
  do_setup_printing
  do_packages_extra
  do_packages_makerspace
  # TODO
  # do_setup_kicad
fi

