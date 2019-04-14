#!/bin/bash

basedir=$(pwd)
KERNEL_VER=$(cat $basedir/kernel-version)
rm -rf intel vyos-intel-driver

mkdir intel
pkgdir="$basedir/intel"
mkdir intel

URLS=" \
    https://downloadmirror.intel.com/14687/eng/ixgbe-5.5.5.tar.gz \
    https://downloadmirror.intel.com/13663/eng/igb-5.3.5.22.tar.gz \
    https://downloadmirror.intel.com/15817/eng/e1000e-3.4.2.1.tar.gz \
    https://downloadmirror.intel.com/24411/eng/i40e-2.7.29.tar.gz \
    https://downloadmirror.intel.com/28725/eng/ixgbevf-4.5.2.tar.gz \
    https://downloadmirror.intel.com/24693/eng/i40evf-3.6.15.tar.gz \
"

# The intel IGBVF driver can't be compiled with recent Kernel versions
# due to interlanl API changes. Driver is from 10.09.2015
# Source code is here: https://downloadmirror.intel.com/18298/eng/igbvf-2.3.9.6.tar.gz

for URL in $URLS
do
     cd $pkgdir
     wget ${URL}
     ret=$?
     if [ "$ret" != "0" ]; then
         echo "Download of ${URL} failed!"
         exit $ret
     fi

     filename=${URL##*/}
     dirname_full=$(echo $filename | awk -F".tar.gz" '{print $1}')
     dirname=$(echo $dirname_full | awk -F- '{print $1}')
     version="$(echo $dirname_full | awk -F- '{print $2}')-0"
     deb_pkg=${dirname}_${version}_amd64
     deb_pkg_dir=$basedir/vyos-intel-${deb_pkg}

     tar xf $filename
     cd $dirname_full/src

     KSRC=$basedir/vyos-kernel INSTALL_MOD_PATH=$deb_pkg_dir \
         make -j $(cat /proc/cpuinfo | grep processor | wc -l) install

     mkdir -p $deb_pkg_dir/DEBIAN
     echo "Package: vyos-intel-$dirname" >$deb_pkg_dir/DEBIAN/control
     echo "Version: $version" >>$deb_pkg_dir/DEBIAN/control
     echo "Section: kernel" >>$deb_pkg_dir/DEBIAN/control
     echo "Priority: extra" >>$deb_pkg_dir/DEBIAN/control
     echo "Architecture: amd64" >>$deb_pkg_dir/DEBIAN/control
     echo "Maintainer: VyOS Package Maintainers <maintainers@vyos.net>" >>$deb_pkg_dir/DEBIAN/control
     echo "Installed-Size: 9" >>$deb_pkg_dir/DEBIAN/control
     echo "Depends: linux-image" >>$deb_pkg_dir/DEBIAN/control
     echo "Description: Intel Vendor driver for $dirname" >>$deb_pkg_dir/DEBIAN/control
     echo "  Replacement for the in Kernel drivers" >>$deb_pkg_dir/DEBIAN/control

     # Cleanup files which might also be present in linux-image-4.19.20-amd64-vyos
     rm -rf $deb_pkg_dir/usr $deb_pkg_dir/lib/modules/$KERNEL_VER/modules.*

     cd $basedir
     dpkg-deb --build $(basename $deb_pkg_dir)
done
