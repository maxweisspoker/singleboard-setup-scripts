#!/bin/bash -i

# Run with interactive flag so I can source my bashrc and use my exported variables

source ~max/.bashrc

trap ctrl_c INT

# Binaries required on system. Listed as bins rather than packages so it can
# be run cross platform. Should cover literally everything.
# Also make sure the mkfs bins are recent. The semantics of the mkfs format
# changed in some recent version, so before running this script, test the mkfs
# step on your system to make sure it will work correctly.
REQUIRED_BINS="env sh bash dd parted wget mkfs.ext4 mkfs.vfat bsdtar ln rm mkdir chown chmod mount umount sync eject grep awk sed tr lsblk su echo cat sync sleep tar base64"

SCRIPT_SDCARD_PATH="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
SCRIPT_DEVICE="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

SCRIPT_DO_WARNING=1

# DO NOT CHANGE. Used in a STRCMP later.
INPUT_URL="http://x/"

function ctrl_c() {
    echo -e "\n----------------------------------------------------------\n"
    echo -e "Ctrl+C interrupt caught...\n"
    read -p "Type \"c\" to continue or nothing to quit: " CTRL_C_CHECK
    if [[ "$CTRL_C_CHECK" != "c" ]]; then
        echo -e "\nExiting...\n"
        exit 0
    else
        echo -e "\nContinuing execution in 5 seconds...\n"
        sleep 5
    fi
}

usage()
{
    echo ""
    echo "This script must be run with root/admin privileges."
    echo ""
    echo "usage: $0 --sdcard /dev/sdcard_device --device [one of:  pi0,pi2,pi3,pi4,odroid-c2] [OPTIONAL] --no-warning"
    echo ""
    echo "example: \"sudo $0 --sdcard /dev/sdf --device pi4\""
    echo ""
    echo "example: \"sudo $0 --sdcard /dev/sda --device pi0 --no-warning\""
    echo ""
}

while [ "$1" != "" ]; do
    case $1 in
        -s | --sdcard )         shift
                                SCRIPT_SDCARD_PATH=$1
                                ;;
        -d | --device )         shift
                                SCRIPT_DEVICE=$1
                                ;;
        -w | --no-warning )     SCRIPT_DO_WARNING=0
                                ;;
        -u | --url )            shift
                                INPUT_URL=$1
                                ;;
        -h | --help )           usage
                                exit 0
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

case $SCRIPT_DEVICE in
    pi0 ) ;;
    pi2 ) ;;
    pi3 ) ;;
    pi4 ) ;;
    odroid-c2) ;;

    *  )  echo "The destination for --device was not recognized. Aborting..."
          exit 1
esac


echo ""
echo "Step 1: Verifying you are root..."
if [[ $EUID -ne 0 ]]; then
    echo "    ... Failed. You are not root/sudo." 1>&2
    exit 1
else
    echo "    ... Passed!"
fi

echo ""
echo "Step 2: Validating necessary binaries are in \$PATH..."
for bin in $REQUIRED_BINS; do
    which $bin 2>&1 >/dev/null
    if [ $? -ne 0 ]; then
        echo "    ... Failed. The binary \"$bin\" could not be found. Aborting..." 1>&2
        echo "        (You might also see this message if the \"which\" command is not present.)" 1>&2
        exit 1
    fi
done
echo "    ... Passed!"

echo ""
echo "Step 3: Validating sdcard path..."
grep $SCRIPT_SDCARD_PATH <(lsblk -p -o NAME,TYPE | grep disk) 2>&1 >/dev/null
if [ $? -ne 0 ]; then
    echo "    ... Failed. The block device \"$SCRIPT_SDCARD_PATH\" could not be located or is not a disk. Aborting..." 1>&2
    exit 1
fi
echo "    ... Passed!"

