#!/bin/bash
#set -x

usage() { echo "Usage: $0 [-i <number>] [-t <san|nas>] [-s <string> the path will be passtrough in host machine] [-m <tring> the mount point in VM]" 1>&2; exit 1; }

while getopts ":i:t:s:m:" o; do
    case "${o}" in
        i)
            i=${OPTARG}
            num=${i}
            ;;
        t)
            t=${OPTARG}
            ((t == 'san' || t == 'nas')) || usage
            xas=${t}
            ;;
        s)
            s=${OPTARG}
            path=${s}
            ;;
        m)
            m=${OPTARG}
            mount_tag="${m}"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${i}" ] || [ -z "${t}" ] || [ -z "${s}" ] || [ -z "${m}" ]; then
    usage
fi

function nas_process(){
    virsh  qemu-monitor-command ${num} --hmp fs ${path}
    virsh  qemu-monitor-command ${num} --hmp device_add virtio-9p-pci,id=fs0,fsdev=fsdev-fs0,mount_tag=/shell,bus=pci.0
    sleep 1
    cmd="virsh qemu-agent-command ${num} '{\"execute\":\"guest-file-mount\",\"arguments\":{\"src\":\"/shell\",\"dir\":\"$mount_tag\"}}'"
    eval ${cmd}
}

function san_process(){

cat <<EOF > /tmp/disk-test.xml
<disk type='block' device='disk'>
<driver name='qemu' type='raw'/>
<source dev='/dev/sdc'/>
<target dev='vdf' bus='virtio'/>
</disk>
EOF

vdx=`virsh domblklist $num|awk '/dev/ {print $1}'`
if [ -z ${vdx} ]; then
    sed -i -e "s|/dev/sdc|${path}|" /tmp/disk-test.xml
    #sed -i -e "s|vdc|${vdx}'|" /tmp/disk-test.xml
    #virsh detach-device $num /tmp/disk-test.xml
    virsh attach-device $num /tmp/disk-test.xml
fi
}


if [ ${xas} == 'san' ]; then
    san_process
    echo 'san process'
elif [ ${xas} == 'nas' ]; then
    nas_process
    echo 'nas process'
fi
echo "End"
