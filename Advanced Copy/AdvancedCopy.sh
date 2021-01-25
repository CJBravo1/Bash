#!/bin/bash
#Get Core Utils
wget http://ftp.gnu.org/gnu/coreutils/coreutils-8.32.tar.xz
tar xvJf coreutils-8.32.tar.xz
cd coreutils-8.32/

#Download Advanced Copy Patch
wget https://raw.githubusercontent.com/jarun/advcpmv/master/advcpmv-0.8-8.32.patch

#Apply Patch
patch -p1 -i advcpmv-0.8-8.32.patch

#Compile
./configure
make

#Copy New cp and mv commands
sudo cp src/cp /usr/local/bin/cp
sudo cp src/mv /usr/local/bin/mv

#Add Alias
echo 'alias cp='/usr/local/bin/cp -gR'' > ~/.bashrc
echo 'alias mv='/usr/local/bin/mv -g'' > ~/.bashrc