if [[ $SCRIPT_DO_WARNING -eq 1 ]]; then
    echo ""
    echo "Step 4: Sanity check..."
    echo -e "\n    ****************************************************************"
    echo "    PLEASE MAKE SURE YOU WISH TO CONTINUE."
    echo "    PLEASE MAKE SURE ANY SDCARD PARTITIONS ARE UNMOUNTED."
    echo "    PLEASE MAKE SURE NO WHITESPACE EXISTS IN THE PATH TO THE CURRENT WORKING DIR."
    echo "    PLEASE MAKE SURE THERE ARE NO FOLDERS CALLED root OR boot IN THE CURRENT WORKING DIR."
    echo ""
    echo "    THE DEVICE $SCRIPT_SDCARD_PATH WILL BE COMPLETELY WIPED."
    echo -e "    ****************************************************************\n"
    read -p "Type \"THIS_IS_MY_FAULT\" to continue: " SANITY_CHECK
    echo ""
    if [[ "$SANITY_CHECK" != "THIS_IS_MY_FAULT" ]]; then
        echo "... Sanity check failed. Aborting..." 1>&2
        exit 1
    else
        echo "... Sanity check passed!"
        echo ""
    fi
else
    echo ""
    echo "Step 4: Sanity check..."
    echo "... Skipped (--no-warning)"
fi

echo ""
echo "Step 5: Zeroing out beginning of sdcard with dd..."
dd if=/dev/zero of=$SCRIPT_SDCARD_PATH bs=1M count=8  2>&1 >/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: dd run returned non-zero exit status. Aborting..." 1>&2
    exit 1
fi
echo "... Done!"

echo ""
echo "Step 6: Write MSDOS parition table with parted..."
parted $SCRIPT_SDCARD_PATH mklabel msdos  2>&1 >/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: parted returned non-zero exit status. Aborting..." 1>&2
    exit 1
fi
echo "... Done!"

parted_with_boot()
{
    parted -a optimal $SCRIPT_SDCARD_PATH mkpart primary 4096s 100M  2>&1 >/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: parted returned non-zero exit status while creating boot partition. Aborting..." 1>&2
        exit 1
    fi
    sleep 3
    grep "${SCRIPT_SDCARD_PATH}1" <(lsblk -p -o NAME,TYPE | grep part) 2>&1 >/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: Boot partition was successfully created, but the script could not locate it at "${SCRIPT_SDCARD_PATH}1". Aborting..." 1>&2
        exit 1
    fi
    export NUMSECTORS=$(parted $SCRIPT_SDCARD_PATH 'unit s print' | grep "^[[:space:]]1[[:space:]]" | awk '{print $3}' | tr -d '\n' | sed 's/s//g')
    export NEWLOC=$(expr 1 + $NUMSECTORS | tr -d '\n')
    parted -a optimal $SCRIPT_SDCARD_PATH mkpart primary ${NEWLOC}s 100%  2>&1 >/dev/null
    if [ $? -ne 0 ]; then
        unset NEWLOC
        unset NUMSECTORS
        echo "ERROR: parted returned non-zero exit status while creating root partition. Aborting..." 1>&2
        exit 1
    fi
    unset NEWLOC
    unset NUMSECTORS
    sleep 3
    grep "${SCRIPT_SDCARD_PATH}2" <(lsblk -p -o NAME,TYPE | grep part) 2>&1 >/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: Root partition was successfully created, but the script could not locate it at "${SCRIPT_SDCARD_PATH}2". Aborting..." 1>&2
        exit 1
    fi
}

parted_no_boot()
{
    parted -a optimal $SCRIPT_SDCARD_PATH mkpart primary 4096s 100%  2>&1 >/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: parted returned non-zero exit status while creating the new partition. Aborting..." 1>&2
        exit 1
    fi
    sleep 3
    grep "${SCRIPT_SDCARD_PATH}1" <(lsblk -p -o NAME,TYPE | grep part) 2>&1 >/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: New partition was successfully created, but the script could not locate it at "${SCRIPT_SDCARD_PATH}1". Aborting..." 1>&2
        exit 1
    fi
}

echo ""
echo "Step 7: Creating new paritions with parted..."
case $SCRIPT_DEVICE in
    pi0 )      parted_with_boot
               ;;
    pi2 )      parted_with_boot
               ;;
    pi3 )      parted_with_boot
               ;;
    pi4 )      parted_with_boot
               ;;
    odroid-c2) parted_no_boot
               ;;

    *  )  echo "An unknown error has occured. Bailing out..." 1>&2
          exit 1
esac
echo "... Done!"

