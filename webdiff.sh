#!/bin/bash
minargs=1
dbfile="db.webdiff"
if [ $# != $minargs ]; then
    printf "Argument count must be $minargs, you provided $#\n"
    exit 1
fi

if [ ! -f "$dbfile" ]; then
	printf "$dbfile doesn't exist!\n"
	exit 1
fi

if [ "$1" = "cleanup" ]; then
	printf "Cleaning up...\n"
	for l in `cat "$dbfile"`
	do
		tormdate="$(echo $l | cut -d "#" -f1)"
		tormname="$(echo $l | cut -d "#" -f2)"
		tormhash="$(echo $l | cut -d "#" -f3)"
		printf "I want to remove $l\n"
		if [ ! -d "$l" ]; then
			printf "$tormname doesn't exist! Something fishy happened!\n"
			exit 2
		fi
		printf "Removing $torm and www.$torm\n"
		printf "Seen date: $(date -d @$tormdate)"
		#rm -rf "$torm"
		#rm -rf "www.$torm"
	done
	printf "Cleanup finished!\n"
	exit 0
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
printf "$curdate#$1#$curid" >> "$dbfile"


## == End script == ##
printf "\n"
