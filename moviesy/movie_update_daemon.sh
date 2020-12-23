#!/bin/bash

while true
	do
		/usr/lib/moviesy/download_latest_movies.sh &
		sleep 7200;
done