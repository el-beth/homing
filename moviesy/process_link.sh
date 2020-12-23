#!/bin/bash

## GLOBAL VARIABLES 

# this version has had minor additions to extract and hold all metadata pertaining to the movie,
# already available on yts.ag .. stuff like description, genre, language, run-length ... are dumped
# in an XML file and stored for later use inside a file called meta.xml in the directory of the movie.
# i.e. /var/www/html/movies/20[0-9]{2}/$movie/meta.xml

# start of ammendment is December 16, 2020

# for raw comparison and diff file generation, the starting point of the script amendment is stored
# as .process_link.sh in the project directory

## in addition, this script will embed all downloaded .srt files into the movie file instead of removing
## them all as part of the cleanup process.

movie_page_content="";
session_id="$RANDOM";
session_temp_file="/tmp/session_$session_id.html";
being_processed_movies_list="/tmp/movies_being_processed";
downloaded_movies_list="/usr/lib/moviesy/processed";
calling_url="$1";
url_hash="";
trailer_url="";
trailer_alternative_url="";
poster_url="";
torrent_file_url="";
torrent_file="";
trailer_file="";
poster_file="";
temporary_working_dir="/media/load/storage3/temporary_dir";
movie_name="";
movie_dir="";
cookie_file="/home/load/Desktop/cookies.txt";
poster_downloaded="false";
trailer_downloaded="false";
torrent_downloaded="false";
torrent_file_downloaded="false";
finished_processing="false";
current_permanent_storage="/media/load/storage3/movies";
movies_hashlist="/usr/lib/moviesy/movies_hash.list";
meta_file_content="";

## END OF GLOBAL VARIABLES

function tell_status(){
	# call with status message to say
	notify-send -t 5000 -u normal "  status" "$1" &
}

function check_connection(){
	# if ping doesn't work, while the website is up n running, uncomment the ff line
	return 0
}

function create_session_files(){
	touch "$session_temp_file";
	#
}

function create_url_hash(){
	url_hash=`md5sum <<< "$calling_url" | cut --characters -32`;
	#
}

function unlock_link(){
	if [ ! -z "$url_hash" ]
		then
			sed --in-place "s/^$url_hash$//g" "$being_processed_movies_list";
		else
			create_url_hash;
			sed --in-place "s/^$url_hash$//g" "$being_processed_movies_list";
	fi

	while read line
		do
			if [ ! -z "$line" ]
				then
					echo "$line" >> "$being_processed_movies_list.tmp"
			fi
	done < "$being_processed_movies_list"

	if [ -e "$being_processed_movies_list.tmp" ]
		then
			mv "$being_processed_movies_list.tmp" "$being_processed_movies_list"
	fi

}

function get_movie_page(){
	if ( check_connection )
		then
			create_session_files;

			if ( ! wget --quiet --output-document "$session_temp_file" "$calling_url" )
				then
					echo "error: wget couldn't download $calling_url.html, exitting";
					exit;
				else	
					movie_page_content=`cat "$session_temp_file"`;
					rm "$session_temp_file";
			fi
		else
			echo "error: error pinging www.yts.ag, exitting";
			exit;
			#tell_status "error pinging www.yts.ag";
	fi
}

function extract_movie_name(){
	movie_name="`egrep --only-matching --regexp "<title>[^>]+>"  <<< "$movie_page_content" | cut --characters 8- | sed --regexp-extended --expression "s/YIFY.+$//g" | sed --regexp-extended --expression "s/[ \t]*$//g"`";
	#
}

