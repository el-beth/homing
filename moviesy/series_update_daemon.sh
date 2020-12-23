#!/bin/bash

cd "/var/www/html/serial_english"

if [ "$(pwd)" != "/var/www/html/serial_english" ]
	then
		echo "error: # series_update_daemon.sh # couldn't navigate to /var/www/html/serial_english";
		exit;
fi

while true
	do
		for dir in *
			do
				if ( [ -d "$dir" ] && [ -e "$dir/serial.conf" ] )
					then
						/usr/lib/moviesy/auxiliary/finals/find_new_releases.sh "$dir/serial.conf"&
						sleep 600;
				fi
		done
		sleep 18000;
done