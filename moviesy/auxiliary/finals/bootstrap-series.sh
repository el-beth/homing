#!/bin/bash

# This script will accept an eztv showpage URL and use that to create the necessary directories

## TODO
## Mute the outputs of programs herein after verifying that they are error free

if [ -z "$1" ]
	then
		echo "error: # bootstrap-series.sh # call this script with an eztv showpage URL";
		exit 1;
fi

calling_arg="$1";
calling_arg_valid=false;
showpage_content="";
show_title=""
current_dump_dir=$(head -n 1 /usr/lib/moviesy/auxiliary/finals/current_dump_dir);
description="";

if ( [ -z "$current_dump_dir" ] || [ ! -d "$current_dump_dir" ] )
	then
		echo "error: # bootstrap-series.sh # \$current_dump_dir isn't valid, check the contents of /usr/lib/moviesy/auxiliary/finals/current_dump_dir";
		exit 3;
fi

function get_showpage_content(){
	until [ ! -z "$showpage_content" ]
		do
			showpage_content="$(wget -q -O - "$calling_arg" | tac - | tac -)";
	done
}


function make_directories(){
	count="0";
	mkdir --parents "/var/www/html/serial_english/$show_title";
	until ( [ "$count" -gt 5 ] || [ -d "/var/www/html/serial_english/$show_title" ] )
		do
			mkdir --parents "/var/www/html/serial_english/$show_title";
			count=$((++count));
			sleep 2;
	done

	if [ ! -d "/var/www/html/serial_english/$show_title" ]
		then
			echo "error: # bootstrap-series.sh # couldn't mkdir /var/www/html/serial_english/$show_title";
			exit 4;
	fi

	count="0";

	current_dump_dir=$(sed -E 's/^(.+)\/$/\1/gi' <<< "$current_dump_dir"); # remove trailing slashes if any

	until ( [ "$count" -gt 5 ] || [ -d "$current_dump_dir/$show_title" ] )
		do
			mkdir --parents "$current_dump_dir/$show_title";
			count=$((++count));
			sleep 2;
	done

	if [ ! -d "$current_dump_dir/$show_title" ]
		then
			echo "error: # bootstrap-series.sh # couldn't mkdir $current_dump_dir/$show_title";
			exit 5;
	fi
}

function extract_info(){
	description=$(egrep -ioe '<span itemprop="description">([^<]+)<\/span>' <<< "$showpage_content" | sed -E 's/<span itemprop="description">([^<]+)<\/span>/\1/g' | head -n 1);
	show_title=$(egrep -ioe '<title>([^<]+) Torrent Download - EZTV</title>' <<< "$showpage_content" | sed -E 's/<title>([^<]+) Torrent Download - EZTV<\/title>/\1/g' | head -n 1)
}

function populate_directories(){
	touch "/var/www/html/serial_english/$show_title/"{description.txt,dump.conf,eztv_link,index.html,poster.jpg,serial.conf,tvmaze_page};
	for file in "/var/www/html/serial_english/$show_title/"{description.txt,eztv_link,index.html,poster.jpg,serial.conf,tvmaze_page}
		do
			if [ ! -e "$file" ]
				then
					echo "error: # bootstrap-series.sh # couldn't create $file";
					exit 6;
			fi
	done

	echo "$description" > "/var/www/html/serial_english/$show_title/description.txt";
	echo "$calling_arg" > "/var/www/html/serial_english/$show_title/eztv_link";

	until (wget -q -O "/var/www/html/serial_english/$show_title/poster.jpg" "$(egrep -ioe 'https?://eztv.[^\/]+/ezimg/thumbs/[^"\/]+\.jpg' <<< "$showpage_content" | head -n 1)")
		do
			sleep 2;
	done

	echo "$calling_arg" >> "/var/www/html/serial_english/$show_title/serial.conf";
	echo "$show_title" >> "/var/www/html/serial_english/$show_title/serial.conf";
	echo "$current_dump_dir/$show_title" >> "/var/www/html/serial_english/$show_title/dump.conf";
	echo "$current_dump_dir/$show_title" >> "/var/www/html/serial_english/$show_title/serial.conf";
	echo "/var/www/html/serial_english/$show_title/index.html" >> "/var/www/html/serial_english/$show_title/serial.conf";
}

function main(){
	get_showpage_content;
	extract_info;
	make_directories;
	populate_directories;
}

main;