#!/bin/bash
#for_loop2.sh
for i in *
do lower="$(echo "$i" | tr [:upper:] [:lower:])"
echo mv "$i" "$lower"
done
