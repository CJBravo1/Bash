#!/bin/bash 
#This is just a simple while loop script. Nothing to exciting
ANSWER=$(( RANDOM % 10 ))
clear
echo Guess a number 0 through 10
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
 
