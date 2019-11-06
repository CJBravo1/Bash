# !/bin/bash
# This is going to be a test mounting script
SHAREPOINT="$COMPUTER:$SHARE $MOUNTED nfs defaults 0 0"

echo "Which computer is the share located?"
read COMPUTER
echo "What is the name of the share on the remote computer?"
read SHARE
echo "Where would you like to mount this volume?"
read MOUNTED
mount $COMPUTER:$SHARE $MOUNTED
echo "$COMPUTER:$SHARE was mounted in $MOUNTED"
echo "Should I mount this when the computer starts?"
echo "1= YES or 2= NO"
while read MOUNTSTARTUP
do
if [ $MOUNTSTARTUP -eq 1 ]
then
if
cat /etc/fstab | grep -i "$COMPUTER:$SHARE" | cut -d " " -f1 -eq "$COMPUTER:$SHARE"
then 
break
else
echo "$COMPUTER:$SHARE $MOUNTED nfs defaults 0 0" >> /etc/fstab
echo "Your Mount is $SHAREPOINT"
break
fi
fi

if [ $MOUNTSTARTUP -eq 2 ]
then
echo "Ok"
echo "Your Mount is $SHAREPOINT"
fi
done
