#!/bin/sh -e

. "$(dirname "$0")/../../_lib"

(
    msg "Setting up PCB mill"
    cd /home/user

    if [ -d "pcb-mill" ]; then
        dbg "Updating PCB mill from git"
        sudo -u user git pull
    else
        dbg "Cloning PCB mill from git"
        sudo -u user git clone https://github.com/makerspacelt/pcb-mill.git pcb-mill
    fi

    cd pcb-mill/workstation
    docker-compose up -d
)
