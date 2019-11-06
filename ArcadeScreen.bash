#!/bin/bash
xrandr --newmode "640x480-15khz" 13.218975 640 672 736 840 480 484 490 525 -HSync -VSync interlace
xrandr --addmode DVI-I-1 "640x480-15khz"
xrandr --output DVI-I-1 --mode "640x480-15khz"