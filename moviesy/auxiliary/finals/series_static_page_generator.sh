#!/bin/bash

# control this script by controling the varable $working_dir
# $working_dir is a variable that is the parent directory of the directory
# where the pre-arranged episode files are located in

# e.g. /media/load/storage2/finish-ish which contains a directory structure 
# like  				Family Guy
#                          ↳ Season 1
#                          ↳ Season 2
#                          ↳ Season 3
#                          ↳ Season 4
#
# will have working_dir='/media/load/storage2/finish-ish' 
# and the final error and status output of this script will be an index.html
# file located in the directory for each series
# i.e 					Family Guy
#                          ↳ index.html
#                          ↳ Season 1
#                          ↳ Season 2
#                          ↳ Season 3
#                          ↳ Season 4
# All other error and status messages will be output to stdout and stderr
# this script will be called upon to generate a new index.html page whenever a new episode gets 
# added, 
#
# TODO
#
# 1) we need a moded version of the script that names the episode correctly after it has been downloaded
#    and one that will situate it in the appropriate season directory after it has bee properly named
# 2) A script that will check what episode needs to be downloaded (determine the latest, and therefore,
#    the unavailable) episode, and download it, 

working_dir="/media/dimitri/storage2/finish-ish";
working_dir="$(sed -E 's/\/$//g' <<< "$working_dir")";
series_hash_table="/tmp/hashes-series" # this is the hash table that will be used to store that hashes if the entries are new;
series_log_file="~/Desktop/series.log"

function navigate_to_working_dir(){

	cd "$working_dir";

	if [ "$(pwd)" != "$working_dir" ]
		then
			counter=0
			until ( [ "$(pwd)" == "$working_dir" ] || [ "$counter" -gt "30" ] ) # this iteration will not last for more than a minute
				do
					cd "$working_dir";
					sleep 2;
					counter=$((++counter));
			done
	fi

	if [ "$(pwd)" != "$working_dir" ]
		then
			if [ ! -z "$working_dir" ]
				then
					if [ ! -d "$working_dir" ]
						then
							echo "error # extract_episode_lists_local.sh #: \'$working_dir\' is not a directory"
						else
							echo "error # extract_episode_lists_local.sh #: \'$working_dir\' can't be accessed"
					fi
				else
					echo "error # extract_episode_lists_local.sh #: \'$working_dir\' is an empty string";
			fi
	fi
}

function main(){
	navigate_to_working_dir;

	for serial in * # this is the name of the series as far as the script is concerned
		do
			if [ -d "$serial" ]
				then
					preamble='<!DOCTYPE html><html><head><link rel="stylesheet" type="text/css" href="http://192.168.0.200/css/main.css"><link rel="stylesheet" type="text/css" href="http://192.168.0.200/css/series-specific.css"><title>'"$serial"'</title></head><body><div class="container"><div class="header neu-passive"><a href="http://192.168.0.200/"><div class="home_button neu"><img src="http://192.168.0.200/img/home.png"></div></a><div class="other-offerings"><div class="offerings-container"><a href="http://192.168.0.200/cgi-bin/moviesy_feature/main.sh"><div class="offering neu"><span>feature</span></div></a><a href="http://192.168.0.200/cgi-bin/moviesy_korean/main.sh"><div class="offering neu"><span>korean</span></div></a><a href="http://192.168.0.200/eritrean/"><div class="offering neu"><span>eritrean</span></div></a></div></div><div class="search_bar"><form action="http://192.168.0.200/cgi-bin/search_series.sh" method="get" enctype="application/x-www-form-urlencoded" autocomplete="off" novalidate><input class="neu" type="text" placeholder="Search" name="query"><img class="search_icon_style" src="http://192.168.0.200/img/search_icon.png"></form></div></div>''<div class="landing-single neu-passive"><div class="desc-and-image"><div><img class="neu-passive" src="'"http://192.168.0.200/serial_english/$serial/poster.jpg"'"></div><div class="desc-wrapper neu-passive"><p>'"$(cat "/var/www/html/serial_english/$serial/description.txt")"'</p></div></div><div class="loading-section-container neu-passive">';
					body_content=''; # scoping this variable to this series
					cd "$serial" ## go in-- look for 'go out'
					seasons=$(ls 2> /dev/null);

					if [ -z "$seasons" ]
						then
							echo "error: # series_static_page_generator.sh # : nothing in \$serial"
							exit 1;
					fi
					
					seasons_clean=$(egrep -ioe '^Season [0-9]+' <<< "$seasons");

					if [ -z "$seasons_clean" ]
						then
							echo "error: # series_static_page_generator.sh # : you might have called this script before flatenning and renaming stuff"
							exit 2;
					fi

					seasons_clean=$(sort -V <<< "$seasons_clean")
					if [ ! -z "$seasons_clean" ]
						then
							while read season
								do
									if [ ! -d "$season" ]
										then
											continue;
									fi
									season_number=$(sed -E 's/^Season ([0-9]+)/\1/gi' <<< "$season");
									season_number=$(bc <<< "$season_number"); # removing any leading '0' if there is/are any
									season_specific='<div class="season-container neu-passive"><div class="season-number"><center>Season</br><span>'"$season_number"'</span></center></div><div class="loadables-container neu-passive"><div class="iframes-container">';
									cd "$season"; # go in -- into season this time
									episode_frames="";
									for epi in * 
										do 
											if [ -f "$epi" ]
												then
													episode_id=$(sed -E 's/^.+--(S[0-9]{2})(E[0-9]{2}).+$/\2/gi' <<< "$epi");
													filename=$(sed -E 's/^(.+)\.[a-z0-9]{2,5}$/\1/gi' <<< "$epi"); # incase a defective episode file gets replaced with a working one that has a different filename extension, just using the filename stripped of the extension ensures continued functionality by simply updating the serial hashtable and the file, without need to interact with the index.html file that is produced by this script
													hash=$(md5sum <<< "$filename" | egrep -ioe '^[0-9a-z]{32}'); 
													html="<html><head></head><body><center><a href=\"http://127.0.0.1/cgi-bin/myscr.sh?$hash\" style='padding:auto; margin: auto; text-decoration: none; font-family: sans-serif; color: #333; font-size: 1.2em'>$episode_id</a></center></body></html>"; 
													base64_enc=$(base64 -w 0 --ignore-garbage <<< "$html");
													frame='<iframe class="neu" src="data:text/html;base64,'"$base64_enc"'">iframe not supported</iframe>'; 
													episode_frames="$episode_frames$(echo "$frame")";
													echo "$hash $(pwd)/$epi" >> /tmp/new_hashes; # updating the hash table if need be, i.e. new addition

													if ( ! egrep -qie "^$hash .+$" "$series_hash_table" )
														then
															echo "$hash $(pwd)/$epi" >> "$series_hash_table";
													fi
											fi; 
									done
									body_content="$body_content$(echo "$season_specific")$(echo "$episode_frames")</div></div></div>";
									cd "$working_dir/$serial" # go out of season
							done <<< "$seasons_clean"
							footer='</div></div><footer><div class="footer neu"><img src="http://192.168.0.200/img/logo_elbet_smaller.png" height="90%"></div></footer></div></body></html>';
							page="$preamble$body_content$footer";
							echo "$page" > "/var/www/html/serial_english/$serial/index.html";
							echo "done with $serial";
						else
							echo "no season directories in $serial";
					fi
					cd "$working_dir"; ## go out
			fi
	done
}

main;