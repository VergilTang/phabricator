#!/bin/bash

set -e
set -x

#zypper ls
#exit

zypper ar -f http://mirrors.163.com/openSUSE/update/openSUSE-current/ 163-update
zypper ar -f http://mirrors.163.com/openSUSE/update/openSUSE-non-oss-current/ 163-update-non-oss
zypper ar -f http://mirrors.163.com/openSUSE/distribution/leap/15.1/repo/oss/ 163-oss
zypper ar -f http://mirrors.163.com/openSUSE/distribution/leap/15.1/repo/non-oss/ 163-non-oss

zypper modifyrepo -d repo-oss repo-update

zypper ref

# Add repositories
zypper --non-interactive ar http://download.opensuse.org/repositories/devel:/languages:/php/openSUSE_Leap_15.1/ php
#zypper --non-interactive ar http://download.opensuse.org/repositories/devel:/languages:/nodejs/openSUSE_Leap_15.1/ nodejs
zypper --non-interactive ar http://download.opensuse.org/repositories/devel:/languages:/python/openSUSE_Leap_15.1/ python

# Install Git before we add the SCM repository (the SCM repository contains Git 2.11, which is broken).
zypper --gpg-auto-import-keys --non-interactive in --force-resolution git

# Lock the git package to the current version
zypper --non-interactive al git

# Test to make sure we're not running Git 2.11, otherwise, abort the image bake right now (this prevents
# bad images from being pushed to the index).
if [ "$(git --version)" == *"2.11"* ]; then
  echo "Bad version of Git detected: $(git --version).  Aborting image creation!"
  exit 1
fi

# Add SCM package for other tools (Subversion, Mercurial)...
zypper --non-interactive ar http://download.opensuse.org/repositories/devel:/tools:/scm/openSUSE_Leap_15.1/ scm

# Install requirements
zypper --gpg-auto-import-keys --non-interactive in --force-resolution nginx php7 php7-fpm php php7-pecl php7-mbstring php7-mysql php7-curl php7-pcntl php7-gd php7-openssl php7-ldap php7-fileinfo php7-posix php7-json php7-iconv php7-ctype php7-zip php7-sockets which python3-Pygments ca-certificates ca-certificates-mozilla ca-certificates-cacert sudo subversion mercurial php7-xmlwriter php7-opcache ImageMagick postfix glibc-locale supervisor

# Build and install APCu
zypper --non-interactive install --force-resolution autoconf automake binutils cpp gcc glibc-devel libatomic1 libgomp1 libitm1 libltdl7 libmpc3 libpcre16-0 libpcrecpp0 libpcreposix0 libstdc++-devel libtool libtsan0 libxml2-devel libxml2-tools linux-glibc-devel m4 make ncurses-devel pcre-devel php7-devel php7-pear php7-zlib pkg-config readline-devel tack xz-devel zlib-devel

pecl channel-update pecl.php.net

printf "\n" | pecl install apcu-5.1.18
#zypper --non-interactive remove --force-resolution autoconf automake binutils cpp cpp48 gcc gcc48 glibc-devel libasan0 libatomic1 libcloog-isl4 libgomp1 libisl10 libitm1 libltdl7 libmpc3 libmpfr4 libpcre16-0 libpcrecpp0 libpcreposix0 libstdc++-devel libstdc++48-devel libtool libtsan0 libxml2-devel libxml2-tools linux-glibc-devel m4 ncurses-devel pcre-devel php7-devel php7-pear pkg-config readline-devel tack xz-devel zlib-devel

# Remove cached things that pecl left in /tmp/
rm -rf /tmp/*

# Install a few extra things
zypper --non-interactive install --force-resolution mariadb-client vim vim-data

# Force reinstall cronie
zypper --non-interactive install -f cronie

# Create users and groups
echo "nginx:x:497:495:user for nginx:/var/lib/nginx:/bin/false" >> /etc/passwd
echo "nginx:!:495:" >> /etc/group
echo "PHABRICATOR:x:2000:2000:user for phabricator:/srv/phabricator:/bin/bash" >> /etc/passwd
echo "wwwgrp-phabricator:!:2000:nginx" >> /etc/group

# Set up the Phabricator code base
mkdir /srv/phabricator
chown PHABRICATOR:wwwgrp-phabricator /srv/phabricator
cd /srv/phabricator
sudo -u PHABRICATOR git clone https://www.github.com/phacility/libphutil.git /srv/phabricator/libphutil
sudo -u PHABRICATOR git clone https://www.github.com/phacility/arcanist.git /srv/phabricator/arcanist
sudo -u PHABRICATOR git clone https://www.github.com/phacility/phabricator.git /srv/phabricator/phabricator
sudo -u PHABRICATOR git clone https://www.github.com/PHPOffice/PHPExcel.git /srv/phabricator/PHPExcel
cd /

# Clone Let's Encrypt
git clone https://github.com/letsencrypt/letsencrypt /srv/letsencrypt
cd /srv/letsencrypt
./letsencrypt-auto-source/letsencrypt-auto --help
cd /
