#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u
OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
echo $FINDER_APP_DIR
export ARCH=arm64
export CROSS_COMPILE=aarch64-none-linux-gnu-
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
if [ -z "$SYSROOT" ]; then
	echo "[Error] SYSROOT not set"
	exit 1
fi

echo "[Info] STARTING ..."

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi
echo "[Info] Entering ${OUTDIR}"
mkdir -p "${OUTDIR}"
cd "$OUTDIR"
echo "[Info] Kernel preparation"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "[Info] CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
cd linux-stable
if [ $? -ne 0 ]; then
    	echo "[Error] while cd linux-stable"
	exit 1
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    	echo "[Info] Checking out version ${KERNEL_VERSION}"
    	git checkout ${KERNEL_VERSION}

    	make mrproper
    	make defconfig
    	make -j2 all
    	make -j2 modules
    	make -j2 dtbs
fi

echo "[Info] Adding the Image to ${OUTDIR}"
cp arch/${ARCH}/boot/Image  "${OUTDIR}"
echo "[Info] Adding dtb file to ${OUTDIR}"

echo "[Info] Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "[Info] Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
        sudo rm -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
echo "[INFO] Creation of necessary base directories"
mkdir -p "${OUTDIR}/rootfs"
cd "${OUTDIR}/rootfs"
mkdir bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir usr/bin usr/lib usr/sbin
mkdir -p var/log
# TODO copy kernel modules
cd "$OUTDIR"
cd linux-stable
echo "[Info] Adding kernel modules to ${OUTDIR}"
echo "[Info] Busybox preparation"
cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]; then
    	git clone git://busybox.net/busybox.git
        if [ $? -ne 0 ]; then
            	echo "[Error] while git clone busybox"
            	exit 1
        fi
	cd busybox
	if [ $? -ne 0 ]; then
		echo "[Error] while cd busybox"
	        exit 1
	fi
    	git checkout ${BUSYBOX_VERSION}
else
    	cd busybox
	if [ $? -ne 0 ]; then
	        echo "[Error] while cd busybox"
	        exit 1
	fi
fi
if [ ! -f busybox ]; then
	# TODO:  Configure busybox
	echo "[Info] Configure busybox"
	make distclean
	if [ $? -ne 0 ]; then
	    	echo "[Error] while make distclean"
	    	exit 1
	fi
	make defconfig
	if [ $? -ne 0 ]; then
	    	echo "[Error] while make defconfig"
	    	exit 1
	fi
	# TODO: Make and install busybox
	echo "[Info] make busybox"
	make
	if [ $? -ne 0 ]; then
	    	echo "[Error] while make busybox"
	    	exit 1
	fi
fi
echo "[Info] install busybox"
make CONFIG_PREFIX="${OUTDIR}/rootfs" install
echo "[Info] Library dependencies"
${CROSS_COMPILE}readelf -a "${OUTDIR}/rootfs/bin/busybox" | grep "program interpreter"
${CROSS_COMPILE}readelf -a "${OUTDIR}/rootfs/bin/busybox" | grep "Shared library"
# TODO: Add library dependencies to rootfs
cd "${OUTDIR}/rootfs"
echo "[Info]     program interpreter"
#ld-linux.so.3
DEP1=$(${CROSS_COMPILE}readelf -a "${OUTDIR}/rootfs/bin/busybox" | grep "program interpreter" | sed  's/\( *\)\(\[\).*\/\(.*\)\(\]\)/\3/')
if [ ! -z "$DEP1" ]; then
	echo "[Info] copy program interpreter 1"
	cp -a $SYSROOT/lib/$DEP1 lib
	if [ $? -ne 0 ]; then
	    	echo "[Error] while cp $DEP1" 
	    	exit 1
	fi
        k=$(ls -l $SYSROOT/lib/$DEP1 |sed 's/\(.*\)\(>\)\(.*\)/\3/')
	kk=$(echo $k |sed 's/\(.*\)\(\/\)\(.*\)/\3/')
	echo "[Info] copy program interpreter 2"
	cp -a $SYSROOT/lib64/$kk lib64
	if [ $? -ne 0 ]; then
	    	echo "[Error] while cp $k" 
	    	exit 1
	fi
else
	echo "[Warning] No dependences in program interpreter found"
fi

