#!/bin/sh
# this script works properly run on console - and breaks if redirected to log file

for ID in `/usr/sbin/vzlist -Ho ctid`; do
	echo "####### updating container $ID [`vzlist -Ho hostname $ID`]"
	vzctl exec $ID apt-get update -qy
done
