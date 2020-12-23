#!/bin/bash

# this script is a daemon
# it runs in the background and iterates over the contents of /var/www/attached - if any - 

sessions_attached_dir="/var/www/attached";
loaded_dir="/var/www/loaded";
loading_dir="/var/www/loading";

if [ ! -d "$loaded_dir" ]
	then
		mkdir "loaded_dir";
fi

movies_hash='/usr/lib/moviesy/movies_hash.list';
series_hash='/usr/lib/moviesy/series_hash.list';

if [ ! -d "$sessions_attached_dir" ]
	then
		echo "error: # local_load_processor_daemon.sh # sessions_attached_dir doesn't exist $sessions_attached_dir" && exit 1;
fi

count=0;

until ([ "$(pwd)" == "$sessions_attached_dir" ] || [ "$count" -gt "10" ])
	do
		cd "$sessions_attached_dir";
		sleep 1;
		count=$((++count));
done

if [ "$(pwd)" != "$sessions_attached_dir" ]
	then
		echo "error: # local_load_processor_daemon # cant navigate to $sessions_attached_dir" && exit;
fi

function process_queue(){
	session_local="$1";

	if [ ! -e "$loaded_dir/$session_local" ]
		then
			touch "$loaded_dir/$session_local";
			if [ ! -e "$loaded_dir/$session_local" ]
				then
					echo "error: # local_load_processor_daemon.sh # can't create loaded file queue" && return;
			fi
	fi

	if [ ! -e "/var/www/sessions/$session_local" ]
		then
			echo "error: # local_load_processor_daemon # $session_local is not a real session" && return 1;
	fi

	device=$(cat /var/www/attached/$session_local);

	if ([ -z "$device" ] || [ ! -b "$device" ])
		then
			echo "error: # local_load_processor_daemon # might have suffered an emergence shutdown" && return 33;
	fi

	device_mountpoint="$(lsblk -o MOUNTPOINT "$device" | egrep -ve '^(MOUNTPOINT|)$')";

	if [ "$(lsof -Fc "$device" | egrep -oe '^c.+$')" == 'ccp' ]
		then
			return;
	fi

	if [ ! -d "$device_mountpoint/mov.ez" ]
		then
			mkdir "$device_mountpoint/mov.ez";
	fi

	hashes=$(cat /var/www/sessions/$session_local);

	if [ -z "$hashes" ]
		then
			echo "error: # local_load_processor_daemon # $session_local hasn't queued anything yet" && return 2;
	fi

	while read hashline
		do
			if [ ! -b "$(cat "/var/www/attached/$session_local")" ]
				then
					return
			fi
			if ( grep -q "$hashline" "$loaded_dir/$session_local")
				then
					continue;
			fi

			matchedLine=$(grep "$hashline" "$movies_hash");
			if [ ! -z "$matchedLine" ]
				then
					hash=$(cut -c -32 <<< "$matchedLine");
					moviePath=$(cut -c 34- <<< "$matchedLine");
					movieName=$(sed -E "s/^.+\/([^\/]+)$/\1/g" <<< "$moviePath");

					device_freespace="$(df --output=avail "$device" | tail -n 1 | egrep -ioe '[0-9]+')";
					space_needed="$(du "$moviePath" | egrep -ioe '^[0-9]+')";

					if [ "$space_needed" -gt "$device_freespace" ]
						then
							if (zenity --height=250 --width=700 --title="Not Enough Space" --question --ok-label="YES" --cancel-label="NO" --text='<span foreground="#10FF10" face="sans" size="xx-large"><b>There seems to be a shortage of space while processing '"$session_local""'s"' queue</b>\n\n\nIf you want to free space click YES\n\nor \n\nIf you want to stop loading, click NO</span>')
								then
									nautilus "$device_mountpoint" 2> /dev/null &

									until [ "$device_freespace" -ge "$space_needed" ]
										do
											sleep 2;
											device_freespace="$(df --output=avail "$device" | tail -n 1 | egrep -ioe '[0-9]+')";
									done

								else
									firefox "http://adm.in/cgi-bin/emergency_stop?session=$session_local" || chromium "http://adm.in/cgi-bin/emergency_stop?session=$session_local"&
							fi

					fi

					cp "$moviePath" "$device_mountpoint/mov.ez/$movieName" && echo "$hashline" >> "$loaded_dir/$session_local";
				else
					serialMatchedLine=$(grep "$hashline" "$series_hash");
					if [ ! -z "$serialMatchedLine" ]
						then
							hash=$(cut -c -32 <<< "$serialMatchedLine");
							moviePath=$(cut -c 34- <<< "$serialMatchedLine");
							serial_name=$(sed -e "s/^.\+\/\(.\+\)\/.\+\/.\+$/\1/g" <<< "$moviePath");
							season=$(sed -e "s/^.\+\/\(.\+\)\/.\+$/\1/g" <<< "$moviePath");
							episode=$(sed -e "s/^.\+\/\(.\+\)$/\1/g" <<< "$moviePath");
							if [ ! -d "$device_mountpoint/mov.ez/$serial_name" ]
								then
									mkdir "$device_mountpoint/mov.ez/$serial_name";
							fi

							if [ ! -d "$device_mountpoint/mov.ez/$serial_name/$season" ]
								then
									mkdir "$device_mountpoint/mov.ez/$serial_name/$season";
							fi

							if [ ! -d "$device_mountpoint/mov.ez/$serial_name/$season" ]
								then
									echo "couldn't create \"$device_mountpoint/mov.ez/$serial_name/$season\"" && return;
							fi

							device_freespace="$(df --output=avail "$device" | tail -n 1 | egrep -ioe '[0-9]+')";
							space_needed="$(du "$moviePath" | egrep -ioe '^[0-9]+')";

							if [ "$space_needed" -gt "$device_freespace" ]
								then
									if (zenity --height=250 --width=700 --title="Not Enough Space" --question --ok-label="YES" --cancel-label="NO" --text='<span face="sans" size="large">There seems to be a shortage of space while processing '"$session_local""'s"' queue\n\nIf you want to free space click YES\n\nor \n\nIf you want to stop loading, click NO</span>')
										then
											nautilus "$device_mountpoint" 2> /dev/null &

											until [ "$device_freespace" -ge "$space_needed" ]
												do
													sleep 3;
													device_freespace="$(df --output=avail "$device" | tail -n 1 | egrep -ioe '[0-9]+')";
											done

										else
											firefox "http://adm.in/cgi-bin/emergency_stop?session=$session_local" || chromium "http://adm.in/cgi-bin/emergency_stop?session=$session_local"&
									fi

							fi

							cp "$moviePath" "$device_mountpoint/mov.ez/$serial_name/$season/$episode" && echo "$hashline" >> "$loaded_dir/$session_local";
							
					fi
			fi
	done <<< "$hashes"

	rm "$loading_dir/$session_local";

}

while (true)
	do
		for session in *
			do
				if ([ -f "$session" ] && [ -b "$(cat "$session")" ] && [ ! -e "$loading_dir/$session" ])
					then
						device=$(cat "$session");
						users_of_device=$(lsof -Fc "$device" | egrep -oe '^c.+$');
						
						if [ "$users_of_device" == "ccp" ]
							then
								continue;
						fi
						touch "$loading_dir/$session" && process_queue "$session" &
				fi
				sleep 2;
		done
		sleep 2;
done