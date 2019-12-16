#!/bin/bash 
#This is just a simple if loop script.
ANSWER=$(( RANDOM % 10 ))
echo guess a number 1 through 10
read NUMBER
if [ $ANSWER == $NUMBER ]
then 
echo "That is correct"
else
echo "Guess again"
if [ $ANSWER -le $NUMBER ]
then 
echo "You are too high"
else
echo "You are too low"
fi
fi
echo " "
