#!/bin/bash

## THIS WILL BE CALLED BY APACHE AND WILL GENERATE DYNAMIC CONTENT 

printf "Content-type: text/html\n\n"

session=$(sed -E 's/^session=(.+)/\1/gi' <<< "$QUERY_STRING");

preamble='<!DOCTYPE html><html><head><link rel="shortcut icon" href="http://mov.ez/img/favicon.ico"><link rel="stylesheet" type="text/css" href="http://mov.ez/css/main.css"><link rel="stylesheet" type="text/css" href="http://mov.ez/css/series-specific.css"><title>mov.ez -- Series</title></head><body><div class="container"><div class="header neu-passive"><a href="http://mov.ez/"><div class="home_button neu"><img src="http://mov.ez/img/home.png"></div></a><div class="other-offerings"><div class="offerings-container"><a href="http://mov.ez/cgi-bin/moviesy_series/main_dl.sh?session='"$session"'"><div class="offering neu"><img src="http://mov.ez/img/tv-100.png"></div></a><a href="http://mov.ez/cgi-bin/moviesy_feature/main_dl.sh?page=1&session='"$session"'"><div class="offering neu"><img src="http://mov.ez/img/movies-100.png"></div></a><a href="http://mov.ez/cgi-bin/moviesy_korean/main_dl.sh?session='"$session"'"><div class="offering neu"><img src="http://mov.ez/img/korean.png"></div></a></div></div><div class="search_bar"><form action="http://mov.ez/cgi-bin/search_series_dl.sh" method="get" enctype="application/x-www-form-urlencoded" autocomplete="off" novalidate><input class="neu" type="text" placeholder="Search" name="query'"$session"'"><img class="search_icon_style" src="http://mov.ez/img/search_icon.png"></form></div></div><div class="landing neu-passive">'
iterated="";

cd /var/www/html/serial_english/;

for dir in *
	do
		if [ -d "$dir" ]
			then
				iterated="$iterated"'<a href="'"http://mov.ez/cgi-bin/moviesy_series/loader_dl.sh?name=$dir&session=$session"'"><div class="card neu-passive"><div class="card-img neu_inset"><img src="'"http://mov.ez/serial_english/$dir/poster.jpg"'"></div><div class="card-button neu_inset"><span>'"$dir"'</span></div></div></a>';
		fi
done

footer='</div></div></body></html>';

page="$preamble""$iterated""$footer";

echo "$page"