#!/bin/bash

serial_dir='/var/www/html/serial_english';

function navigate_to_serial_dir(){
	i="0";
	until ( [ "$(pwd)" == "$serial_dir" ] || [ "$i" -gt "10" ] )
		do
			cd "$serial_dir";
			i=$((++i));
	done

	if [ "$(pwd)" != "$serial_dir" ]
		then
			echo "error: # update_series.sh # can't navigate to $serial_dir";
			exit 1;
	fi
}

function update(){
	for serial in */serial.conf
		do
			series_name=$(sed -E 's/^(.+)\/serial\.conf/\1/g' <<< "$serial");
			if [ ! -z "$series_name" ]
				then
					echo "working with $series_name";
			fi
			/usr/lib/moviesy/auxiliary/finals/find_new_releases.sh "$serial" &> /dev/null &
			sleep 5;
	done
}

function main(){
	navigate_to_serial_dir;
	update;
}

main;