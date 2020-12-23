#!/bin/bash

/usr/lib/moviesy/updater_wrapper.sh &
#/usr/lib/moviesy/update_series_daemon.sh &
#/usr/lib/moviesy/new_medium_detect_daemon.sh &
#/usr/lib/moviesy/local_load_processor_daemon.sh &
/usr/lib/moviesy/dnsmasq_related.sh & 
#/usr/lib/moviesy/filfil.sh &
/usr/lib/moviesy/reprocess_movies_daemon.sh &