#!/bin/bash

now="$(lsblk -o MOUNTPOINT | egrep -ve '(^$|^\/$|^MOUNTPOINT$)')";
previous="$now";

while true
	do
		now="$(lsblk -o MOUNTPOINT | egrep -ve '(^$|^\/$|^MOUNTPOINT$)')";
		while read new_line
			do
				if ( ! egrep -qe "^$new_line$" <<< "$previous" )
					then
						new_line=$(sed -E 's/\//\\\//g' <<< "$new_line");
						device="$(lsblk -o NAME,MOUNTPOINT | egrep -oe "^.+ $new_line$" | sed -E "s/^[└|─|├─]*(sd[a-z0-9][0-9]*) $new_line$/\/dev\/\1/gi")";
						firefox "http://mov.ez/cgi-bin/popup?device=$device"&
				fi
		done <<< "$now"
		previous="$now";
		sleep 1.5;
done