#!/bin/sh -e

sed -i '/stream-webcam.sh/d; /^exit 0/d' /etc/rc.local
echo "/root/setup/hosts/all/scripts/stream-webcam.sh" >> /etc/rc.local
if [ -d "user-home-dir" ]; then
    rsync -a --chown user:user "user-home-dir/" /home/user/
fi
