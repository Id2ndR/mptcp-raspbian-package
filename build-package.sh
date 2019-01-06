#!/bin/bash -e

echo "Get package orig"
firmware_version=$(wget -q -O- https://github.com/raspberrypi/firmware/releases | grep '/raspberrypi/firmware/archive/.' | head -n1 | sed -re 's:.*/(.+)(\.zip|\.tar\.gz).*:\1:')

[ -e raspberrypi-firmware_${firmware_version}.orig.tar.gz ] || wget -nv https://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-firmware/raspberrypi-firmware_${firmware_version}.orig.tar.gz
[ -e raspberrypi-firmware_${firmware_version}-1.debian.tar.xz ] || wget -nv https://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-firmware/raspberrypi-firmware_${firmware_version}-1.debian.tar.xz

KERNEL=kernel7

echo "Install kernel to temporary directory"
mkdir -p raspberrypi-firmware-${firmware_version}-mptcp/boot/overlays/
cd linux
make ARCH=arm INSTALL_MOD_PATH=../raspberrypi-firmware-${firmware_version}-mptcp modules_install
cp arch/arm/boot/zImage ../raspberrypi-firmware-${firmware_version}-mptcp/boot/$KERNEL.img
cp arch/arm/boot/dts/*.dtb ../raspberrypi-firmware-${firmware_version}-mptcp/boot/
cp arch/arm/boot/dts/overlays/{*.dtb*,README} ../raspberrypi-firmware-${firmware_version}-mptcp/boot/overlays/
cd ..
echo "Extracting raspberrypi-firmware archive"
rm -rf raspberrypi-firmware-${firmware_version}/
tar xf raspberrypi-firmware_${firmware_version}.orig.tar.gz
echo "Add custom kernel $KERNEL"
rsync -a --del raspberrypi-firmware-${firmware_version}-mptcp/lib/modules/* raspberrypi-firmware-${firmware_version}/modules/
rsync -a --existing raspberrypi-firmware-${firmware_version}-mptcp/boot/ raspberrypi-firmware-${firmware_version}/boot/

echo "Extracting Debian packaging files"
cd raspberrypi-firmware-${firmware_version}/
tar xf ../raspberrypi-firmware_${firmware_version}-1.debian.tar.xz
echo "Modify Debian changelog"
package_version=$(sed -n -re "1s:(-.+)\):\1.mptcp):" -e 1p debian/changelog)
package_content=$(sed -n 3p debian/changelog)
CHANGELOG="${package_version}

${package_content}
  * Add MPTCP in Kernel

 -- Id2ndR <none>  $(date -Ru)
 "
CHANGELOG_VAR=$(echo "$CHANGELOG" | sed ':a;N;$!ba;s/\n/\\n/g') # https://stackoverflow.com/a/1252191/8159285
sed -i "1i${CHANGELOG_VAR}" debian/changelog
## Building source package can be done only after recreating orig file
#dpkg-buildpackage -aarmhf -us -uc
echo "Build binary deb package"
dpkg-buildpackage -a armhf -b
