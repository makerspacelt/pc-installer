#!/bin/sh -e

if [ -d "user-home-dir" ]; then
    rsync -a --chown user:user "user-home-dir/" /home/user/
fi
