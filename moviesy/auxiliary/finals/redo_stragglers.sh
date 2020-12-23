#!/bin/bash


temp_dir="/media/load/storage2/temporary_dir";
process_queue_file="/tmp/movies_being_processed";

cd "$temp_dir"

until [ "$(pwd)" == "$temp_dir" ]
	do
		cd "$temp_dir";
		sleep 1;
done

for dir in *
	do
		if ( [ -d "$dir" ] && [ -e "$dir/link" ] )
			then
				hash=$(md5sum - < "$dir/link" | egrep -oe '^[0-9a-z]{32}');
				if [ ! -z "$hash" ]
					then
						if ( egrep -q "^$hash" "$process_queue_file" )
							then
								already_getting=true;
							else
								reprocess.sh "$(cat "$dir/link")" &
						fi
				fi
		fi
done