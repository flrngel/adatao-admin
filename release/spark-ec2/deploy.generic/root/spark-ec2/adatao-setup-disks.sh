#!/bin/bash -
#
# @author ctn@adatao.com
# @date Mon Aug  5 15:27:17 PDT 2013
#
# This script will be copied to /root/spark-ec2 and invoked by spark_ec2.py
# before doing any other setup tasks.
#
# The effect of this script is idempotent so it's ok to have it run multiple
# times.
#

PATH+=:/sbin

#
# Uses parted -l to discover mounted raw disks, and formats them all
#
function mkfs_raw_disks {
	local raw_devices=(`parted -l | grep unrecog | cut -f2 -d:`)
	for device in ${raw_devices[*]} ; do
		echo mkfs -t ext4 $device
		mkfs -t ext4 $device
	done
}

#
# Uses parted -l to locate formatted Xen disks, and mounts them all
#
function mount_xen_disks {
  local devices=(`parted -l | grep -A1 Xen | grep -v Xen | grep dev | cut -f1 -d: | cut -f2 -d' ' | sed -e 's/xvd/sd/g' | sort`)
  local mount_no=1
  local mount_point

  for device in ${devices[*]} ; do
    local base_device=`basename $device`

    if [ $mount_no == "1" ] ; then
      mount_point=/mnt
    else
      mount_point=/mnt${mount_no}
    fi

    echo "Mounting $device (base name is $base_device) to $mount_point"
    sed -e "/$base_device/d" -e "/`basename $mount_point`/d" /etc/fstab -i
    #/dev/sdf	/mnt5	auto	defaults,noatime,comment=cloudconfig	0	0
    echo "$device $mount_point  auto  defaults,noatime,comment=cloudconfig  0 0" >> /etc/fstab
    umount $device >/dev/null 2>&1
    umount $mount_point >/dev/null 2>&1
    mount $device

    mount_no=$((mount_no+1))
  done
}

function run {
	mkfs_raw_disks
	mount_xen_disks
}

run
