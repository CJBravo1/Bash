#!/bin/bash

#This Script is a copy of all commands from https://ostechnix.com/advanced-copy-add-progress-bar-to-cp-and-mv-commands-in-linux/
#Written 12/04/2020

#Get Core Utils
wget http://ftp.gnu.org/gnu/coreutils/coreutils-8.32.tar.xz
tar xvJf coreutils-8.32.tar.xz
cd coreutils-8.32/

#Get Advanced Copy 
wget https://raw.githubusercontent.com/jarun/advcpmv/master/advcpmv-0.8-8.32.patch

#Apply Patch
patch -p1 -i advcpmv-0.8-8.32.patch

#Compile
./configure
make

#Copy New Copy $Path
sudo cp src/cp /usr/local/bin/cp
sudo cp src/mv /usr/local/bin/mv

#Auto Add Progress Bar to cp and mv commands
echo 'alias cp='/usr/local/bin/cp -gR' ' >> ~/.bashrc
echo 'alias mv='/usr/local/bin/mv -g' ' >> ~/.bashrc

