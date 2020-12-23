#!/bin/bash

permanent_storage_parent="/media/load/storage2/korean";

printf "Content-type: text/html\n\n"

if [ -z "$QUERY_STRING" ]
	then
		echo "<html><head><link rel="shortcut icon" href="http://mov.ez/img/favicon.ico"></head><body><p>error: # loader.sh # error generating loader page with \$QUERY_STRING '$QUERY_STRING'</p></body></html>" && exit 1;
fi

if ( egrep -qie '%[0-9]{2}' <<< "$QUERY_STRING" )
	then
		QUERY_SAFE=$(printf "$(sed -E 's/%([0-9\n]{2})/\\x\1/gi' <<< "$QUERY_STRING")\n" | sed -E 's/\/$//gi')
	else
		QUERY_SAFE=$(sed -E 's/\/$//gi' <<< "$QUERY_STRING");
fi

name=$(sed -E 's/^name=([^&]+)&session=(.+)$/\1/gi' <<< "$QUERY_SAFE");
session=$(sed -E 's/^name=([^&]+)&session=(.+)$/\2/gi' <<< "$QUERY_STRING");

QUERY_SAFE="$name";

count="1";
until ( [ "$(pwd)" == "$permanent_storage_parent/$QUERY_SAFE" ] || [ "$count" -gt "10" ] )
	do
		cd "$permanent_storage_parent/$QUERY_SAFE";
		count=$((++count));
		sleep 1.5;
done

if [ "$(pwd)" != "$permanent_storage_parent/$QUERY_SAFE" ]
	then
		echo "error: # loader.sh # couldn't navigate to $permanent_storage_parent/$QUERY_SAFE" && exit 3;
fi

if ( [ ! -e poster.jpg ] || [ ! -e description ] )
	then
		if [ ! -e poster.jpg ]
			then
				echo "error: # loader.sh # poster.jpg not in $QUERY_SAFE" && exit 5;
		fi

		if [ ! -e description ]
			then
				echo "error: # loader.sh # description not in $QUERY_SAFE" && exit 6;
		fi
fi

QUERY_SAFE=$(sed -E 's/\/$//gi' <<< "$QUERY_SAFE");
serial="$(sed -E 's/^.+\/([^\/]+)$/\1/gi' <<< "$QUERY_SAFE")"

preamble='<!DOCTYPE html><html><head><link rel="shortcut icon" href="http://mov.ez/img/favicon.ico"><link rel="stylesheet" type="text/css" href="http://mov.ez/css/main.css"><link rel="stylesheet" type="text/css" href="http://mov.ez/css/series-specific.css"><title>'"$serial"'</title></head><body><div class="container"><div class="header neu-passive"><a href="http://mov.ez/"><div class="home_button neu"><img src="http://mov.ez/img/home.png"></div></a><div class="other-offerings"><div class="offerings-container"><a href="http://mov.ez/cgi-bin/moviesy_series/main_dl.sh?session='"$session"'"><div class="offering neu"><img src="http://mov.ez/img/tv-100.png"></div></a><a href="http://mov.ez/cgi-bin/moviesy_feature/main_dl.sh?page=1&session='"$session"'"><div class="offering neu"><img src="http://mov.ez/img/movies-100.png"></div></a><a href="http://mov.ez/cgi-bin/moviesy_korean/main_dl.sh?session='"$session"'"><div class="offering neu"><img src="http://mov.ez/img/korean.png"></div></a></div></div><div class="search_bar"><form action="http://mov.ez/cgi-bin/search_korean_dl.sh" method="get" enctype="application/x-www-form-urlencoded" autocomplete="off" novalidate><input class="neu" type="text" placeholder="Search" name="query'"$session"'"><img class="search_icon_style" src="http://mov.ez/img/search_icon.png"></form></div></div>''<div class="landing-single neu-passive"><div class="desc-and-image"><div><img class="neu-passive" src="'"http://mov.ez/korean/$serial/poster.jpg"'"></div><div class="desc-wrapper neu-passive"><p>'"$(cat "/var/www/html/korean/$serial/description")"'</p></div></div><div class="loading-section-container neu-passive">';
body_content=''; # scoping this variable to this series

permanent_storage="$permanent_storage_parent/$serial";

count="1";
until ( [ "$(pwd)" == "$permanent_storage" ] || [ "$count" -gt "10" ] )
	do
		cd "$permanent_storage";
		count=$((++count));
		sleep 1.5;
done

if [ "$(pwd)" != "$permanent_storage" ]
	then
		echo "error: # loader.sh # couldn't navigate to $permanent_storage" && exit 7;
fi

seasons=$(ls 2> /dev/null | sort -V );

if [ -z "$seasons" ]
	then
		echo "error: # loader.sh # : nothing in \$serial" && exit 8;
fi

seasons_clean=$(egrep -ioe '^Season [0-9]+' <<< "$seasons");

if [ -z "$seasons_clean" ]
	then
		echo "error: # loader.sh # : you might have called this script before flatenning and renaming stuff" && exit 9;
fi

seasons_clean=$(sort -V <<< "$seasons_clean");

if [ ! -z "$seasons_clean" ]
	then
		while read season
			do
				if [ -f "$season" ]
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
								html="<html><head></head><body><center><a href=\"http://mov.ez/cgi-bin/dl?$hash&session=$session\" style='padding:auto; margin: auto; text-decoration: none; font-family: sans-serif; color: #333; font-size: 1.2em'>$episode_id</a></center></body></html>"; 
								base64_enc=$(base64 -w 0 --ignore-garbage <<< "$html");
								frame='<iframe class="neu" src="data:text/html;base64,'"$base64_enc"'">iframe not supported</iframe>'; 
								episode_frames="$episode_frames$(echo "$frame")";
								echo "$hash $(pwd)/$epi" >> /tmp/current_korean_hashes; # dumping hashes to a temporary log

								if ( ! egrep -qie "^$hash .+$" "$series_hash_table" )
									then
										echo "$hash $(pwd)/$epi" >> "$series_hash_table";
								fi
						fi; 
				done
				body_content="$body_content$(echo "$season_specific")$(echo "$episode_frames")</div></div></div>";
		done <<< "$seasons_clean"
		footer='</div></div></div></body></html>';
		page="$preamble$body_content$footer";
		echo "$page"
	else
		echo "no season directories in $serial";
fi