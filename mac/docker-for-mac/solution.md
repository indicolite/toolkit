# Development Toolkit for Kubernetes on Docker for Mac

Docker for Mac (on Edge channel) includes a local Kubernetes cluster which is very delightful for test and development. Refer to the official document ([https://docs.docker.com/docker-for-mac/#kubernetes](https://docs.docker.com/docker-for-mac/#kubernetes)) to know how to get it up and running.

If you are using Kubernetes on Docker for Mac, some scripts in this repository might be helpful.

## Table of Content

- [Pod/Docker Network Access](#pod-docker-network-access)

## <a name="pod-docker-network-access">Pod/Docker Network Access</a>

Because the Docker for Mac containers are actually running in a VM powered by
HyperKit, you can't directly have interactions with the containers. More details here, _[Docker for Mac - Networking - Known limitations, use cases, and workarounds](https://docs.docker.com/docker-for-mac/networking/#known-limitations-use-cases-and-workarounds)_.

To solve this problem, run an OpenVPN server container inside the VM with `host` network mode, then you can reach the containers with its internal IP. You can run the OpenVPN server with docker-compose or on Kubernetes.

Off course you can follow the docker-compose approach without Kubernetes.

Generally, it works like this:

``` Text
Mac <-> Tunnelblick <-> socat/service <-> OpenVPN Server <-> Containers
```

``` Bash
urmcdull@urmcdull:~|⇒  screen ~/Library/Containers/com.docker.docker/Data/vms/0/tty

linuxkit-025000000001:~# uname -a
Linux linuxkit-025000000001 4.9.93-linuxkit-aufs #1 SMP Wed Jun 6 16:55:56 UTC 2018 x86_64 Linux

Welcome to LinuxKit

                        ##         .
                  ## ## ##        ==
               ## ## ## ## ##    ===
           /"""""""""""""""""___/ ===
          {                       /  ===-
           ______ O           __/
                          __/
              ___________/

linuxkit-025000000001 login: root (automatic login)
Welcome to LinuxKit!

NOTE: This system is namespaced.
The namespace you are currently in may not be the root.

```

### Prepare

1. Install [`Tunnelblick`](https://tunnelblick.net/downloads.html) (an open source GUI OpenVPN client for Mac).

2. Change into the `docker-for-mac-openvpn` directory.


### Run OpenVPN server with docker-compose

Run the OpenVPN server, it'll generate certificates and configurations at the first time, maybe a little slow.

``` Bash
$ # Run
$ docker-compose up -d
$ # Follow logs
$ docker-compose logs -f
```

### Configure Client

Now, you will get the client config file at `./local/docker-for-mac.ovpn`. Add the subnets that you want to reach at bottom of the client config like below, and connect to the local OpenVPN server.

``` Config
route 192.168.65.0 255.255.255.0
route 10.96.0.0 255.240.0.0
route 172.17.0.0 255.255.0.0
```

### Test Network

Run a container and access to it directory with it's IP address.

``` Bash
$ # Start Nginx
$ docker run --rm -it nginx

$ # Find out the IP address
$ docker inspect `docker ps | grep nginx | awk '{print $1}'` | grep '"IPAddress"'
"IPAddress": "172.17.0.2",

$ # Visit
$ curl http://172.17.0.2
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

## Reference
https://github.com/pengsrc/docker-for-mac-kubernetes-devkit
