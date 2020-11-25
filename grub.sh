#!/bin/bash
cat >/etc/yum.repos.d/grub2.repo <<EOL
[grub2]
name=grub-yum.rumyantsev
baseurl=https://yum.rumyantsev.com/centos/7/x86_64/
gpgcheck=0
enabled=1
EOL

yum -y upgrade grub2
setenforce 0