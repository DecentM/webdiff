#!/bin/bash
minargs=1
dbfile="db.webdiff"
qfile="q.cleanup"
dateformat="+%d/%m/%Y %H:%M.%S"

if [ $# != $minargs ]; then
    printf "Argument count must be $minargs, you provided $#\n"
    exit 1
fi

if [ ! -f "$dbfile" ]; then
	printf "$dbfile doesn't exist!\n"
	exit 1
fi

printf "URL#Date (DD/MM/YYYY)#Name + Date hash#Content hash#HTML hash\n" > "$qfile"

if [ "$1" = "clean" ]; then
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
			if [ -d "www.$1" ]; then
				rm -rf "www.$l/"
			fi
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
wget -q -E -H -k -K -p "$1"
if [ -d "$1" ]; then
	printf "\nReorganizing files and directories...\n"
	if [ -d "www.$1" ]; then
		mv "www.$1" "$1"/
	fi
	contenthash="$(find -name $curdate#$1#$curid* -type f -exec cat {} \; | sha256sum | cut -d ' ' -f1)"
	mv "$1" "$curdate#$1#$curid#$contenthash"
	printf "\nDownloaded, writing to arbitrary flatfile database ($dbfile)\n"
	printf "$curdate#$1#$curid#$contenthash\n" >> "$dbfile"
else
	printf "Downloading $1 was unsuccessful, quitting...\n"
	exit 1
fi

cbeforedate="0"
for l in `cat "$dbfile" | grep -i "$1"`
do
	if [ ! "$l" = "" ]; then
		cdate="$(echo $l | cut -d "#" -f1)"
		cname="$(echo $l | cut -d "#" -f2)"
		chash="$(echo $l | cut -d "#" -f3)"
		cchash="$(echo $l | cut -d "#" -f4)"
		if [ "$cbeforedate" -gt "$cdate" ]; then
			newest="$chash"
		fi
		cbeforedate="$cdate"
	fi
done
printf "Newest copy of $1 is on this line: $(($(cat $dbfile | wc -l) - 1))"


## == End script == ##
printf "\n"
