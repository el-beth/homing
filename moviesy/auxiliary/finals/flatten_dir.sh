#!/bin/bash

# this script will flatten the directory hierarchy of the pwd so call it after successfully navigating to the desired directory

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
		echo "Error: couldn't create directory 'neat'";
		exit 1;
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
		echo "Error: couldn't create directory 'junk'";
		exit 2;
fi


while read directory 
	do
		if ([ "$directory" != "./neat" ] && [ "$directory" != "./junk" ])
			then
				mv "$directory" --no-clobber --target-directory="junk";
		fi

done <<< "$directories"

small_files="$(find . -size -10971520c -type f 2> /dev/null)"; ## less than ~10M in size and files, not directories - since not specifying f results in non-empty directories being included in the return

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
				rm -r "$dir";
		fi
done
