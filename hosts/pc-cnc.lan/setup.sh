#!/bin/sh -e

msg() { printf '\e[37m\e[32m%s\e[m\n' "$*"; }

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
