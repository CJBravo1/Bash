#!/bin/bash
for i in $(cat /home/u0155443/hostlist)
do
ping -q -c 1 -W 1 $i > /dev/null;
if [ $? = 0 ];
then
echo $i is up
else
echo $i is down
fi
done

