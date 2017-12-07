#!/bin/bash
set -x
basepath=$(cd "$(dirname "$0")"; pwd)

templatepath=$basepath/template/
#------------------------------------------------------------------------------------------
tar zxvf $basepath/rpm.tar.gz -C $basepath
rpm -ivh $basepath/rpm/deltarpm-3.6-3.el7.x86_64.rpm
rpm -ivh $basepath/rpm/python-deltarpm-3.6-3.el7.x86_64.rpm
rpm -Uvh $basepath/rpm/libxml2-2.9.1-6.el7_2.3.x86_64.rpm
rpm -ivh $basepath/rpm/libxml2-python-2.9.1-6.el7_2.3.x86_64.rpm
rpm -ivh $basepath/rpm/createrepo-0.9.9-28.el7.noarch.rpm
createrepo --version 
if [ $? -ne 0 ]; then
    echo -e "\033[$red 'createrepo --version' command failed! \033[0m" 
    exit 1
fi

# local repos
mkdir -p /etc/yum_backup
mv -f /etc/yum.repos.d/* /etc/yum_backup

repoFile="/etc/yum.repos.d/centos.repo"
rm -f $repoFile
echo "[centos]" >> "$repoFile"
echo "name=centos" >> "$repoFile"
echo "baseurl=file://$basepath/rpm/" >> "$repoFile"
echo "gpgcheck=0" >> "$repoFile"
echo "enabled=1" >> "$repoFile"
createrepo $basepath/rpm/

yum clean all
yum makecache

# yum install  
yum remove -y libselinux-devel
yum install -y libselinux-devel
yum update -y
yum install -y docker-ce 

systemctl enable docker
systemctl start docker
systemctl status docker

docker --version 
if [ $? -ne 0 ]; then
    echo -e "\033[$red 'docker --version' command failed! \033[0m" 
    exit 1
fi

rm -f /etc/yum.repo.d/*
mv -f /etc/yum_backup/* /etc/yum.repos.d/
rm -rf /etc/yum_backup

yum clean all
yum makecache


/bin/docker load < $basepath/centos-6.6.tar
/bin/docker load < $basepath/ubuntu-16.04.tar
