#!/bin/bash

# This script will produce the episode IDs on the eztv.ag page used to call the script

## call this script with 
	# $1 = the https://eztv.ag showpage e.g. https://eztv.ag/shows/25836/the-mandalorian
showpage_url="$1";
page="";
episodes="";

function download_showpage(){
	#call with the url of the showpage

	page="$(wget -q -O - "$showpage_url" 2> /dev/null | tac - | tac - )";
	counter="0";
	until ( [ ! -z "$page" ] || [ "$counter" -gt "20" ] )
		do
			page="$(wget -q -O - "$showpage_url" 2> /dev/null | tac - | tac - )";
			counter=$((++counter));
			sleep 1.5;
	done
	if [ -z "$page" ]
		then
			#echo "error # extract_episode_lists_eztv.sh #: couldn't download $showpage_url";
			exit 2;
	fi
}

function episode_str_gen(){
	season="$1";
	episode_max="$2";

	if [ "$season" -lt "10" ] 
		then
			season="0$season"; 
	fi

	episode=1;

	while [ "$episode" -le "$episode_max" ]
		do
			if [ "$episode" -lt "10" ]
				then
					echo "S$season""E0$episode";
				else
					echo "S$season""E$episode";
			fi
			episode=$((++episode));
	done
}

function filter_episodes(){
	episodes=$(egrep -ioe 'Season [0-9]+ -- [0-9]+ Episodes' <<< "$page" );
	if [ -z "$episodes" ]
		then
			#echo "error # extract_episode_lists_eztv.sh #: filter_episodes() wasn't productive";
			exit 3;
	fi
}

function generate_episodes(){
	while read line
		do 
			episode_str_gen "$(sed -E 's/^Season ([0-9]+) -- ([0-9]+) Episodes$/\1/gi' <<< "$line")" "$(sed -E 's/^Season ([0-9]+) -- ([0-9]+) Episodes$/\2/gi' <<< "$line")";
	done <<< "$episodes"
}

function main(){
	download_showpage;
	filter_episodes;
	generate_episodes;
}

main;