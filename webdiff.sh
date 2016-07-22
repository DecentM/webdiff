#!/bin/bash
minargs=1
dbfile="db.webdiff"
dateformat="+%d/%m/%Y %H:%M.%S"
tableheader="URL#Date (D/M/Y H:M.S)#Name + Date hash#Content hash#HTML hash"

if [ $# -lt $minargs ]; then
    printf "Argument count must be $minargs, you provided $#\n"
    exit 1
fi

if [ ! -f "$dbfile" ]; then
	touch "$dbfeil"
	exit 1
fi

function listdb {
	cat "$dbfile" | grep -i "$1"
}

function parsedb {
    printf "$tableheader\n"
    for g in `listdb $1`
    do
        tolsdate="$(echo $g | cut -d '#' -f1)"
        tolsname="$(echo $g | cut -d '#' -f2)"
        tolshash="$(echo $g | cut -d '#' -f3)"
        tolschash="$(echo $g | cut -d '#' -f4)"
        tolshhash="$(echo $g | cut -d '#' -f5)"
        printf "$tolsname#$(date "$dateformat" -d @$tolsdate)#$tolshash#$tolschash#$tolshhash\n"
    done
}

function parsedb_table {
    parsedb "$1" | column -t -s "#"
}

function cleanup {
	cleaned=0
    printf "The following entries will be removed:\n"
    parsedb_table "$1"
    read -r -p "Proceed? [y/N] " response
        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
        then
            for l in `listdb "$1" | cut -d "#" -f3`
            do
                rm -rf *$l*
            done
            echo > "$dbfile"
        else
            do_something_else
        fi
}

function downloadsite {
	printf "Downloading $1...\n"
	wget -q -E -H -k -K -p "$1"
}

function organize {
	if [ -d "$1" ]; then
	        printf "Reorganizing files and directories...\n"
	        if [ -d "www.$1" ]; then
	                mv "www.$1" "$1"/
	        fi
	        contenthash="$(find $1 -type f -exec cat {} \; | sha256sum | cut -d ' ' -f1)"
	        mv "$1" "$curdate#$1#$curid#$contenthash"
	        htmlhash="$(find $curdate#$1#$curid#$contenthash -name "*.html" -type f -exec cat {} \; | sha256sum | cut -d ' ' -f1)"
	        mv "$curdate#$1#$curid#$contenthash" "$curdate#$1#$curid#$contenthash#$htmlhash"
	        printf "Downloaded, writing to arbitrary flatfile database: $dbfile\n"
	        printf "$curdate#$1#$curid#$contenthash#$htmlhash\n" >> "$dbfile"
	else
	        printf "There was nothing to organize. Are you sure you downloaded a vaild website?\n"
	        exit 1
	fi
}

if [ "$1" = "clean" ]; then
	cleanup "$2"
	exit 0
fi

if [ "$1" = "list" ]; then
	if [ "`listdb "$2"`" == "" ]; then
		printf "There are no downloaded sites matching your query!\n"
		exit 0
	else
		parsedb_table "$2"
	fi
	exit 0
fi

curdate="$(date +""%s"")"
curid="$(echo $1#$curdate | sha256sum | cut -d " " -f1)"

SCRIPTPATH=$(cd $(dirname $0); pwd -P)

downloadsite "$1"
organize "$1"

cbeforedate="0"
for l in `cat "$dbfile" | grep -i "$1"`
do
	if [ ! "$l" = "" ]; then
		cdate="$(echo $l | cut -d '#' -f1)"
		cname="$(echo $l | cut -d '#' -f2)"
		chash="$(echo $l | cut -d '#' -f3)"
		cchash="$(echo $l | cut -d '#' -f4)"
		if [ "$cbeforedate" -gt "$cdate" ]; then
			newest="$chash"
		fi
		cbeforedate="$cdate"
	fi
done

if [ "$(cat $dbfile | wc -l)" -gt "2" ]; then
	newest_n="$(($(cat $dbfile | wc -l)))"
	secondnewest_n="$(($(cat $dbfile | wc -l) - 1))"
	newest_chash=$(head -n"$newest_n" $dbfile | tail -1 | cut -d '#' -f4)
	secondnewest_chash=$(head -n"$secondnewest_n" $dbfile | tail -1 | cut -d '#' -f4)
	newest_hhash=$(head -n"$newest_n" $dbfile | tail -1 | cut -d '#' -f5)
        secondnewest_hhash=$(head -n"$secondnewest_n" $dbfile | tail -1 | cut -d '#' -f5)

	if [ "$secondnewest_chash" != "" ] && [ "$newest_chash" != "" ]; then
		if [ "$secondnewest_chash" = "$newest_chash" ]; then
			printf "There has been no change since last time\n"
		else
			printf "The site has changed since last time\n"
			if [ "$secondnewest_hhash" = "$newest_hhash" ]; then
				printf "This was a resource change, the HTML is the same!\n"
			else
				printf "There is a change in HTML, but resources could have been altered as well!\n"
			fi
			#echo "$SCRIPTPATH clean"
		fi
	else
		printf "There has been an internal error, quitting..."
		exit 2
	fi
else
	printf "We dont have enough copies of the site yet to compare\n"
fi

## == End script == ##
printf "\n"