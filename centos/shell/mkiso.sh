#!/bin/bash
#change isolinux/isolinux.cfg
#label linux
#  menu label ^Install CentOS 7
#  kernel vmlinuz
#  append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 ks=cdrom:/ks.cfg quiet
mkisofs  -J -R -T -v -V "CentOS 7 x86_64" -boot-info-table -no-emul-boot -boot-load-size 4 -b isolinux/isolinux.bin  -c isolinux/boot.cat  -o ../centOS-1206.iso ./
virsh destroy `virsh list|tail -2|awk '/916/{print $1}'|awk '/./ {print}'`
rm -fr 916.img
qemu-img create 916.img 10g
virsh create 916.xml

