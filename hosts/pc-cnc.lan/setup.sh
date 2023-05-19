#!/bin/sh -e

(
    echo "Setting up PCB mill"
    cd /home/user

    if [ -d "pcb-mill" ]; then
        msg "Updating PCB mill from git"
        sudo -u user git pull
    else
        msg "Cloning PCB mill from git"
        sudo -u user git clone https://github.com/makerspacelt/pcb-mill.git pcb-mill
    fi

    cd pcb-mill/workstation
    docker-compose up -d
)