mkfs_pis()
{
    mkfs.vfat "${SCRIPT_SDCARD_PATH}1"
    if [ $? -ne 0 ]; then
        echo "ERROR: mkfs.vfat returned non-zero exit status. Aborting..." 1>&2
        exit 1
    fi
    sleep 1
    mkfs.ext4 -F "${SCRIPT_SDCARD_PATH}2"
    if [ $? -ne 0 ]; then
        echo "ERROR: mkfs.ext4 returned non-zero exit status. Aborting..." 1>&2
        exit 1
    fi
}

mkfs_ordroid()
{
    mkfs.ext4 -O ^metadata_csum,^64bit "${SCRIPT_SDCARD_PATH}1"
    if [ $? -ne 0 ]; then
        echo "ERROR: mkfs.ext4 returned non-zero exit status. Aborting..." 1>&2
        exit 1
    fi
}


echo ""
echo "Step 8: Creating new file systems with mkfs..."
case $SCRIPT_DEVICE in
    pi0 )      mkfs_pis
               ;;
    pi2 )      mkfs_pis
               ;;
    pi3 )      mkfs_pis
               ;;
    pi4 )      mkfs_pis
               ;;
    odroid-c2) mkfs_ordroid
               ;;

    *  )  echo "An unknown error has occured. Bailing out..." 1>&2
          exit 1
esac
echo "... Done!"

echo ""
echo "Step 9: Downloading Arch Linux ARM image. This may take a while..."
echo ""

# Yes Pi3 is supposed to use the Pi2 image
case $SCRIPT_DEVICE in
    pi0 )      IMAGE_FILE_NAME="ArchLinuxARM-rpi-latest.tar.gz"
               ;;
    pi2 )      IMAGE_FILE_NAME="ArchLinuxARM-rpi-2-latest.tar.gz"
               ;;
    pi3 )      IMAGE_FILE_NAME="ArchLinuxARM-rpi-2-latest.tar.gz"
               ;;
    pi4 )      IMAGE_FILE_NAME="ArchLinuxARM-rpi-4-latest.tar.gz"
               ;;
    odroid-c2) IMAGE_FILE_NAME="ArchLinuxARM-odroid-c2-latest.tar.gz"
               ;;

    *  )  echo "An unknown error has occured. Bailing out..." 1>&2
          exit 1
esac

# Arch Linux ARM downloads point to a non-https site, which redirects to an
# https site with an invalid cert. Yes, that's dumb, but it is what it is.
if [[ "$INPUT_URL" == "http://x/" ]]; then
    INPUT_URL="http://os.archlinuxarm.org/os/${IMAGE_FILE_NAME}"
fi

# Since the cert is invalid, wget doesn't validate it. Yes, this can cause
# MITM attacks, which is why there is the unpublished option for a custom
# input URL. That --url option can also be used if you just want to download
# the file once and host it yourself so you don't have to keep re-downloading
# it on every run. e.g. you are creating multiple SD cards.
wget -O "${IMAGE_FILE_NAME}" --no-check-certificate "${INPUT_URL}"
if [ $? -ne 0 ]; then
    rm -f "${IMAGE_FILE_NAME}"
    echo ""
    echo "ERROR: wget returned non-zero exit status. Aborting..." 1>&2
    exit 1
fi
echo ""
echo "... Done!"
echo ""

echo "Step 10: Mounting sdcard in temporary folders and extracting the OS."
echo "         This may also take a while..."

if [ -d "$PWD/root" ]; then
    echo "ERROR: The folder \"root\" already exists. Aborting..." 1>&2
    exit 1
fi
if [ -d "$PWD/boot" ]; then
    echo "ERROR: The folder \"boot\" already exists. Aborting..." 1>&2
    exit 1
fi

mkdir root
mkdir boot
chown root:root root
chown root:root boot
chmod 755 root
chmod 755 boot

case $SCRIPT_DEVICE in
    pi0 )      mount "${SCRIPT_SDCARD_PATH}1" "$PWD/boot"
               ;;
    pi2 )      mount "${SCRIPT_SDCARD_PATH}1" "$PWD/boot"
               ;;
    pi3 )      mount "${SCRIPT_SDCARD_PATH}1" "$PWD/boot"
               ;;
    pi4 )      mount "${SCRIPT_SDCARD_PATH}1" "$PWD/boot"
               ;;
    odroid-c2) echo -n ""
               ;;

    *  )  echo "An unknown error has occured. Bailing out..." 1>&2
          exit 1
esac
if [ $? -ne 0 ]; then
    echo "ERROR: mounting ./boot attempt returned non-zero exit status. Aborting..." 1>&2
    exit 1
