#!/bin/bash

count=1
PARAMNUM="$#"

while test "$count" -le "$PARAMNUM"
do
echo -e "\nBacking up ""$1"" to /backup/"
rsync -av --no-whole-file "$1" /backup
count=$(($count + 1))
shift
done
