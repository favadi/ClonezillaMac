#!/bin/bash

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <Clonezilla .zip file>"
}

if [ "$#" != "1" ]; then
    usage
    exit 1
fi

readonly prefix="CZMac"
readonly cz_path="$1"
readonly cz_file="$(basename "$cz_path")"
readonly tmp_dir="$(mktemp -d)"
readonly remastered_file="$prefix-$cz_file"

if [[ $(whoami) != "root" ]]; then
    echo "This program should be run as root!"
    exit 1
fi

unzip -q "$cz_path" -d "$tmp_dir"

pushd "$tmp_dir/live"
unsquashfs filesystem.squashfs
mount --bind /dev/ "$tmp_dir/live/squashfs-root/dev"
chroot "$tmp_dir/live/squashfs-root" /bin/bash <<EOF
LC_ALL=C
HOME=/root

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts

mv /etc/resolv.conf /etc/resolv.conf.bak
echo 'nameserver 8.8.8.8' > /etc/resolv.conf

apt-get -qqy update
apt-get -qqy dist-upgrade
apt-get -qqy autoremove
apt-get -qqy install git dkms
apt-get -qqy install linux-headers-$(uname -r)

echo -e "\n# macbook12-spi-drivers\napplespi\nappletb\nspi_pxa2xx_platform\nintel_lpss_pci" >> /etc/initramfs-tools/modules
git clone https://github.com/roadrunner2/macbook12-spi-driver.git
cd ./macbook12-spi-driver
git checkout touchbar-driver-hid-driver
dkms add .
dkms install -m applespi -v 0.1

mv /etc/resolv.conf.bak /etc/resolv.conf
umount /dev/pts
umount /sys
umount /proc
EOF
sudo umount "$tmp_dir/live/squashfs-root/dev"

blocksize=$(unsquashfs -s filesystem.squashfs | grep "Block size" | awk '{print $3}')
rm -f filesystem.squashfs
if [[ -n "$blocksize" ]]; then
    mksquashfs squashfs-root filesystem.squashfs -b "$blocksize"
else
    mksquashfs squashfs-root filesystem.squashfs
fi
rm -rf squashfs-root
popd

pushd "$tmp_dir"
zip -qr "$remastered_file" .
popd
rm -rf "$tmp_dir"
