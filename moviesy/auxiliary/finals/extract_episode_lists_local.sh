#!/bin/bash

# this script will be called with a series directory, it'll verify that the calling string is a directory,
# then continue to finally produce a list that is the list of episode indexes in the directory, assuming every file in the 
# working directory is a video file and every directory is a season container

calling_string="$1"; # this has to be an absolute path or relative to where the caller is at time of calling
working_dir=""; # globalisation of this variable, once calling string has been verified as a directory, this will contain
               # the calling_string
episodes="";

function verify_calling_string(){
	if [ ! -d "$calling_string" ]
		then
			echo "error # extract_episode_lists_local.sh # : \$calling_string doesn't identify a directory";
			exit 1;
		else
			working_dir="$(sed -E 's/[\/]*$//g' <<< "$calling_string")"; # stripping calling_string of all trailing slashes
	fi
}

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
	verify_calling_string;
	navigate_to_working_dir;

	episodes="$(find . -type f -regextype egrep -iregex '.+S[0-9]{2}E[0-9]{2}.+' 2> /dev/null | sed -E 's/^\.\/Season [0-9]+\/.+(S[0-9]{2}E[0-9]{2}).+\.[0-9A-Z]{2,5}$/\1/gi' | egrep -ioe 'S[0-9]{2}E[0-9]{2}' | sort -V)";

	if [ -z "$episodes" ]
		then
			echo "error # extract_episode_lists_local.sh #: extracting episode IDs failed";
			exit 1;
	fi

	echo "$episodes";
}

main;