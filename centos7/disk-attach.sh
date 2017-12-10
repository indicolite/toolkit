#!/bin/bash
set -x

usage() { echo "Usage: $0 [-i <number>] [-t <san|nas>] [-s <string>]" 1>&2; exit 1; }

while getopts ":i:t:s:" o; do
    case "${o}" in
        i)
            i=${OPTARG}
            num=${i}
            ;;
        t)
            t=${OPTARG}
            ((t == 'san' || t == 'nas')) || usage
            ;;
        s)
            s=${OPTARG}
            path=${s}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${i}" ] || [ -z "${t}" ] || [ -z "${s}" ]; then
    usage
fi

cat <<EOF > /tmp/disk-test.xml
<disk type='block' device='disk'>
<driver name='qemu' type='raw'/>
<source dev='/dev/sdc'/>
<target dev='vdc' bus='virtio'/>
</disk>
EOF

vdx=`virsh domblklist $num|awk '/dev/ {print $1}'`
if [ -z ${vdx} ]; then
    sed -i -e "s|/dev/sdc|${path}|" /tmp/disk-test.xml
    #sed -i -e "s|vdc|${vdx}'|" /tmp/disk-test.xml
    virsh attach-device $num /tmp/disk-test.xml
fi
echo "End"
