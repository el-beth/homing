#!/bin/bash
#
## call this script with the series conf_page_path($1), show_episode($2)(as S01E01)
# show_name should be the same as the one used across the system -- exactly e.g. no family guy or Family guy .. The right one is
# Family Guy

conf_page_content=$(cat "$1");

if [ -z "$conf_page_content" ]
	then
		echo "error: # automate.sh # conf_page_content is empty" && exit;
fi

showpage_url="$(head -n 1 <<< "$conf_page_content")";
show_name="$(head -n 2 <<< "$conf_page_content" | tail -n 1)";
permanent_storage="$(head -n 3 <<< "$conf_page_content" | tail -n 1)";
catalogue_page_path="$(head -n 4 <<< "$conf_page_content" | tail -n 1)";

series_hash_table="/usr/lib/moviesy/series_hash.list";

show_episode="$2";

if [ -z "$show_episode" ]
	then
		exit
fi
working_dir="$(pwd)";
page="";
session="$(md5sum <<< "$show_name $show_episode" | egrep -oe '^[a-z0-9]{32}')";
episode_update_dir="episode_update_""$session";
showstring="$show_name $show_episode";
show_filter_regex="";
min_seeders="1";
max_size="700000000" # maximum file size in bytes
smallest_file="";
magnet="";

function download_showpage(){
	#call with the url of the showpage
	until [ ! -z "$page" ]
		do
			page=$(wget -q -O - "$showpage_url" | tac - | tac -);
	done
}
	
function create_temp_dir(){
	echo "current session is: $session";
	if [ ! -d "/tmp/$episode_update_dir/$show_name" ]
		then
			mkdir --parents "/tmp/$episode_update_dir/$show_name" && cd "/tmp/$episode_update_dir/$show_name";
		else
			users_of_this_dir=$(lsof /tmp/$episode_update_dir/$show_name 2> /dev/null);
			if [ ! -z "$users_of_this_dir" ]
				then
					echo "error # automate.sh # : thwarted repeat simultaneous update attempt, exitting"
					exit; # this prevents repeated simultaneous update attempts;
				else
					cd "/tmp/$episode_update_dir/$show_name" && rm -r * 2> /dev/null;
			fi
			
	fi
}

function extract_tables_from_page(){

	## call with the name of the output file after running the download_showpage() function;
	pcregrep -M --buffer-size 999999 '<tr name="hover" class="forum_header_border">\n<td[^<]+<a[^>]+><img[^>]+><\/a><\/td>\n<td[^>]+>\n<a[^>]+>[^<]+<\/a>\n<\/td>\n<td[^>]+>\n<a[^>]+><\/a>\n<a[^>]+><\/a>\n<\/td>\n<td[^>]+>[^<]+<\/td>\n<td[^>]+>[^<]+<\/td>\n<td[^>]+><[^>]+>[^<]+<\/[^>]+><\/[^>]+>\n<\/tr>' <<< "$page" >> "$1";
}

function prepare_showname_string(){

	## call as prepare_showname_string "family guy s19e01"
	show_filter_regex="$(sed -E 's/([^A-Z0-9]|^|$)/\.\*/gi' <<< "$1")";
}

function tokenise(){
	# call with the name of the ouput file that contains the tables 
	if [ ! -z tables ]
		then
			split -l 13 tables table_token_ ;
		else
			echo "error # automate.sh # : 'tables' not found" && exit ;
	fi
}

