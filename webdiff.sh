#!/bin/bash
minargs=1
dbfile="db.webdiff"
qfile="q.cleanup"
if [ $# != $minargs ]; then
    printf "Argument count must be $minargs, you provided $#\n"
    exit 1
fi

if [ ! -f "$dbfile" ]; then
	printf "$dbfile doesn't exist!\n"
	exit 1
fi

printf "Name#Seen date#Hash\n" > "$qfile"

if [ "$1" = "cleanup" ]; then
	printf "Cleaning up...\n"
	cleaned=0
	for l in `cat "$dbfile"`
	do
		if [ ! "$l" = "" ]; then
			tormdate="$(echo $l | cut -d "#" -f1)"
			tormname="$(echo $l | cut -d "#" -f2)"
			tormhash="$(echo $l | cut -d "#" -f3)"
			if [ ! -d "$l" ]; then
				printf "$l doesn't exist! Something fishy happened!\n"
				exit 2
			fi
			printf "$tormname#$(date -d @$tormdate)#$tormhash\n" >> "$qfile"
			rm -rf "$l/"
			rm -rf "www.$l/"
			cleaned=1
		fi
	done
	if [ "$cleaned" = "1" ]; then
		printf "Removed entries:\n\n"
	        cat "$qfile" | column -t -s "#"
       		printf "\n"
	else
		printf "No need to clean anything here\n"
	fi
	echo > "$dbfile"
	rm -f "$qfile"
	printf "Cleanup finished!\n"
	exit 0
fi

if [ "$1" = "list" ]; then
	if [ "$(cat $dbfile)" == "" ]; then
		printf "There are no downloaded sites!\n"
		rm -f "$qfile"
		exit 0
	else
		printf "So far, these sites have been downloaded:\n\n"
		for l in `cat "$dbfile"`
        	do
        	        if [ ! "$l" = "" ]; then
        	                tormdate="$(echo $l | cut -d "#" -f1)"
        	                tormname="$(echo $l | cut -d "#" -f2)"
                	        tormhash="$(echo $l | cut -d "#" -f3)"
                	        printf "$tormname#$(date -d @$tormdate)#$tormhash\n" >> "$qfile"
                	fi
        	done
		cat "$qfile" | column -t -s "#"
	fi
	rm -f "$qfile"
	exit 0
fi

printf "Webpage modificiation detector\n"

curdate="$(date +""%s"")"
curid="$(echo $curdate | sha256sum | cut -d " " -f1)"
printf "ID: $curid\n"

printf "\nDownloading $1...\n\n"
wget -nv -E -H -k -K -p "$1"
if [ -d "$1" ]; then
	printf "\nReorganizing files...\n"
	mv "www.$1" "$1"/
	mv "$1" "$curdate#$1#$curid"
	
	printf "\nDownloaded, writing to arbitrary flatfile database ($dbfile)"
	printf "$curdate#$1#$curid\n" >> "$dbfile"
else
	printf "Downloading $1 was unsuccessful, quitting...\n"
	exit 1
fi

## == End script == ##
printf "\n"
