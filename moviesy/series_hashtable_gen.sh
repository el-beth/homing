#!/bin/bash

# the purpose of this script is to generate the hash of the series episodes by iteratively looking 
# for files over 10MiB

series_hashtable='/usr/lib/moviesy/series_hash.list';

if ( ! touch "$series_hashtable" )
	then
		echo "error: # series-hashtable-gen.sh # can't write to $series_hashtable" && exit 1;
	else
		echo '' > "$series_hashtable";
fi

while read series_dir
	do
		files=$(find "$series_dir" -size +5M );

		while read episode
			do
				episode_name="$(sed -E 's/^.+\/([^\/]+)$/\1/g' <<< "$episode" | sed -E 's/^(.+)\.[^\.]+$/\1/g')";
				episode_hash="$(md5sum <<< "$episode_name" | cut -c -32 | egrep -ioe '^[0-9a-z]{32}')";
				if [ -z "$episode_hash" ]
					then
						continue;
				fi
				echo "$episode_hash $episode" >> "$series_hashtable";
		done <<< "$files"
done < '/usr/lib/moviesy/serial_dump_dirs.conf'