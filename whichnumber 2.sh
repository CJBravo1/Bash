#!/bin/bash 
#This is just a simple read script. Nothing to exciting
ANSWER=$(( RANDOM % 10 ))

echo Guess a number 1 through 10
while read NUMBER
do 
if [ $ANSWER == $NUMBER ] 
then
echo "You are Correct!"
break

else
echo "Guess Again!"

if [ $ANSWER -le $NUMBER ]
then
echo "You are too high"
else
echo "You are too low"
fi
fi
done
 
