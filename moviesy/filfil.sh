#!/bin/bash

while read line
	do
		/usr/lib/moviesy/process_link.sh "$line";
done < /media/load/storage3/ful/pages.list