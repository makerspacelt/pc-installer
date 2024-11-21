#!/bin/sh -e

sed -i '/stream-webcam.sh/d; /^exit 0/d' /etc/rc.local
echo "/root/setup/hosts/all/scripts/stream-webcam.sh" >> /etc/rc.local
if [ -d "user-home-dir" ]; then
    rsync -a --chown user:user "user-home-dir/" /home/user/
fi
if [ -d /etc/chromium ]; then
    cp -r chromium-settings/* /etc/chromium/
    echo 'export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --homepage file:///etc/chromium/homepage.html"' > /etc/chromium.d/homepage
fi
