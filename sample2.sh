#!/bin/bash
#
#sample2.sh
#Backup Someone's home directory to /backup using rsync

USERNAME="chris"
echo -e "Backing up /home/""$USERNAME" to /backup/""

rsync -a --no-whole-file /home/"$USERNAME" /backup > /backup/backup-log_"$NOW" 2>/backup/backup-errorlog_"$NOW"

#send log files per mail to user

if test "$?" -eq 0
then
mail -s "Backup successful" "$USERNAME" < /backup/backup-log_"$NOW"
else
mail -s "Some Error occurred during backup" "$USERNAME" < /backup/backup-errorlog_"$NOW"
fi



