#!/bin/sh -e

# Allow tcp connection to the X server.
# Access is restricted by xhost (e.g. /etc/X11/Xsession.d/35x11-common_xhost-local)
sed -i 's/^#xserver-allow-tcp=false.*/xserver-allow-tcp=true/' /etc/lightdm/lightdm.conf

if [ -d "user-home-dir" ]; then
    rsync -a --chown user:user "user-home-dir/" /home/user/
    chmod 600 /home/user/.ssh/id_rsa
fi
