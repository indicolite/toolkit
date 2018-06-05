#run under fabric 1.4.4
#fab -f fabfile.py deploy
from fabric.api import *
from fabric.colors import *

env.user = 'root'
env.hosts = ['host-30']
env.passwords = {
    'host-30' :'fhrootroot',
}

#@parallel
def deploy():
    #with cd('/xxx/'):
    with settings(warn_only=True):
        run('rm -fr /tmp/x86_64')
	put('/tmp/x86_64.tar.gz', '/tmp')
	run('tar xzvf /tmp/x86_64.tar.gz -C /tmp')
        run('pkill -KILL sanlock')
        run('rpm -qa|grep -E ^sanlock|xargs rpm -e --nodeps')
	run('cd /tmp/x86_64 && rpm -ivh sanlock-*')
        #run('mv /etc/sanlock/sanlock.conf.rpmsave /etc/sanlock/sanlock.conf')
        #run('mv /etc/libvirt/qemu-sanlock.conf.rpmsave /etc/libvirt/qemu-sanlock.conf')
        run('systemctl start sanlock')
        run('systemctl restart libvirtd')
        run('systemctl status libvirtd')
        run('systemctl status sanlock')
