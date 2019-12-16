#!/bin/bash

#Pull All Updates
git pull --all

#Create Commit Message
echo "Enter your Commit Message"
echo "If no Changes have been made, Press Enter"

#Create $cMessage Variable
read "cMessage"

#Add all files to be comitted
git add *

#Commit all files added and changed
git commit -a -m "$cMessage"

#Push changes to github repository
git push origin master


