#!/bin/bash

being_processed_movies_list="/tmp/movies_being_processed";
downloaded_movies_list="/usr/lib/moviesy/processed";
temporary_dir="/media/load/storage3";

function naviate_to_temp_dir(){
	count="0";
	until ([ "$(pwd)" == "$temporary_dir" ] || [ "$count" -gt "10" ])
		do
			cd "$temporary_dir";
			count=$((++count));
			sleep 6;
	done

	if [ "$(pwd)" != "$temporary_dir" ]
		then
			echo "error: not in $temporary_dir" && exit;
	fi
}

function try_reprocessing(){
	while true
		do
			for dir in *;
				do
					if ( [ -d "$dir" ] && [ -e "$dir/link" ] && [ ! -z "$dir/link" ] )
						then
							/usr/lib/moviesy/reprocess.sh "$(cat "$dir/link")";
							sleep 1;
						else
							sleep 1;
					fi
			done
			sleep 600;
	done
}

naviate_to_temp_dir;
try_reprocessing;