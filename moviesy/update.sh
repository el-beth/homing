#!/bin/bash

## GLOBAL VARIABLES

home_page_content="";
movie_links="";
movie_links_with_hashes="";
current_movie_links="";
current_movie_links_with_hashes="";
approved_links="";
current_year="";
session_id="$RANDOM";
session_home_page="/tmp/index_$session_id.html";
downloaded_movies_list="/usr/lib/moviesy/processed";
being_processed_movies_list="/tmp/movies_being_processed";
new_stuff_available="false";


## END OF GLOBAL VARIABLES

function check_connection(){
	# if ping doesn't work, while the website is up n running, uncomment the ff line
	return 0
	if ( ping -c 2 www.yts.ag &> /dev/null )
		then
			return 0;
		else
			return 1;
	fi
}

function tell_status(){
	if [ ! -z "$1" ]
		then
			notify-send --expire-time 5000 --urgency normal "  status" "$1" &
		else
			echo "error: notify-send called without an argument"
	fi
}

function create_session_files(){
	touch "$being_processed_movies_list";
	touch "$session_home_page";
}

function download_homepage(){
	create_session_files;

	wget --output-document "$session_home_page" "https://www.yts.ag";

	home_page_content="$(cat "$session_home_page")";
}

function extract_movie_links(){
	movie_links=`egrep --only-matching --regexp '<a href="https://yts\.[A-Za-z0-9]+/movies/[^"]+\" class="browse-movie-link"' <<< "$home_page_content" | sed --regexp-extended "s/(<a href\=\"|\" class=\"browse-movie-link\")//g" | sed --regexp-extended 's/\/$//g' | sort | uniq`;
	#
}

function get_current_year(){
	current_year=`date +%Y`;
	#
}

function extract_current_movie_links(){
	get_current_year;
	current_movie_links=`egrep --only-matching --regexp "^.+$current_year$" <<< "$movie_links"`;
}

function create_link_hashes(){
	while read movie_link
		do
			link_hash=`md5sum <<< "$movie_link" | cut --characters -32`;
			line="$link_hash $movie_link";

			if [ -z "$movie_links_with_hashes" ]
				then
					movie_links_with_hashes="$line";
				else
					movie_links_with_hashes=`echo "$movie_links_with_hashes" && echo "$line"`;
			fi
	done <<< "$movie_links"
}

function create_current_link_hashes(){
	while read movie_link
		do
			link_hash=`md5sum <<< "$movie_link" | cut --characters -32`;
			line="$link_hash $movie_link";

			if [ -z "$current_movie_links_with_hashes" ]
				then
					current_movie_links_with_hashes="$line";
				else
					current_movie_links_with_hashes=`echo "$current_movie_links_with_hashes" && echo "$line"`;
			fi
	done <<< "$current_movie_links"
}

function approve_link(){
	new_stuff_available="true";
	if [ -z "$approved_links" ]
				then
					approved_links="$1";
				else
					approved_links=`echo "$approved_links" && echo "$1"`;
			fi
}

function pre_process_movie_links(){
	while read link_and_hash
		do
			if [ ! -z "$link_and_hash" ]
				then
					hash=`cut --characters -32 <<< "$link_and_hash"`;
					link=`cut --characters 34- <<< "$link_and_hash"`;

					if ( ! egrep --quiet "^$hash$" "$downloaded_movies_list" "$being_processed_movies_list" )
						then
							approve_link "$link";
					fi
			fi
	done <<< "$movie_links_with_hashes"
}

function pre_process_current_movie_links(){
	while read current_link_and_hash
		do
			if [ ! -z "$current_link_and_hash" ]
				then
					hash=`cut --characters -32 <<< "$current_link_and_hash"`;
					link=`cut --characters 34- <<< "$current_link_and_hash"`;

					if ( ! egrep --quiet "^$hash$" "$downloaded_movies_list" "$being_processed_movies_list" )
						then
							approve_link "$link";
					fi
			fi
	done <<< "$current_movie_links_with_hashes"
}

function dispatch(){
	if [ "$new_stuff_available" == "true" ]
		then
			while read approved_link
				do
					/usr/lib/moviesy/process_link.sh "$approved_link"&
			done <<< "$approved_links"
	fi
}

function main(){
	download_homepage;
	extract_movie_links;
	extract_current_movie_links;
	create_current_link_hashes;
	pre_process_current_movie_links;
	dispatch;
}

main;