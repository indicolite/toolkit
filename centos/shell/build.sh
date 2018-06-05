cd /root/rpmbuild/SOURCES/sanlock3.5.0/sourcecode
tar czvf sanlock-3.5.0.tar.gz sanlock-3.5.0
mv sanlock-3.5.0.tar.gz /root/rpmbuild/SOURCES/
rpmbuild -ba /root/rpmbuild/SPECS/sanlock.spec
ps aux|grep sanlock|grep daemon|awk '{print $2}'|xargs kill -9
rpm -qa|grep -E ^sanlock|xargs rpm -e --nodeps
rpm -ivh /root/rpmbuild/RPMS/x86_64/sanlock-*
#cp /root/sanlock.conf /etc/sanlock/sanlock.conf
systemctl start sanlock
systemctl restart libvirtd
echo "xxxxxxxxxxxxxxxxxxxxx"
time virsh list
