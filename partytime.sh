#!/bin/bash
x="0"

while [ $x -eq '0' ]

do

color=$(shuf -i 0-7 -n 1)
#RANGE=8
#MAXCOUNT=8

#echo $color

setterm -term linux -fore $color


echo "Party Time"

done
