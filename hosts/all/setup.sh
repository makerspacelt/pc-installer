#!/bin/sh -e

sed -i '/stream-webcam.sh/d; /^exit 0/d' /etc/rc.local
echo "/root/setup/scripts/stream-webcam.sh" >> /etc/rc.local
if [ -d "$script_dir/user-home-dir" ]; then
    rsync -a --chown user:user "$script_dir/user-home-dir/" /home/user/
fi