fi

case $SCRIPT_DEVICE in
    pi0 )      mount "${SCRIPT_SDCARD_PATH}2" "$PWD/root"
               ;;
    pi2 )      mount "${SCRIPT_SDCARD_PATH}2" "$PWD/root"
               ;;
    pi3 )      mount "${SCRIPT_SDCARD_PATH}2" "$PWD/root"
               ;;
    pi4 )      mount "${SCRIPT_SDCARD_PATH}2" "$PWD/root"
               ;;
    odroid-c2) mount "${SCRIPT_SDCARD_PATH}1" "$PWD/root"
               ;;

    *  )  echo "An unknown error has occured. Bailing out..." 1>&2
          exit 1
esac
if [ $? -ne 0 ]; then
    echo "ERROR: mounting ./root attempt returned non-zero exit status. Aborting..." 1>&2
    exit 1
fi

# bsdtar has issues if you don't use root account, so we specifically use it
su - root -c "bsdtar -xpf $PWD/$IMAGE_FILE_NAME -C $PWD/root"  2>&1 >/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: bsdtar returned non-zero exit status. Aborting..." 1>&2
    exit 1
fi

echo "... Done!"


echo ""
echo "Step 11: Enabling auto-configured wireless networking and dhcp..."

# Yes, Pi2 and Pi3 use the same one, and yes Pi4 uses the Pi0 one.
case $SCRIPT_DEVICE in
    pi0 )      WPA_SUP_FILE="armv6_wpa_supplicant_tar-gz-b64.txt"
               ;;
    pi2 )      WPA_SUP_FILE="armv7_wpa_supplicant_tar-gz-b64.txt"
               ;;
    pi3 )      WPA_SUP_FILE="armv7_wpa_supplicant_tar-gz-b64.txt"
               ;;
    pi4 )      WPA_SUP_FILE="armv6_wpa_supplicant_tar-gz-b64.txt"
               ;;
    odroid-c2) WPA_SUP_FILE="armv8_wpa_supplicant_tar-gz-b64.txt"
               ;;

    *  )  echo "An unknown error has occured. Bailing out..." 1>&2
          exit 1
esac
HAD_WPA_SUP_FILE=1
if [[ ! -f "$WPA_SUP_FILE" ]]; then
    HAD_WPA_SUP_FILE=0
    wget -q -O "$WPA_SUP_FILE" "https://raw.githubusercontent.com/maxweisspoker/singleboard-setup-scripts/ac693cf8f3ff41a35348d5bf30a20c568be1fb67/install_archlinuxarm/${WPA_SUP_FILE}" 2>&1 >/dev/null
    if [ $? -ne 0 ]; then
        rm -f "$WPA_SUP_FILE"
        echo "ERROR: Could not download wpa_supplicant b64 text file. Aborting..." 1>&2
        exit 1
    fi
fi
cat $WPA_SUP_FILE | base64 -d > wpa_supplicant_install.tar.gz
if [ $? -ne 0 ]; then
    echo "ERROR: Could not convert wpa_supplicant b64 to tar.gz. Aborting..." 1>&2
    exit 1
fi
tar -xf wpa_supplicant_install.tar.gz
if [ $? -ne 0 ]; then
    echo "ERROR: Could not extract wpa_supplicant tar.gz. Aborting..." 1>&2
    exit 1
fi
rm -f wpa_supplicant_install.tar.gz
cat << EOF >> wpa_supplicant_archlinuxarm.conf
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant
update_config=1

