#!/bin/bash

# the relevance of this script has  dropped dramatically as I've discovered the original domain of EZTV
# i.e. much like yts.as, eztv.ag redirects to the latest domain, so use this script if all else fails.

# this is not a daemonised scripts like intened, there appears to be no need for that

# load the currently in use domain url from a config file
# if domain provided, check if domain is up and update to that domain if the domain is different from  current domain
# else progress with update
# fetch the current domains from eztvstatus.
# if there is a change in the primary domain, perform updates of all files -- all files are in subdirectories of
# /var/www/html/serial_english
#### this should only be done after a successful download of the homepage at the new domain

#### TODO

###### in case of a service downage on the primiary and fallback mirrors collected from eztvstatus.com, use the unblockit.app mirror as a fallback
###### this is a desperate act as this mirror is routinely several days behind the primary domain
# if there is a change in the mirror domains, log the change and exit
# 

serial_dir="/var/www/html/serial_english";
local_config_file="/usr/lib/moviesy/eztv_domain.conf";

count=0;
until ( [ "$(pwd)" == "$serial_dir" ] || [ "$count" -gt 5 ] )
	do
		cd "$serial_dir" || sleep 5;
done

if [ "$(pwd)" != "$serial_dir" ]
	then
		echo "error: can't navigate to $serial_dir" && exit 1;
fi

current_domain="$(cat "$local_config_file" | sed -E 's/\/*$//g')";
remote_domain="$(sed -E 's/\/*$//g' <<< "$1")";
files="$(find . -type f)";

if [ -z "$files" ]
	then
		echo "error: cant find files in $serial_dir" && exit 1;
fi

contain_eztv="$(while read line; do if ( egrep -q -i eztv "$line" ); then echo "$line"; fi;done <<< "$files")";

if [ -z "$contain_eztv" ]
	then
		echo "error: no files contain an eztv link" && exit 1;
fi

if [ ! -z "$remote_domain" ]
	then
		# update to provided domain
		primary_mirror="$remote_domain";
		primary_mirror_safe="$(sed -E -e 's/\//\\\//gi' -e 's/\./\\\./g' <<< "$primary_mirror")";
		if [ "$current_domain" != "$primary_mirror" ]
			then
				if (wget -q -O /dev/null "$primary_mirror")
				 	then 
				 		while read line
				 			do
				 				sed -i -E "s/(https?:\/\/[^\/]*eztv[^\/]*)/$primary_mirror_safe/gi" "$line" ;
				 		done <<< "$contain_eztv";

				 		echo "$primary_mirror" > "$local_config_file";
				 		echo "changed from $current_domain to $primary_mirror" && exit 0;
				 	else
				 		echo "error: couldn't update to $primary_mirror as the provided site appears down";
				fi
			else
				echo "status: domain doesn't need updating" && exit 0;
		fi
fi

status_page_content="$(wget -q -O - 'https://eztvstatus.com')";

if [ -z "$status_page_content" ]
	then
		echo "error: can't fetch eztvstatus.com page" && exit 1;
fi

primary_mirror="$(egrep -ioe '<a class="domainLink" href=".+' <<< "$status_page_content" | sed -E -e 's/.*href="([^" ]+).*/\1/gi' -e 's/\/*$//g' | head -n 1)";
primary_mirror_safe="$(sed -E -e 's/\//\\\//gi' -e 's/\./\\\./g' <<< "$primary_mirror")";
fallback_mirrors="$(egrep -ioe '<li>.*<a href="https?://[^"]+.*class="domainLink' <<< "$status_page_content" | sed -E -e 's/.*href="([^" ]+).*/\1/gi' -e 's/\/*$//g' | head -n 3)";
#fallback_mirrors_safe="$(sed -E -e 's/\//\\\//gi' -e 's/\./\\\./g'  <<< "$fallback_mirrors")";
fail="0";
if [ "$current_domain" != "$primary_mirror" ]
	then
		if (wget -q -O /dev/null "$primary_mirror")
		 	then 
		 		while read line
		 			do
		 				sed -i -E "s/(https?:\/\/[^\/]*eztv[^\/]*)/$primary_mirror_safe/gi" "$line";
		 		done <<< "$contain_eztv";

		 		echo "$primary_mirror" > "$local_config_file";
		 		echo "changed from $current_domain to $primary_mirror";
		 	else
		 		fail=$((++fail));
		 		echo "error: updating to $primary_mirror failed"
		 		while read sec_mirror
		 			do
		 				sec_mirror_safe="$(sed -E -e 's/\//\\\//gi' -e 's/\./\\\./g'  <<< "$sec_mirror")";
		 				if (wget -q -O /dev/null "$sec_mirror")
		 				 	then 
		 				 		while read line
		 				 			do
		 				 				sed -i -E "s/(https?:\/\/[^\/]*eztv[^\/]*)/$sec_mirror_safe/gi" "$line" ;
		 				 		done <<< "$contain_eztv";
		 				 		echo "$sec_mirror" > "$local_config_file";
		 				 		echo "changed from $current_domain to $sec_mirror" && exit;
		 				 	else
		 				 		echo "error: couldn't change from $current_domain to $sec_mirror" && fail=$((++fail));
		 				fi
		 		done <<< "$fallback_mirrors_safe"
		fi
	else
		echo "status: domain doesn't need updating" && exit 0;
fi

if [ "$fail" -ge "4" ]
	then
		echo "error: domain update failed" && exit 8;
fi