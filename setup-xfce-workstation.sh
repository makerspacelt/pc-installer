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
    msg "Self update successful from $REPO_URL branch $branch. Restarting."
    rm -fr "$script_dir"
    mv "${script_dir}-new" "$script_dir"
    cd "$script_dir"
    if [ "$branch" != "master" ]; then
      echo "$branch" > "$script_dir/branch"
    fi
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
  else
    dbg "Skipping apt update. Delete this file to force: /var/lib/apt/periodic/update-success-stamp"
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
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-backports main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
EOF


  cat <<EOF > /etc/apt/preferences.d/pin-backports
Package: *
Pin: release a=bookmworm-backports
Pin-Priority: 900
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

    echo kernel.dmesg_restrict=0 > /etc/sysctl.d/99-dmesg-for-all.conf
}

do_enlarge_partition() {
  msg "Growing partition"
  (
    eval "$(lsblk -n --include="$(stat --format=%Hd /)" --output NAME,PKNAME -P|grep -v 'PKNAME=""')"
    if [ "$PKNAME" ] && [ "$NAME" ]; then
      if growpart "/dev/$PKNAME" 1; then
        resize2fs "/dev/$NAME"
      fi
    else
      err "Cannot grow partition: root device was not identified"
    fi
  )
}

do_packages_base_system() {
  #
  # Install packages for minimal base image with network & desktop.
  # These packages are part of the initial image.
  #
  msg "Installing base system packages"

  # Make sure there are no broken packages
  apt-get -y -f install
  dpkg --configure -a

  if do_maybe_apt_update; then
    apt-get -y upgrade
  fi

  apt_install \
    `# debian specific` \
    dpkg-dev \
    `# boot & kernel & firmwares` \
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
    "linux-headers-$ARCH" \
    "linux-image-$ARCH" \
    memtest86+ \
    syslinux-common \
    `# cli: media` \
    bluetooth \
    pulseaudio-module-bluetooth \
    `# cli: network` \
    cifs-utils \
    curl \
    ethtool \
    fping \
    iproute2 \
    iw \
    ncat \
    nmap \
    openssh-client \
    openssh-server \
    rsync \
    tcpdump \
    wireless-regdb \
    wpasupplicant \
    `# cli: other` \
    bash-completion \
    cloud-guest-utils \
    dos2unix \
    dosfstools \
    eject \
    file \
    git \
    gvfs \
    htop \
    imagemagick \
    iotop-c \
    jq \
    lm-sensors \
    locales \
    make \
    mc \
    moreutils \
    ntfs-3g \
    pciutils \
    powertop \
    pv \
    python-is-python3 \
    screen \
    systemd-timesyncd \
    sudo \
    tmux \
    usbtop \
    usbutils \
    vim \
    `# gui: fonts` \
    fonts-cantarell \
    fonts-dejavu \
    fonts-font-awesome \
    fonts-freefont-ttf \
    fonts-hack \
    fonts-karla \
    fonts-liberation2 \
    fonts-noto \
    fonts-terminus \
    fonts-ubuntu \
    `# gui: network` \
    network-manager-gnome \
    `# gui: utilities` \
    vim-gtk3 \
    `# gui: desktop environment` \
    i3-wm \
    task-xfce-desktop \
    thunar-archive-plugin \
    thunar-gtkhash \
    thunar-volman \
    xarchiver \
    xfce4-terminal \
    xserver-xorg-video-all \
    xserver-xorg-video-intel \

}

do_packages_extra() {
  #
  # Install packages for full system with all extras.
  # These packages are installed after first boot.
  #
  msg "Installing extra packages (this will take a while...)"

  echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
  
  apt_install \
    `# debian specific` \
    debconf-utils \
    build-essential \
    `# cli: other` \
    docker-compose \
    docker.io \
    ffmpeg \
    gnuplot \
    iptraf-ng \
    mosquitto-clients \
    net-tools \
    qrencode \
    v4l-utils \
    `# cli: hw hack` \
    arduino \
    avrdude \
    binwalk \
    flashrom \
    i2c-tools \
    picocom \
    sigrok \
    sigrok-firmware-fx2lafw \
    spi-tools \
    stlink-tools \
    `# gui: other` \
    chromium webext-ublock-origin-chromium \
    evince \
    geeqie \
    gimp \
    inkscape \
    i965-va-driver-shaders \
    intel-media-va-driver-non-free \
    libreoffice \
    obs-studio \
    pavucontrol \
    pulseaudio \
    pulseview \
    ttf-mscorefonts-installer \
    va-driver-all vainfo \
    vdpau-driver-all vdpauinfo \
    vlc \
    wireshark \
    x11vnc \
    xfce4-power-manager \
    `# printing` \
    cups \
    cups-browsed \
    cups-pk-helper \
    hplip \
    hpijs-ppds \
    ipp-usb \
    printer-driver-hpcups \
    printer-driver-hpijs \
    printer-driver-postscript-hp \
    printer-driver-splix \
    system-config-printer \
    system-config-printer-udev \
    `# makerspace: sdr` \
    gqrx-sdr \
    gnuradio \
    rtl-sdr \
    rtl-433 \
    `# makerspace` \
    cura \
    kicad kicad-libraries kicad-packages3d \
    
    usermod -a -G bluetooth user
    usermod -a -G docker user

    # TODO appImage mqtt-explorer
    
    # TODO kicad
    #  ( \
    #    cd $SYSTEM_USER_HOME/.local/share/kicad/6.0/scripting/plugins/ \
    #    && _clone https://github.com/gregdavill/KiBuzzard.git \
    #    && _clone https://github.com/openscopeproject/InteractiveHtmlBom.git \
    #    && _clone https://github.com/jsreynaud/kicad-action-scripts.git \
    #    && _clone https://github.com/MitjaNemec/ReplicateLayout.git \
    #    && _clone https://github.com/OneKiwiTech/kicad-length-matching.git \
    #    && _clone https://github.com/bennymeg/JLC-Plugin-for-KiCad.git \
    #  ) 
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
  mkdir -p /etc/systemd/system/NetworkManager-wait-online.service.d
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
  # makerspace.lt_5g
  sed 's/makerspace.lt/makerspace.lt_5g/g' \
    < /etc/NetworkManager/system-connections/makerspace.lt.nmconnection \
    > /etc/NetworkManager/system-connections/makerspace.lt_5g.nmconnection

  chmod 600 /etc/NetworkManager/system-connections/makerspace.lt*.nmconnection

  # Add auto update
  touch /etc/rc.local
  chmod +x /etc/rc.local
  if ! grep -qF '#!/bin/sh' /etc/rc.local; then
    echo '#!/bin/sh' > /etc/rc.local
  fi

  sed -i '/setup-xfce-workstation/d; /^exit 0/d' /etc/rc.local
  cmd_setup='nm-online -q -t 600; ( /root/setup/setup-xfce-workstation.sh | logger --skip-empty --stderr --tag pc-installer-setup ) &'
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

do_system_base
do_packages_base_system
do_improve_life

if [ $chroot -eq 0 ]; then
  do_enlarge_partition
  # install more packages once we are running from the actual computer
  do_packages_extra
  do_setup_printing
fi