function extract_trailer_url(){
	trailer_url=`egrep --max-count 1 --only-matching --regexp 'http[s]*://www.youtube.com/embed/[^?]+' <<< "$movie_page_content"`;
	if [ -z "$trailer_url" ]
		then
			echo "error: problem extracting trailer URL from the page $calling_url";
			search_string="https://www.youtube.com/results?search_query=`sed --regexp-extended --expression "s/[^A-Za-z0-9()]/+/g" <<< "$movie_name"`+Official+Trailer&sp=EgQIBRgB";
			trailer_youtube_vid=`wget --quiet --output-document - "$search_string" | tac - | tac - | egrep --only-matching --regexp 'watch\?v=[^"]+' | head --lines 1`;
			trailer_url="https://www.youtube.com/$trailer_youtube_vid";
	fi

	if [ -z "$trailer_url" ]
		then
			tell_status "error: couldn't get trailer for $movie_name, exitting";
			unlock_link;
			exit;
	fi
}

function extract_meta_info(){
	# the meta info to be extracted are:
		# production year -- single line
		# genre/s -- as csv
		# IMDB page link -- single line
		# synopsis -- single line
		# director -- as csv
		# cast -- as csv
		# run-length
		# frame rate 
		# language

	# also, noteworthiny mentioning than any errors encountered during extraction of the above
	# metadata are non-blocking errors and in no way cause halt of execution

	production_year="$(egrep -ioe '<title>[^<]+</title>' <<< "$movie_page_content" | sed -E 's/^<title>(.+) \(([0-9]{4})\) YIFY - Download Movie TORRENT - YTS<\/title>/\2/gi' | tail -n 1)";
	genre=$(pcregrep --buffer-size 9999999 -M '<div class="hidden-xs">\n<h1>[^<]+</h1>\n(<h2>[^<]+<a[^>]+><span[^>]+>[^<]+<\/span></a></h2>\n<h2>[^<]+</h2>|<h2>[^<]+</h2>\n<h2>[^<]+</h2>)' <<< "$movie_page_content" | tail -n 1 | sed -E -e 's/(^<h2>|<\/h2>$)//gi' -e 's/ \/ /, /g' | tail -n 1);
	imdb_page_link=$(egrep -ioe 'https://www\.imdb\.com/title/[^/" ]+' <<< "$movie_page_content" | tail -n 1);
	synopsis="$(egrep -ioe '<p class="hidden-xs">[^<]+<\/p>' <<< "$movie_page_content" | sed -E 's/(^<p class="hidden-xs">|<\/p>$)//g' | tail -n 1 )";
	director="$(egrep -ioe 'itemprop="director".*http://schema\.org/Person"><span[^>]+>[^<]+</span></span></a>' <<< "$movie_page_content" | tail -n 1 | sed -E 's/^itemprop="director".*http:\/\/schema\.org\/Person"><span[^>]+>([^<]+)<\/span><\/span><\/a>/\1/gi' | tail -n 1)";
	cast="$(pcregrep --buffer-size 999999 -M '<div class="actors">\n<h3>Cast</h3>\n(<div[^>]+>\n<div[^>]+>\n<a[^>]+> ?<img[^>]+> ?</a>\n</div>\n<div[^>]+>\n<a[^>]+><span[^>]+><span[^>]+>[^<]+</span></span></a>[^<]+\n</div>\n</div>\n)+' <<< "$movie_page_content" | egrep -ioe 'itemprop="actor".*http:\/\/schema\.org\/Person"><span[^>]+>([^<]+)<\/span><\/span><\/a>' | sed -E 's/itemprop="actor".*http:\/\/schema\.org\/Person"><span[^>]+>([^<]+)<\/span><\/span><\/a>/\1/gi')"; while read cast_member; do cast_line="$cast_line, $cast_member"; done <<< "$cast"; cast_line="$(sed -E 's/^, //g' <<< "$cast_line")"; cast="$(tail -n 1 <<< "$cast_line")";
	run_length="$(egrep -ioe '<span title="Runtime" class="icon-clock"></span>([^<]+)<div[^>]+></div> ?</div>' <<< "$movie_page_content" | tail -n 1 | sed -E -e 's/<span title="Runtime" class="icon-clock"><\/span>([^<]+)<div[^>]+><\/div> ?<\/div>/\1/gi' -e 's/^ *//g' | tail -n 1)";
	frame_rate="$(egrep -ioe 'title="Frame Rate" class="icon-film"></span> ?([^<]+)' <<< "$movie_page_content" | tail -n 1 | sed -E -e 's/title="Frame Rate" class="icon-film"><\/span> ?([^<]+)/\1/gi' -e 's/^ *//g' | tail -n 1 )";
	language="$(egrep -ioe 'title="Language" class="icon-volume-medium"></span>([^<]+)<div></div>' <<< "$movie_page_content" |  sed -E -e 's/title="Language" class="icon-volume-medium"><\/span>([^<]+)<div><\/div>/\1/gi' -e 's/^ *//g' )"; language_int=""; while read line; do language_int="$language_int, $line" ; done <<< "$language"; language_int="$(sed -E 's/^, //gi' <<< "$language_int")"; language="$(tail -n 1 <<< "$language_int")";

	if [ ! -z "$production_year" ]
		then
			echo "<production_year>$production_year</production_year>" >> meta.xml;
	fi

	if [ ! -z "$genre" ]
		then
			echo "<genre>$genre</genre>" >> meta.xml;
	fi

	if [ ! -z "$imdb_page_link" ]
		then
			echo "<imdb_page_link>$imdb_page_link</imdb_page_link>" >> meta.xml;
	fi

	if [ ! -z "$synopsis" ]
		then
			echo "<synopsis>$synopsis</synopsis>" >> meta.xml;
	fi

	if [ ! -z "$director" ]
		then
			echo "<director>$director</director>" >> meta.xml;
	fi

	if [ ! -z "$cast" ]
		then
			echo "<cast>$cast</cast>" >> meta.xml;
	fi

	if [ ! -z "$run_length" ]
		then
			echo "<run_length>$run_length</run_length>" >> meta.xml;
	fi

	if [ ! -z "$frame_rate" ]
		then
			echo "<frame_rate>$frame_rate</frame_rate>" >> meta.xml;
	fi

	if [ ! -z "$language" ]
		then
			echo "<language>$language</language>" >> meta.xml;
	fi

	echo "$movie_page_content" >> "meta.page"
}