network={
        ssid="$ANSIBLE_WIFI_NETWORK_SSID"
        psk=$ANSIBLE_WIFI_NETWORK_PSK
        priority=99
}
EOF
mkdir -p "$PWD/root/etc/systemd/system/multi-user.target.wants/"
mkdir -p "$PWD/root/usr/lib/dhcpcd/dhcpcd-hooks/"
mkdir -p "$PWD/root/usr/lib/systemd/system/"
mkdir -p "$PWD/root/etc/wpa_supplicant/"
ln -s /usr/lib/systemd/system/dhcpcd@.service "$PWD/root/etc/systemd/system/multi-user.target.wants/dhcpcd@wlan0.service"
ln -s /usr/share/dhcpcd/hooks/10-wpa_supplicant "$PWD/root/usr/lib/dhcpcd/dhcpcd-hooks/10-wpa_supplicant"
cp -r $PWD/wpa_supplicant_install/* "$PWD/root/"
cp "$PWD/wpa_supplicant_archlinuxarm.conf" "$PWD/root/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"
rm -rf "$PWD/wpa_supplicant_install/"
rm -f "$PWD/wpa_supplicant_archlinuxarm.conf"
fi
echo "... Done!"

echo ""
echo "Step 12: Creating first run boot script to install python for ansible..."
cat << EOF >> "$PWD/root/firstrun.sh"
#!/bin/bash
if [ -f "/firstruncomplete.bin" ]; then
    /bin/true
else 
    touch "/firstruncomplete.bin"
    sleep 40
    systemctl stop systemd-resolved
    systemctl stop systemd-networkd
    systemctl restart systemd-networkd
    sleep 5
    systemctl restart systemd-resolved
    sleep 5
    pacman-key --init
    pacman-key --populate archlinuxarm
    pacman -Syy
    pacman -S --noconfirm python
fi
/bin/true
EOF
chmod +x "$PWD/root/firstrun.sh"
mkdir -p "$PWD/root/etc/systemd/system/multi-user.target.wants/"
mkdir -p "$PWD/root/usr/lib/systemd/system/"
cat << EOF >> "$PWD/root/usr/lib/systemd/system/firstrun.service"
[Unit]
Description=Install python on first boot using simple stupid shell script
Wants=systemd-resolved.service

[Service]
Type=forking
ExecStart=/bin/bash /firstrun.sh
RemainAfterExit=true
TimeoutSec=600

[Install]
WantedBy=multi-user.target

EOF
ln -s /usr/lib/systemd/system/firstrun.service "$PWD/root/etc/systemd/system/multi-user.target.wants/firstrun.service"
echo "... Done!"

odroid_uboot_setup()
{
    cd $PWD/root/boot
    ./sd_fusing.sh $SCRIPT_SDCARD_PATH  2>&1 >/dev/null
    if [ $? -ne 0 ]; then
        cd ../..
        echo "ERROR: sd_fusing.sh returned non-zero exit status. sync command not run. Aborting..." 1>&2
        exit 1
    fi
    cd ../..
}

echo ""
echo "Step 13: Setting up boot files..."
case $SCRIPT_DEVICE in
    pi0 )      mv $PWD/root/boot/* $PWD/boot
               ;;
    pi2 )      mv $PWD/root/boot/* $PWD/boot
               ;;
    pi3 )      mv $PWD/root/boot/* $PWD/boot
               ;;
    pi4 )      mv $PWD/root/boot/* $PWD/boot
               ;;
    odroid-c2) odroid_uboot_setup
               ;;

    *  )  echo "An unknown error has occured. Bailing out..." 1>&2
          exit 1
esac
echo "... Done!"

echo ""
echo "Step 15: Unmounting, syncing, ejecting sdcard, and cleaning up..."
sync
case $SCRIPT_DEVICE in
    pi0 )      umount ${SCRIPT_SDCARD_PATH}2 2>&1 >/dev/null
               ;;
    pi2 )      umount ${SCRIPT_SDCARD_PATH}2 2>&1 >/dev/null
               ;;
    pi3 )      umount ${SCRIPT_SDCARD_PATH}2 2>&1 >/dev/null
               ;;
    pi4 )      umount ${SCRIPT_SDCARD_PATH}2 2>&1 >/dev/null
               ;;
    odroid-c2) echo -n ""
               ;;

    *  )  echo "An unknown error has occured. Bailing out..." 1>&2
          exit 1
esac
umount ${SCRIPT_SDCARD_PATH}1 2>&1 >/dev/null
sync
eject $SCRIPT_SDCARD_PATH 2>&1 >/dev/null
sync
rm -rf "$PWD/root/"
rm -rf "$PWD/boot/"
rm -f "$PWD/$IMAGE_FILE_NAME"
if [ $HAD_WPA_SUP_FILE -eq 0 ]; then
    rm -f "$WPA_SUP_FILE"
fi
echo "... Done!"

echo -e "\n\nScript Complete! The device is synced, unmounted and ejected; you must now unplug it."
echo -e "It should boot and connect to wifi automatically.\n"
exit 0

