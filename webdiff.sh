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
		else
			printf "No need for cleaning here\n"
		fi
	done
	printf "Removed entries:\n\n"
	cat "$qfile" | column -t -s "#"
	printf "\n"
	echo > "$dbfile"
	printf "Cleanup finished!\n"
	exit 0
fi

if [ "$1" = "list" ]; then
	printf "So far, these sites have been downloaded:"
fi

printf "Webpage modificiation detector\n"

curdate="$(date +""%s"")"
curid="$(echo $curdate | sha256sum | cut -d " " -f1)"
printf "ID: $curid\n"

printf "\nDownloading $1...\n\n"
wget -nv -E -H -k -K -p "$1"

printf "\nReorganizing files...\n"
mv "www.$1" "$1"/
mv "$1" "$curdate#$1#$curid"

printf "\nDownloaded, writing to arbitrary flatfile database ($dbfile)"
printf "$curdate#$1#$curid\n" >> "$dbfile"


## == End script == ##
printf "\n"
