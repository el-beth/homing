#!/bin/bash

printf "Content-type: text/html\n\n";

calling_arg="$QUERY_STRING";
session=$(sed -E 's/^query([A-Z0-9 _\.]{3,15})=.+$/\1/gi' <<< "$calling_arg");
headless_query="$(sed -E 's/^query[A-Z0-9 _\.]{3,15}=(.+)/\1/gi' <<< "$calling_arg")";
page="";

iterated="";

cd "/var/www/html/movie";
preamble='<!DOCTYPE html><html><head><link rel="shortcut icon" href="http://mov.ez/img/favicon.ico"><link rel="stylesheet" type="text/css" href="http://mov.ez/css/series-specific.css"><link rel="stylesheet" type="text/css" href="http://mov.ez/css/main.css"><title>mov.ez</title></head><body><div class="container"><div class="header neu-passive"><a href="http://mov.ez/"><div class="home_button neu"><img src="http://mov.ez/img/home.png"></div></a><div class="other-offerings"><div class="offerings-container"><a href="http://mov.ez/cgi-bin/moviesy_series/main_dl.sh?session='"$session"'"><div class="offering neu"><img src="http://mov.ez/img/tv-100.png"></div></a><a href="http://mov.ez/cgi-bin/moviesy_feature/main_dl.sh?page=1&session='"$session"'"><div class="offering neu"><img src="http://mov.ez/img/movies-100.png"></div></a><a href="http://mov.ez/cgi-bin/moviesy_korean/main_dl.sh?session='"$session"'"><div class="offering neu"><img src="http://mov.ez/img/korean.png"></div></a></div></div><div class="search_bar"><form action="http://mov.ez/cgi-bin/search_feature_dl.sh" method="get" enctype="application/x-www-form-urlencoded" autocomplete="off" novalidate><input class="neu" type="text" placeholder="Search" name="query'"$session"'"><img class="search_icon_style" src="http://mov.ez/img/search_icon.png"></form></div></div><div class="landing neu-passive">';
if [ ! -z "$QUERY_STRING" ]
	then
		matching_regex=$(sed -E 's/ /\.\+/gi' <<< "$headless_query" | sed -E 's/^/\.\+/g' | sed -E 's/$/\.\*/g' | sed -E 's/(\.\+)+/\.\+/g');
		finds=$(find . -maxdepth 2 -mindepth 1 -type d  -regextype egrep -iregex "$matching_regex");
		if [ -z "$finds" ]
			then
				matching_regex=$(sed -E -f /usr/lib/cgi-bin/prepscr.sed <<< "$headless_query");
				finds=$(find . -maxdepth 2 -mindepth 1 -type d  -regextype egrep -iregex "$matching_regex");
		fi

		if [ ! -z "$finds" ]
			then
				while read dir
					do
						if [ -d "$dir" ]
							then
								dir="$(sed -E 's/^\.\///gi' <<< "$dir")";
								dir_pure="$dir";
								movie_name="$(sed -E 's/\/$//g' <<< "$dir" | sed -E 's/.+\///g')";
								iterated="$iterated"'<a href="http://mov.ez/cgi-bin/moviesy_feature/loader_dl.sh?/var/www/html/movie/'"$dir"'&session='"$session"'"><div class="card neu-passive"><div class="card-img neu_inset"><img src="'"http://mov.ez/movie/$dir/poster.jpg"'"></div><div class="card-button neu_inset"><span>'"$movie_name"'</span></div></div></a>';
						fi
				done <<< "$finds"
			else
				iterated="$iterated"'<center><h1 class="neu" style="margin: 10px; border-r"a>Nothing Found!</br>search again or click <a href="http://mov.ez/cgi-bin/moviesy_feature/main_dl.sh?page=1&session='"$session"'"><span	style="color: cyan;">here</span></a> to go back to the catalogue</h1></center>'
		fi
		footer='</div></div></body></html>';

		page="$preamble""$iterated""$footer";

		echo "$page"
fi

