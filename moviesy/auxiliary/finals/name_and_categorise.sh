#!/bin/bash

# call this script while in the directory you want to name and categorise

series_name="$(pwd 2> /dev/null)";
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

				index=$(egrep -ioe 's[0-9]{2}e[0-9]{2}' <<< "$file" | tr [a-z] [A-Z]);
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
		if ( [ ! -z "$size" ] && [ "$size" -lt "1024" ] )
			then
				rm -r "rogue"
		fi
		
fi