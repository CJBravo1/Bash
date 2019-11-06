#!/bin/bash
#backup script 
NAME="chris"
NOW=" $(date '+%Y%m%d-%H%M')"
COUNT=1
PARAMNUM="$#"
for i in "$NAME"
do
echo What Directory would you like to backup?
read DIRECTORY
echo Where would you like to store this backup?
read BACKUP
rsync -a --no-whole-file "$DIRECTORY" "$BACKUP" > /backup2/backup-log_"$NOW" 2>/backup2/backup-errorlog_"$NOW" 
COUNT=$(($COUNT + 1)) 
shift
mail -s "output errors" chris < /backup2/backup-errorlog_"$NOW"
done

for j in "$NOW"
do
echo "Files backed up from "$DIRECTORY" to "$BACKUP" on ""$j"""
done
