#!/bin/bash
minargs=1
dbfile="db.webdiff"
qfile="q.cleanup"
dateformat="+%d/%m/%Y %H:%M"

if [ $# != $minargs ]; then
    printf "Argument count must be $minargs, you provided $#\n"
    exit 1
fi

if [ ! -f "$dbfile" ]; then
	printf "$dbfile doesn't exist!\n"
	exit 1
fi

printf "URL#Date (DD/MM/YYYY)#Name + Date hash#Content hash\n" > "$qfile"

if [ "$1" = "cleanup" ]; then
	printf "Cleaning up...\n"
	cleaned=0
	for l in `cat "$dbfile"`
	do
		if [ ! "$l" = "" ]; then
			tormdate="$(echo $l | cut -d "#" -f1)"
			tormname="$(echo $l | cut -d "#" -f2)"
			tormhash="$(echo $l | cut -d "#" -f3)"
			tormchash="$(echo $l | cut -d "#" -f4)"
			if [ ! -d "$l" ]; then
				printf "$l doesn't exist! Something fishy happened!\n"
				exit 2
			fi
			printf "$tormname#$(date "$dateformat" -d @$tormdate)#$tormhash#$tormchash\n" >> "$qfile"
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
		for l in `cat "$dbfile"`
        	do
        	        if [ ! "$l" = "" ]; then
        	                tolsdate="$(echo $l | cut -d "#" -f1)"
        	                tolsname="$(echo $l | cut -d "#" -f2)"
                	        tolshash="$(echo $l | cut -d "#" -f3)"
				tolschash="$(echo $l | cut -d "#" -f4)"
                	        printf "$tolsname#$(date "$dateformat" -d @$tolsdate)#$tolshash#$tolschash\n" >> "$qfile"
                	fi
        	done
		cat "$qfile" | column -t -s "#"
	fi
	rm -f "$qfile"
	exit 0
fi

printf "Webpage modificiation detector\n"

curdate="$(date +""%s"")"
curid="$(echo $1#$curdate | sha256sum | cut -d " " -f1)"
printf "ID: $curid\n"

printf "\nDownloading $1...\n\n"
wget -nv -E -H -k -K -p "$1"
if [ -d "$1" ]; then
	printf "\nReorganizing files...\n"
	if [ -d "www.$1" ]; then
		mv "www.$1" "$1"/
	fi
	contenthash="$(find $curdate#$1#$curid -type f -exec cat {} \; | sha256sum | cut -d ' ' -f1)"
	mv "$1" "$curdate#$1#$curid#$contenthash"
	printf "\nDownloaded, writing to arbitrary flatfile database ($dbfile)"
	printf "$curdate#$1#$curid#$contenthash\n" >> "$dbfile"
else
	printf "Downloading $1 was unsuccessful, quitting...\n"
	exit 1
fi

echo "Latest $1:"


## == End script == ##
printf "\n"