echo "[Info] Shared libraries"
#libm.so.6
#libresolv.so.2
#libc.so.6
DEP2=$(${CROSS_COMPILE}readelf -a "${OUTDIR}/rootfs/bin/busybox" | grep "Shared library" | sed  's/\(.*\)\(\[\)\(.*\)\(\]\)/\3/') 
if [ ! -z "$DEP2" ]; then
	for i in $DEP2 ; do
		echo "[Info] copy shared library link"
		cp -a $SYSROOT/lib64/$i lib64
		if [ $? -ne 0 ]; then
		    	echo "[Error] while cp $i" 
		    	exit 1
		fi
		echo "[Info] copy shared library"
	        k=$(ls -l $SYSROOT/lib64/$i |sed 's/\(.*\)\(>\) \(.*\)/\3/')
		cp -a $SYSROOT/lib64/$k lib64
		if [ $? -ne 0 ]; then
		    	echo "[Error] while cp $k" 
		    	exit 1
		fi
	done
else
	echo "[Warning] No dependences in shared libraries found"
fi

# TODO: Make device nodes
sudo mknod -m 666 dev/null c 1 3
if [ $? -ne 0 ]; then
        echo "[Error] while mknod /dev/null"
        exit 1
fi
sudo mknod -m 600 dev/console c 5 1
if [ $? -ne 0 ]; then
        echo "[Error] while mknod dev/console"
        exit 1
fi
# TODO: Clean and build the writer utility  # TODO
echo "[Info] copy writer utility" 
cd ${FINDER_APP_DIR}
if [ $? -ne 0 ]; then
    	echo "[Error] while cd ${FINDER_APP_DIR}"
    	exit 1
fi
echo "[Info] make clean writer utility" 
make clean
if [ $? -ne 0 ]; then
    	echo "[Error] while make clean writer utility"
    	exit 1
fi
echo "[Info] make writer utility" 
make
if [ $? -ne 0 ]; then
    	echo "[Error] while make writer utility"
    	exit 1
fi

echo "[Info] Copy the finder related scripts and executables to the /home directory"
cd "${OUTDIR}/rootfs"
if [ $? -ne 0 ]; then
    	echo "[Error] while cd ${OUTDIR}/rootfs"
    	exit 1
fi
cp ${FINDER_APP_DIR}/writer home
if [ $? -ne 0 ]; then
    	echo "[Error] while cp writer to the /home directory"
    	exit 1
fi
mkdir "home/conf"
if [ $? -ne 0 ]; then
    	echo "[Error] while mkdir homne/conf"
    	exit 1
fi
cp ${FINDER_APP_DIR}/finder.sh home
if [ $? -ne 0 ]; then
    	echo "[Error] while cp finder.sh to the /home directory"
    	exit 1
fi
cp ${FINDER_APP_DIR}/conf/username.txt home/conf
if [ $? -ne 0 ]; then
    	echo "[Error] while cp username.txt to the /home/conf directory"
    	exit 1
fi
cp ${FINDER_APP_DIR}/conf/assignment.txt home/conf
if [ $? -ne 0 ]; then
    	echo "[Error] while cp assignment.txt to the /home/conf directory"
    	exit 1
fi

echo "[Info] Modify the finder-test.sh"
sed 's/\.\.\///' ${FINDER_APP_DIR}/finder-test.sh > home/finder-test.sh
if [ $? -ne 0 ]; then
    	echo "[Error] while sed finder-test.sh"
    	exit 1
fi
chmod +x home/finder-test.sh

cp ${FINDER_APP_DIR}/autorun-qemu.sh home
if [ $? -ne 0 ]; then
    	echo "[Error] while cp autorun-qemu.sh to the /home directory"
    	exit 1
fi

# TODO: Chown the root directory
echo "[Info] Chown the root directory ... skipped" 

# TODO: Create initramfs.cpio.gz
echo "[Info] initramfs.cpio.gz creation" 
cd "${OUTDIR}/rootfs"
if [ $? -ne 0 ]; then
        echo "[Error] while cd ${OUTDIR}/rootfs"
        exit 1
fi
find . | cpio -H newc -ov --owner root:root > ../initramfs.cpio
if [ $? -ne 0 ]; then
        echo "[Error] while find"
        exit 1
fi
cd ..
if [ $? -ne 0 ]; then
        echo "[Error] while cd .."
        exit 1
fi
rm -rf initramfs.cpio.gz
gzip initramfs.cpio
if [ $? -ne 0 ]; then
        echo "error while gzip initramfs"
        exit 1
fi
echo "[Info] ALL DONE" 
