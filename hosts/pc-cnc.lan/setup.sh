#!/bin/sh -e

. "$(dirname "$0")/../../_lib"

(
    msg "Setting up PCB mill"
    cd /home/user

    if [ -d "pcb-mill" ]; then
        dbg "Updating PCB mill from git"
        cd pcb-mill
        sudo -u user git pull origin master
        cd workstation
    else
        dbg "Cloning PCB mill from git"
        sudo -u user git clone https://github.com/makerspacelt/pcb-mill.git pcb-mill
        cd pcb-mill/workstation
    fi

    DISPLAY=:0 sudo -u user docker-compose up -d
)