function extract_torrent_url(){
	torrent_file_url=`egrep --regexp '<a download class="download-torrent button-green-download2-big" href="https://yts.[a-zA-Z0-9]+/torrent/download[^"]+' <<< "$movie_page_content" | grep --max-count 1 '720p' | egrep --only-matching --regexp 'https://[^"]+'`;
	if [ -z "$torrent_file_url" ]
		then
			echo "error: torrent file URL couldn't be extracted from $calling_url";
			unlock_link;
			exit;
	fi
	#
}

function extract_poster_url(){
	poster_url=`egrep --max-count 1 --only-matching --regexp 'http[s]*://img.yts.[a-zA-Z0-9]+/assets/images/movies/[^/]+/medium-cover.jpg' <<< "$movie_page_content" | sed --expression "s/medium-cover/large-cover/g"`;
	if [ -z "$poster_url" ]
		then
			echo "error: couldn't extract poster URL from $calling_url"
	fi
}

function download_poster(){

	if [ -e 'poster.jpg' ]
		then
			if [ ! -z 'poster.jpg' ]
				then
					if [ "`file poster.jpg | egrep --only-matching --max-count 1 --regexp 'JPEG image data'`" == 'JPEG image data' ]
						then
							poster_downloaded="true";
							return 0;
					fi
			fi
	fi

	until ( [ ! -z poster.jpg ] && [ "`file poster.jpg | egrep --only-matching --max-count 1 --regexp 'JPEG image data'`" == 'JPEG image data' ] )
		do
			wget --quiet --output-document 'poster.jpg' "$poster_url"; 
	done

	if ( [ ! -z poster.jpg ] && [ "`file poster.jpg | egrep --only-matching --max-count 1 --regexp 'JPEG image data'`" == 'JPEG image data' ] )
		then
			tell_status "downloaded poster for $movie_name";
			poster_downloaded="true";
			return 0;
		else
			echo "error: failed to download poster for $movie_name, exitting";
			tell_status "error: failed to download poster for $movie_name, exitting";
			unlock_link;
			exit;
	fi
}

