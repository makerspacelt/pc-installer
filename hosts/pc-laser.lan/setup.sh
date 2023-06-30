#!/bin/sh -e

if [ -d "user-home-dir" ]; then
    rsync -a --chown user:user "user-home-dir/" /home/user/
    chmod 600 /home/user/.ssh/id_rsa
fi
