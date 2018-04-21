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
readonly remastered_file="$(dirname "$cz_path")/$prefix-$cz_file"

if [[ $(whoami) != "root" ]]; then
    echo "This program should be run as root!"
    exit 1
fi

unzip -q "$cz_path" -d "$tmp_dir"

pushd "$tmp_dir/live"
unsquashfs filesystem.squashfs
mount --bind /dev/ "$tmp_dir/live/squashfs-root/dev"
chroot "$tmp_dir/live/squashfs-root" /bin/bash <<'EOF'
LC_ALL=C
HOME=/root
# assume that there is only one kernel installed
kernel_path="$(find /lib/modules -mindepth 1 -maxdepth 1 -type d | head -1)"
kernel_version="$(basename "$kernel_path")"

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts

mkdir /boot

mv /etc/resolv.conf /etc/resolv.conf.bak
echo 'nameserver 8.8.8.8' > /etc/resolv.conf

apt-get -qqy update
apt-get -qqy install git dkms linux-headers-"$kernel_version"
update-initramfs -k all -c

echo -e "\n# macbook12-spi-drivers\napplespi\nappletb\nspi_pxa2xx_platform\nintel_lpss_pci" >> /etc/initramfs-tools/modules
git clone https://github.com/roadrunner2/macbook12-spi-driver.git
cd ./macbook12-spi-driver
git checkout touchbar-driver-hid-driver
dkms add .
dkms install -m applespi -v 0.1 -k "$kernel_version"

mv /etc/resolv.conf.bak /etc/resolv.conf
umount /dev/pts
umount /sys
umount /proc
EOF
sudo umount "$tmp_dir/live/squashfs-root/dev"
sudo find ./squashfs-root/boot -type f ! -name '*.old-dkms' | xargs -n 1 -I {} cp {} initrd.img
rm -rf ./squashfs-root/boot

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
