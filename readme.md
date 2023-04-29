# Script 1: setup-image.sh

Prepares a disk image for Linux workstation install.

## Requirements

* Debian/Ubuntu host OS

* Required packages on host system:
  ```sh
  sudo apt install extlinux mmdebstrap qemu-utils fdisk
  ```

## Usage

Build a Linux workstation disk image:
```sh
sudo ./setup-image.sh linux-desktop.img
```

You can test the new image using qemu:
```sh
sudo apt install qemu-system-gui
sudo qemu-system-x86_64 -m 1G -net user linux-desktop.img
``` 

Then write the prepared disk image to a real disk:

```sh
sudo dd status=progress bs=16K if=linux-desktop.img of=/dev/XXX
```
Make sure to use the correct target device name instead of /dev/XXX below.
This was tested with an SSD disk connected using a USB-SATA adapter.

Afterwards connect the newly flashed SSD disk to your new computer and Linux
desktop should boot up.

# Script 2: setup-xfce-workstation.sh

After the image boots, it will start installing extra packages. Internet access
will be needed.

On each boot, the /root/setup/setup-xfce-workstation.sh script is run via
/etc/rc.local. This script is self updating from git. You can change the branch
from which it updates by creating a /root/setup/branch file with the branch
name. Default is no file and the `master` branch.

Additionally this script executes:
* `hosts/all/setup.sh` with current dir set to `hosts/all`
* `hosts/<hostname>/setup.sh` with current dir set to `hosts/<hostname>`
  (`<hostname>` is the fully qualified hostname from DHCP, e.g. pc1.lan)....

Note that these autoupdate and autosetup mechanisms are not designed to be secure.
