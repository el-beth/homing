#!/bin/bash

count="0";

while true
	do
		for dir in "/var/www/html/serial_english/"*
			do
				if ( [ -d "$dir" ] && [ -e "$dir/serial.conf" ] && [ "$count" -lt "3" ] )
					then
						/usr/lib/moviesy/auxiliary/finals/find_new_releases.sh "$dir/serial.conf";
						count=$((++count));
				fi

				if ( [ ! -d "$dir" ] || [ ! -e "$dir/serial.conf" ] )
					then
						continue;
				fi

				if [ "$count" -eq "3" ]
					then
						sleep 120	; # launch 3 updates approximately every 20 mins
						count="0";
				fi
		done
done