function download_trailer(){

	if ( [ -e 'trailer.mp4' ] && [ ! -z 'trailer.mp4' ] )
		then
			echo "already downloaded trailer for $movie_name";
			trailer_downloaded="true";
			return 0;
	fi

	if [ ! -e "$cookie_file" ]
		then
			echo "error: cookie file non-existent"
			return 2;
	fi

	if ( ! youtube-dl --cookies "$cookie_file" --continue --no-playlist --output "trailer.mp4" --format 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4' "$trailer_url" &> rep )
		then
			if ( egrep --quiet --only-matching --regexp "HTTP Error 429" ./rep )
				then
					tell_status "error: the youtube cookie might have expired, please process the captcha challenge of the page $trailer_url and dump the cookie to ~/Desktop/cookie.txt";
					starting_hash=`md5sum "$cookie_file" | cut --characters -32`;
					firefox "$trailer_url";
					zenity --height=150 --width=400 --title="Update YouTube cookies" --error --text='Attention: update the YouTube cookies and dump them.' &> /dev/null &

					until [ "`md5sum "$cookie_file" | cut --characters -32`" != "$starting_hash" ]
						do 
							sleep 2;
					done

					youtube-dl --cookies "$cookie_file" --continue --no-playlist --output "trailer.mp4" --format 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4' "$trailer_url"

					if ( [ ! -f 'trailer.mp4' ] || [ -z 'trailer.mp4' ] )
						then
							echo "error: unknown error preventing from downloading trailer for $movie_name, exitting";
							unlock_link;
							exit;
					fi
			fi
	fi

	if ( [ -f 'trailer.mp4' ] && [ ! -z 'trailer.mp4' ] )
		then
			trailer_downloaded="true";
			return 0;
		else
			return 1;
	fi
}

function create_download_dir(){
	movie_dir="$temporary_working_dir/$movie_name";
	if [ ! -d "$movie_dir" ]
		then
			mkdir --parents "$movie_dir";
		else
			echo "status: using pre-existing dir for $movie_name";
	fi

	until [ "`pwd`" == "$movie_dir" ]
		do
			mkdir "$movie_dir" &> /dev/null;
			sleep 5;
			cd "$movie_dir" &> /dev/null;
	done

	if [ ! -d "$movie_dir" ]
		then
			echo "error: couldn't create $movie_dir, exitting";
			tell_status "error: couldn't create $movie_dir, exitting";
			unlock_link;
			exit;
	fi
	cd "$movie_dir" && echo "$calling_url" > link;
}

function download_torrent_file(){
	if ( [ -e 'file.torrent' ] && [ `du file.torrent | egrep -oe "^[0-9]+"` != "0" ] )
		then
			torrent_file_downloaded="true";
			return 0;
		else
			if ( wget --quiet --output-document "file.torrent" "$torrent_file_url" )
				then
					if ( [ -e 'file.torrent' ] && [ `du file.torrent | egrep -oe "^[0-9]+"` != "0" ] )
						then
							torrent_file_downloaded="true";
							return 0;
					fi
				else
					until ( [ -e 'file.torrent' ] && [ `du file.torrent | egrep -oe "^[0-9]+"` != "0" ] )
						do
							wget --quiet --output-document "file.torrent" "$torrent_file_url" 
					done

					if ( [ -e 'file.torrent' ] && [ `du file.torrent | egrep -oe "^[0-9]+"` != "0" ] )
						then
							torrent_file_downloaded="true";
							return 0;
					fi
					echo "error: couldn't download torrent file, exitting";
					unlock_link;
					exit;
			fi
	fi
}

function embed_subtitles(){
	# check if there are any .srt files 
	# if there are embed them into the largest video file.
	# largest file is $1

	largest_file="$1";
	new_name="$(sed -E 's/^(.+)(\.[^\.]+)/\1_Subbed\2/g' <<< "$largest_file")";
	subs=$(find . -type f -regextype egrep -iregex '^.+\.srt$');

	if [ ! -z "$subs" ]
		then
			# embedding syntax ffmpeg -i "$largest_file" "$inputs" -map 0:v -map 0:a "$mappings" -c copy "$metadatas" "$new_name"
			inputs=""; while read line; do inputs="$inputs -i \"$line\""; done <<< "$subs"
			mappings=""; count=1; while read line; do mappings="$mappings -map $count"; count=$((++count)); done <<< "$subs";
			metadatas=""; count="0"; while read line; do lang=$(sed -E 's/.+\.([a-z]{,5})\.[^\.]+$/\1/g' <<< "$line"); metadatas=" $metadatas -metadata:s:s:$count language=\"$lang\""; count=$((++count)) ; done <<< "$subs"; metadatas=$(sed -E 's/^[\t ]*//g' <<< "$metadatas")
			echo "ffmpeg -i \"$largest_file\" "$inputs" -map 0 $mappings -c:v copy -c:a copy -c:s mov_text $metadatas \"$new_name\"" | bash
			mv "$new_name" "$largest_file";
		else
			echo "There are no subtitles to embed" && return;
	fi
}

function download_torrent(){
	if [ -e torrent_downloaded ]
		then
			torrent_downloaded="true"
			return 0;
		else
			aria2c  --allow-overwrite=true --bt-max-peers=0 --file-allocation=none -d . --enable-dht=true --seed-time=0 --bt-stop-timeout=599 --bt-tracker-timeout=599 --max-overall-upload-limit=20K --continue=true "file.torrent" && touch torrent_downloaded;
			if [ -e torrent_downloaded ]
				then
					torrent_downloaded="true";
					return 0;
				else
					return 1;
			fi
	fi
	
}

function find_largest_file(){
	## run this in the specific movie's download dir, it's supposed to find the largest file and spit out a relative
	## path of it's location rooted at the working dir at the time of invocation

	if [ ! -d "$1" ]
		then
			echo "`date` Error 8: find_largest_file() called with an argument that is not a directory";
			unlock_link;
			exit;
	fi

	size=0;
	largest="";
	while read line
	do
		if [ -z "$line" ]
			then
				echo "`date` Error 9: find outputted an empty line";
				unlock_link;
				exit;
		fi

		size_cur="`du "$line" | egrep --only-matching --regexp "^[0-9]+"`";
		if [ "$size_cur" -ge "$size" ]
			then
				size="$size_cur";
				largest="$line";
		fi; 
	done <<< "`find "$1" -type f -size +100M -regex '.+\(\.3g2\|\.3gp\|\.amv\|\.asf\|\.avi\|\.drc\|\.f4a\|\.f4b\|\.f4p\|\.f4v\|\.flv\|\.gif\|\.gifv\|\.M2TS\|\.m2v\|\.m4p\|\.m4v\|\.mkv\|\.mng\|\.mov\|\.mp2\|\.mp4\|\.mpe\|\.mpeg\|\.mpg\|\.mpv\|\.mxf\|\.nsv\|\.ogg\|\.ogv\|\.qt\|\.rm\|\.rmvb\|\.roq\|\.svi\|\.TS\|\.vob\|\.webm\|\.wmv\|\.yuv\|\.3G2\|\.3GP\|\.AMV\|\.ASF\|\.AVI\|\.DRC\|\.F4A\|\.F4B\|\.F4P\|\.F4V\|\.FLV\|\.GIF\|\.GIFV\|\.M2TS\|\.M2V\|\.M4P\|\.M4V\|\.MKV\|\.MNG\|\.MOV\|\.MP2\|\.MP4\|\.MPE\|\.MPEG\|\.MPG\|\.MPV\|\.MTS\|\.MXF\|\.NSV\|\.OGG\|\.OGV\|\.QT\|\.RM\|\.RMVB\|\.ROQ\|\.SVI\|\.TS\|\.VOB\|\.WEBM\|\.WMV\|\.YUV\)$'`"

	if [ ! -z "$largest" ]
		then
			echo "$largest";
		else
			echo "`date` Error 10: find_largest_file() couldn't find the largest file";
			unlock_link;
			exit;
	fi
}

function create_catalogue_entry(){
	## call this with "$movie_name" "$movie_year"

	if [ -e "done" ]
		then
			echo "`date` Error 11: create_catalogue_entry() called on a directory that has already been processed i.e. $1";
			unlock_link;
			exit; ## this is intended to prevent second processing of something that has already been processed
	fi
	movie_page_url="$3";
	movie_year="$2";
	movie_title="$1";

	if ( [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] )
		then
			echo "`date` Error 12: create_catalogue_entry called with insufficient argument/s";
			unlock_link;
			exit;
	fi

	#sed -i 100i"$catalogue_entry_line" /var/www/html/movie/2020/pages/index.html;

	if [ ! -d "/var/www/html/movie/$movie_year/$movie_title" ]
		then
			if ( ! mkdir --parents "/var/www/html/movie/$movie_year/$movie_title" )
				then
					echo "`date` Error 13: unable to create /var/www/html/movie/$movie_year/$movie_title";
			fi
		else
			echo "`date` Error 14: second time processing $movie_title";
			unlock_link;
			exit;
	fi

	if [ ! -e "/var/www/html/movie/$movie_year/$movie_title/trailer.mp4" ]
			then
				mv trailer.mp4 "/var/www/html/movie/$movie_year/$movie_title";
			else
				echo "`date` Error 15: error moving $movie_title's trailer to /var/www/html/movie/$movie_year/$movie_title";
				unlock_link;
				exit;
	fi
	
	if [ ! -e "/var/www/html/movie/$movie_year/$movie_title/poster.jpg" ]
			then
				mv poster.jpg "/var/www/html/movie/$movie_year/$movie_title";
			else
				echo "`date` Error 16: error moving $movie_title's poster to /var/www/html/movie/$movie_year/$movie_title";
				unlock_link;
				exit;
	fi

	if [ -e  "/var/www/html/movie/$movie_year/$movie_title/hash" ]
		then
			echo "`date` Error 17: caught attempt to create a new hash for $movie_title while the old one exists as /var/www/html/movie/$movie_year/$movie_title/hash";
			unlock_link;
			exit;
		else
			if [ ! -e hash ]
				then
					hash=`md5sum - <<< "$movie_page_url" | cut -c -32`;
					echo "$hash" > hash;
				else
					hash=`cat hash`;
			fi
	fi

	mv hash "/var/www/html/movie/$movie_year/$movie_title";
	
	if [ ! -e "/var/www/html/movie/$movie_year/$movie_title/meta.xml" ]
			then
				mv meta.xml "/var/www/html/movie/$movie_year/$movie_title";
			else
				echo "`date` Error 99: error moving $movie_title's meta.xml to /var/www/html/movie/$movie_year/$movie_title";
	fi

	if [ ! -e "/var/www/html/movie/$movie_year/$movie_title/meta.page" ]
			then
				mv meta.page "/var/www/html/movie/$movie_year/$movie_title";
			else
				echo "`date` Error 99: error moving $movie_title's meta.page to /var/www/html/movie/$movie_year/$movie_title";
	fi

	movie_file_path=`find_largest_file .`;
	embed_subtitles "$movie_file_path";
	
	if [ ! -d "$current_permanent_storage/$movie_year" ]
		then
			if ( ! mkdir "$current_permanent_storage/$movie_year" )
				then
					echo "`date` Error 18: problem creating $current_permanent_storage/$movie_year for permanent storage";
			fi
	fi

	movie_file_name=`sed -Ee "s/.+\/(.+)$/\1/g" <<< "$movie_file_path"`;
	mv "$movie_file_path" "$current_permanent_storage/$movie_year";
	movie_db_entry="$hash $current_permanent_storage/$movie_year/$movie_file_name";
	echo "$movie_db_entry" >> "$movies_hashlist";
	page_string="$string_11$movie_title$string_12<h1>$movie_title</h1>$string_13$hash\">$string_14"'<!-- ELBETH LOGO GOES HERE -->'"$string_15";

	tell_status "Done processing $movie_title";
	touch done;

	## this is silly-but-necessary redundance -- if ever there was such a thing haha
	if [ ! -d "/var/www/html/movie/$movie_year/$movie_title" ]
		then
			echo "`date` Error 21: redundant_error_handling_caught_this -- dir: /var/www/html/movie/$movie_year/$movie_title doesn't exist";
	fi

	if [ ! -e "/var/www/html/movie/$movie_year/$movie_title/hash" ]
		then
			echo "`date` Error 22: redundant_error_handling_caught_this -- dir: /var/www/html/movie/$movie_year/$movie_title/hash doesn't exist";
	fi

	if [ ! -e "/var/www/html/movie/$movie_year/$movie_title/poster.jpg" ]
		then
			echo "`date` Error 24: redundant_error_handling_caught_this -- dir: /var/www/html/movie/$movie_year/$movie_title/poster.jpg doesn't exist";
	fi

	if [ ! -e "/var/www/html/movie/$movie_year/$movie_title/trailer.mp4" ]
		then
			echo "`date` Error 25: redundant_error_handling_caught_this -- dir: /var/www/html/movie/$movie_year/$movie_title/trailer.mp4 doesn't exist";
	fi
}

function post_processing(){
	if [ -e done ]
		then
			echo "error: repeat processing $movie_name caught, exitting"
			unlock_link;
			exit;
		else
			movie_year=`egrep -oe "\(.+\)$" <<< "$movie_name" | egrep -oe '[0-9]+'`;
			create_catalogue_entry "$movie_name" "$movie_year" "$calling_url";
	fi
}

function cleanup(){
	if [ -e done ]
		then
			cd "$temporary_working_dir"
			rm -r "$movie_dir"
		else
			echo "error: cleanup called with an unfinished download, exitting"
			unlock_link;
			exit;
	fi
}

function announce_processing(){
	create_url_hash;
	if ( ( ! grep -q "$url_hash" "$being_processed_movies_list" ) && ( ! grep -q "$url_hash" "$downloaded_movies_list" ) )
		then
			echo "$url_hash" >> "$being_processed_movies_list";
		else
			exit;
	fi
}

function commit_procession_completion(){
	echo "$url_hash" >> "$downloaded_movies_list";
	#
}

function main(){
	announce_processing;
	get_movie_page;
	extract_movie_name;
	create_download_dir;
	extract_poster_url;
	extract_torrent_url;
	extract_trailer_url;
	extract_meta_info;
	
	until [ "$poster_downloaded" == "true" ]
		do
			download_poster;
	done
	
	until [ "$trailer_downloaded" == "true" ]
		do
			download_trailer;
	done

	until [ "$torrent_file_downloaded" == "true" ]
		do
			download_torrent_file;
	done
	
	until [ "$torrent_downloaded" == "true" ]
		do
			download_torrent;
	done
	
	if ( [ "$poster_downloaded" == "true" ] && [ "$trailer_downloaded" == "true" ] && [ "$torrent_downloaded" == "true" ] && [ ! -e done ] )
		then
			post_processing;
			cleanup;
			commit_procession_completion;
	fi

	unlock_link;
	exit;
}

main;