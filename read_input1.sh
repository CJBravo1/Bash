#!/bin/bash
#read_input1.sh

#Variables:
USERNAME="chris"

NOW="$(date '+%Y%m%d-%H%M')"

DIRECTORIES=" "

#Get input from user

cat <<EOF
This script backs up the /home/$USERNAME directory to /backup, as well as any files and directories you specify here. Type their names separated by spaces, then press Enter. If you do not want to back up additional directories just press Enter. 

EOF

read DIRECTORIES

#Backup the Directories entered by user

for i in $DIRECTORIES
do 
echo -e "\nBacking up ""$i"" to /backup/"
rsync -av --no-whole-file "$i" /backup

done 
