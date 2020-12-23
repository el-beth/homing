#!/bin/bash

being_processed_movies_list="/tmp/movies_being_processed";
downloaded_movies_list="/usr/lib/moviesy/processed";
calling_url="$1";
url_hash="$(md5sum <<< "$calling_url" | egrep -oe '^[0-9a-z]{32}')";

if [ -z "$url_hash" ]
	then
		exit;
fi

if [ ( ! egrep -oe "$url_hash" "$being_processed_movies_list" ) && ( ! egrep -oe "$url_hash" "$downloaded_movies_list" ) ]
	then
		/usr/lib/moviesy/process_link.sh "$calling_url";
fi