function weedout_unnecessary_files(){
	for file in table_token_* ## This will excise all those entries pertaining to episodes and potentially series other than the one under consideration
		do 
			if ( ! egrep -qie "$show_filter_regex" "$file" )
				then
					rm "$file";
			fi;
	done

	found1="$(find . -type f -name "table_token_*")";

	if [ -z "$found1" ]
		then
			echo "error: filtering with \$show_filter_regex removed all table tokens and nothing remains" && exit 1;
	fi

	for file in table_token_* ## This will remove torrents with no seeders (or unpopular torrents with seeder-number smaller than that specified by $mis_seeders)
		do 
			seeders=$(head -n 12 "$file" | tail -n 1 | sed -E 's/<td [^>]+><font [^>]+>([^<]+)<\/font><\/td>$/\1/g' | sed -E 's/[^0-9\-]//g' | sed -E 's/\-/0/g'); 

			if [ "$seeders" -lt "$min_seeders"  ]
				then 
					rm "$file"; 
			fi 
	done

	found2="$(find . -type f -name "table_token_*")"

	if [ -z "$found2" ]
		then
			echo "error: filtering with \$min_seeders removed all table tokens and nothing remains" && exit;
	fi

	for file in table_token_* ## This will remove torrents larger than 500M as these are too big for any series
		do 
			file_size=$(head -n 10 "$file" | tail -n 1 | sed -E 's/<td [^>]+>([0-9\.]+ [KMGiB]{2})<\/td>$/\1/g'| sed -E 's/( |B$)//g' | numfmt --from auto); 
			if [ "$file_size" -gt "$max_size"  ]
				then 
					rm "$file"; 
			fi 
	done

	found3="$(find . -type f -name "table_token_*")";

	if [ -z "$found3" ]
		then
			echo "error: filtering with \$max_size removed all table tokens and nothing remains";
			exit;
	fi

	for file in table_token_*
		do 
			file_size=$(head -n 10 "$file" | tail -n 1 | sed -E 's/<td [^>]+>([0-9\.]+ [KMGiB]{2})<\/td>$/\1/g'| sed -E 's/( |B$)//g' | numfmt --from auto); 
			seeders=$(head -n 12 "$file" | tail -n 1 | sed -E 's/<td [^>]+><font [^>]+>([^<]+)<\/font><\/td>$/\1/g' | sed -E 's/[^0-9\-]//g' | sed -E 's/\-/0/g');
			inverse_likability="$(bc <<< "$file_size/$seeders")";
			if [ -z "$smallest" ]
				then 
					smallest="$file" && smallest_size="$file_size" && smallest_inverse_likability="$(bc <<< "$file_size/$seeders")"; 
			fi

			if [ "$inverse_likability" -lt "$smallest_inverse_likability" ]
				then 
					smallest="$file" && smallest_inverse_likability="$inverse_likability"; 
			fi
	done

	smallest_file="$smallest";

	# avoiding confusion by removing all tokens other than the smallest

	for file in table_token_*
		do
			if [ "$smallest_file" != "$file" ]
				then
					rm "$file";
			fi
	done

}

function extract_magnet(){
	magnet="$(egrep -ioe 'magnet:\?[^"]+' "$smallest_file")";
	if [ -z "$magnet" ]
		then
			echo "magnet couldn't be extracted from $(pwd)/$smallest_file"
		else
			echo "$magnet" > magnet;
	fi
}

function get_torrent_file_of_best(){
	torrent_file_link=$(head -n 8 "$smallest_file" | tail -n 1 | egrep -ioe 'http[s]*://[^"]+\.torrent');

	i="0";
	until ( ( [ -e "file.torrent" ] && [ ! -z "file.torrent" ] ) || [ "$i" -gt "10" ] )
		do
			wget --no-clobber --no-check-certificate -O "file.torrent" "$torrent_file_link";
			i="$((++i))";
	done

	if ( [ ! -e "file.torrent" ] || [ -z "file.torrent" ] )
		then
			if [ ! -z "$magnet" ]
				then
					echo "error: # automate.sh # : error downloading torrent file but the magnet link is available";
				else
					echo "error: # automate.sh # : error downloading torrent file and the magnet link -- not able to commence download of the episode";
			fi
	fi
}

