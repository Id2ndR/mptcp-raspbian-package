#!/bin/bash -e

echo "Get firmware and linux commits"
commit_firmware=$(wget -q -O- https://github.com/raspberrypi/firmware/releases | grep /raspberrypi/firmware/commit/ | head -n1 | sed -re 's:.*/([^"]+).*:\1:')
commit_linux=$(wget -q -O- https://raw.githubusercontent.com/raspberrypi/firmware/${commit_firmware}/extra/git_hash | sed -re 's:^(.{12}).*:\1:')


echo "Install toolchain"
git clone https://github.com/raspberrypi/tools tools || true
PATH=$PATH:$PWD/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin
CCACHE="$(which ccache 2>/dev/null) "

echo "retriving Linux sources for rasperrypi"
#https://github.com/raspberrypi/linux/commit/${commit_linux}
if [ -d linux ]
then
  cd linux && git checkout master
  git branch -D rpi-linux mptcp rpi-linux-mptcp || true
  git remote remove mptcp || true
else
  git clone https://github.com/raspberrypi/linux && cd linux
fi
git checkout -b rpi-linux ${commit_linux}
linux_verion=$(grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL) =' Makefile | awk '{print $NF}' | paste -sd '.' -)
echo "retriving MPTCP sources"
git remote add mptcp https://github.com/multipath-tcp/mptcp.git && git fetch mptcp
git config --global user.email "example@mail.com"
echo "Merge MPTCP"
git checkout mptcp/mptcp_v0.94
commit_mptcp=$(git log --oneline | grep ${linux_verion%\.*} | head -n1 | cut -d' ' -f1)
git checkout -b mptcp ${commit_mptcp}
git checkout -b rpi-linux-mptcp ${commit_linux}
git merge -X theirs mptcp -m "merge mptcp/mptcp_v0.94"
echo "Fix linux version"
sed -i -re "s:^(SUBLEVEL = ).*:\1${linux_verion##*\.}:" Makefile
git commit Makefile -m "Fix kernel sublevel for rasperrypi"
echo "Create patch file"
commit_merge=$(git show --oneline | head -n1 |  cut -d' ' -f1)
git diff ${commit_linux}..${commit_merge} > ../rpi-mptcp.patch

echo "Generate kernel config for bcm2709"
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- bcm2709_defconfig
echo "Enable MPTCP in kernel"
patch < ../config-enable-mptcp.patch
echo "Building kernel"
make -j6 ARCH=arm CROSS_COMPILE="${CCACHE}arm-linux-gnueabihf-" zImage modules dtbs
