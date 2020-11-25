#!/bin/bash
echo "поехали"

#создаем lvm 
echo "new lvm create"
pvcreate /dev/sdb --bootloaderareasize 1m 
vgcreate otus /dev/sdb
lvcreate -L 1G -n swap otus
lvcreate -l+100%FREE -n root otus

#создаем fs
echo "fs create"
mkfs.xfs /dev/otus/root
mkswap /dev/otus/swap
mount /dev/otus/root /mnt

yum install -y xfsdump
xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
cp -aR /boot/* /mnt/boot/ 

#chroot
echo "chroot!"


mount -t proc /proc/ /mnt/proc/
mount --rbind /dev/ /mnt/dev/
mount --rbind /sys/ /mnt/sys/

chroot /mnt/ /bin/bash <<"EOT"

#перзаписываеи fstab
echo "/dev/mapper/otus-root / xfs  defaults 0 0" > /etc/fstab
echo "/dev/mapper/otsu-swap swap swap defaults 0 0" >> /etc/fstab

#установка grub
#GRUB_CMDLINE_LINUX="no_timer_check console=tty0 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0 elevator=noop crashkernel=auto rd.lvm.lv=VolGroup00/LogVol00 rd.lvm.lv=VolGroup00/LogVol01 rhgb quiet"
grub2-install /dev/sdb
sed -i 's|VolGroup00/LogVol00|otus/root|g' /etc/default/grub
sed -i 's|VolGroup00/LogVol01|otus/swap|g' /etc/default/grub

#обновление grub cfg
grub2-mkconfig -o /boot/grub2/grub.cfg

#пересобираем initrd
dracut -f
EOT