function flatten_dir(){
	files="$(find ./ -type f)";
	directories="$(find ./ -type d)";

	i="0";
	until ( [ -d "neat" ] || [ "$i" -ge 5 ] )
		do
			mkdir "neat";
			i=$((++i));
			sleep 1;
	done

	if [ ! -d neat ]
		then
			echo "Error: couldn't create directory 'neat'" && exit 1;
	fi

	while read file 
		do
			mv "$file" --no-clobber --target-directory="neat";

	done <<< "$files"

	i="0";
	until ( [ -d "junk" ] || [ "$i" -ge 5 ] )
		do
			mkdir "junk";
			i=$((++i));
			sleep 1;
	done

	if [ ! -d junk ]
		then
			echo "Error: couldn't create directory 'junk'" && exit 2;
	fi

	while read directory 
		do
			if ([ "$directory" != "./neat" ] && [ "$directory" != "./junk" ])
				then
					mv "$directory" --no-clobber --target-directory="junk";
			fi

	done <<< "$directories"

	small_files="$(find . -size -10971520c -type f 2> /dev/null)"; ## less than 10M in size and files, not directories - since not specifying f results in non-empty directories being included in the return

	while read small_file
		do
			if [ -e "$small_file" ]
				then
					rm "$small_file";
			fi

	done <<< "$small_files"

	if [ -d "junk" ]
		then
			rm -r "junk";
	fi

	mv neat/* . ;

	if [ "$(du -s neat | egrep -ioe '^[0-9]+')" -le "1024" ]
		then
			if [ -d "neat" ]
				then
					rm -r "neat";
			fi
	fi

	# whatever directory still remaining after all that is one that contains exact duplicates, remove it.

	for dir in *
		do
			if [ -d "$dir" ]
				then
					echo "still stray $dir";
					rm -r "$dir"
			fi
	done
}

function name_and_categorise(){
	series_name="$show_name";
	files=$(ls 2> /dev/null);

	for file in *;
		do
			if [ ! -e "$file" ]
				then
					continue;
			fi

			if [ -d "$file" ]
				then
					continue;
			fi

			if ( ! egrep -qie '^.*s[0-9]{2}e[0-9]{2}.*$' <<< "$file" )
				then
					if [ ! -d rogue ]
						then
							i="0";
							until ( [ -d "rogue" ] || [ "$i" -ge 5 ] )
								do
									mkdir "rogue";
									i=$((++i));
									sleep 1;
							done

							if [ ! -d rogue ]
								then
									echo "Error: couldn't create directory 'rogue'";
									exit 2;
							fi
					fi
					mv "$file" --no-clobber --target-directory="rogue";
				else
					if [ ! -d rogue ]
						then
							i="0";
							until ( [ -d "rogue" ] || [ "$i" -ge 5 ] )
								do
									mkdir "rogue";
									i=$((++i));
									sleep 1;
							done

							if [ ! -d rogue ]
								then
									echo "Error: couldn't create directory 'rogue'";
									exit 2;
							fi
					fi
					index="$(egrep -ioe 's[0-9]{2}e[0-9]{2}' <<< "$file" | tr [a-z] [A-Z])";
					if [ ! -z "$index" ]
						then
							if [ "$(grep -i "$index" <<< "$files" 2> /dev/null | wc -l)" -gt "1" ]
								then
									candidates=$(grep -i "$index" <<< "$files" 2> /dev/null);
									largest="";
									while read input
										do
											if [ -z "$largest" ]
												then
													largest="$input";
												else
													if [ "$(du "$input" | egrep -oe '^[0-9]+')" -gt "$(du "$largest" | egrep -oe '^[0-9]+')" ]
														then
															largest="$input";
													fi
											fi
									done <<< "$candidates"

									file="$largest";

									extension=$(egrep -oe '\.[^\.]+$' <<< "$file" | tr [A-Z] [a-z])
									new_name="$series_name"__"$index""__MOV.EZ__0982268482__""$extension";
									mv --no-clobber "$file" "$new_name";

									while read roguish
										do
											mv "$roguish" --no-clobber --target-directory="rogue";
									done <<< "$candidates"

									season_num=$(sed -E 's/S([0-9]+)E[0-9]+/\1/g' <<< "$index" | egrep -oe '^[0-9]+' | bc);
									season_dir="Season $season_num";

									if [ ! -d "$season_dir" ]
										then
											i="0";
											until ( [ -d "$season_dir" ] || [ "$i" -ge 5 ] )
												do
													mkdir "$season_dir";
													i=$((++i));
													sleep 1;
											done

											if [ ! -d "$season_dir" ]
												then
													echo "Error: couldn't create directory '$season_dir'";
													exit 2;
											fi
									fi

									mv --no-clobber "$new_name" --target-directory="$season_dir";
								else
									extension=$(egrep -oe '\.[^\.]+$' <<< "$file" | tr [A-Z] [a-z])
									new_name="$series_name"__"$index""__MOV.EZ__0982268482__""$extension";
									mv --no-clobber "$file" "$new_name";
									season_num=$(sed -E 's/S([0-9]+)E[0-9]+/\1/g' <<< "$index" | egrep -oe '^[0-9]+' | bc);
									season_dir="Season $season_num";

									if [ ! -d "$season_dir" ]
										then
											i="0";
											until ( [ -d "$season_dir" ] || [ "$i" -ge 5 ] )
												do
													mkdir "$season_dir";
													i=$((++i));
													sleep 1;
											done

											if [ ! -d "$season_dir" ]
												then
													echo "Error: couldn't create directory '$season_dir'";
													exit 2;
											fi
									fi

									mv --no-clobber "$new_name" --target-directory="$season_dir";
							fi
					fi
			fi
	done

	strays=$(find . -maxdepth 1 -type f);
	if [ ! -z "$strays" ]
		then
			while read stray 
				do
					mv --no-clobber "$stray" --target-directory="rogue";
			done <<< "$strays"
	fi

	# dealing with the directory rogue

	if [ -d "rogue" ]
		then
			size=$(du -s rogue | egrep -oe '^[0-9]+')
			if ( [ ! -z "$size" ] && [ "$size" -lt "20480" ] )
				then
					rm -r "rogue";
				else
					echo "error: directory rogue is not negligible, so not going to be removed";
			fi
			
	fi
}

function update_catalogue(){
	# moving the Season [0-9]+ dir to the final resting place for the series
	cp -r Season\ * "$permanent_storage";
	cd "$permanent_storage";
	permanent_storage=$(sed -E 's/^(.+)\/$/\1/gi' <<< "$permanent_storage"); # remove trailing slashes if any
	if [ "$(pwd)" != "$permanent_storage" ]
		then
			counter=0
			until ( [ "$(pwd)" == "$permanent_storage" ] || [ "$counter" -gt "30" ] ) # this iteration will not last for more than a minute
				do
					cd "$permanent_storage";
					sleep 2;
					counter=$((++counter));
			done
	fi

	if [ "$(pwd)" != "$permanent_storage" ]
		then
			if [ ! -z "$permanent_storage" ]
				then
					if [ ! -d "$permanent_storage" ]
						then
							echo "error # automate.sh #: \'$permanent_storage\' is not a directory";
						else
							echo "error # automate.sh #: \'$permanent_storage\' can't be accessed";
					fi
				else
					echo "error # automate.sh #: \'$permanent_storage\' is an empty string";
			fi
	fi
}

function download_episode(){
	if [ -e "file.torrent" ]
		then
			if [ ! -z "file.torrent" ]
				then
					aria2c  --allow-overwrite=true --bt-max-peers=0 --file-allocation=none -d . --enable-dht=true --seed-time=0 --bt-stop-timeout=599 --bt-tracker-timeout=599 --max-overall-upload-limit=20K --continue=true "file.torrent" && flatten_dir && name_and_categorise && update_catalogue;
				else
					echo "error: # automate.sh # : the file.torrent associated with this episode is empty";
					if [ ! -z "$magnet" ]
						then
							aria2c  --allow-overwrite=true --bt-max-peers=0 --file-allocation=none -d . --enable-dht=true --seed-time=0 --bt-stop-timeout=599 --bt-tracker-timeout=599 --max-overall-upload-limit=20K --continue=true "$magnet" && flatten_dir && name_and_categorise && update_catalogue;
						else
							echo "error: # automate.sh # : both magnet link and torrent file are unavailable";
							exit 120;
					fi
			fi
		else
			if [ ! -z "$magnet" ]
				then
					aria2c  --allow-overwrite=true --bt-max-peers=0 --file-allocation=none -d . --enable-dht=true --seed-time=0 --bt-stop-timeout=599 --bt-tracker-timeout=599 --max-overall-upload-limit=20K --continue=true "$magnet" && flatten_dir && name_and_categorise && update_catalogue;
				else
					echo "error: # automate.sh # : both magnet link and torrent file are unavailable";
					exit 120;
			fi
	fi
}

function main(){
	download_showpage;
	create_temp_dir;
	extract_tables_from_page tables;
	prepare_showname_string "$showstring";
	tokenise;
	weedout_unnecessary_files;
	extract_magnet;
	get_torrent_file_of_best;
	download_episode;
}

main;