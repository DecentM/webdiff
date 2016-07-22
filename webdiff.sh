#!/bin/bash
OPTIND=1
minargs=1
dbfile="db.webdiff"
dateformat="+%d/%m/%Y %H:%M.%S"
tableheader="URL#Date (D/M/Y H:M.S)#Name + Date hash#Content hash#HTML hash"

function msg {
    case "$1" in
        0) sev="Debug";;
        1) sev="Info";;
        2) sev="Error";;
        3) sev="Critical";;
    esac
    if [ "$sev" = "Debug" ] && $verbose || [ "$sev" != "Debug" ]; then
        printf "$(date "$dateformat"): [$sev] $2\n"
    fi
    case "$1" in
        2)  exit 1
            show_help 1
            ;;
        3)  exit 2;;
    esac
}

function show_help {
    usage="Usage: $0 -[vh] <list|clean|[url]> [url]\n"
    if [ "$1" = "0" ]; then
        msg "0" "Showing long help"
        printf "webdiff - track changes beween web pages across time\n\n"
        printf "$usage"
        printf "Examples:\n"
        printf "\t$0 google.com - Download a webpage and if applicable, compare to the previously downloaded one\n"
        printf "\n\t$0 list -  List all previously downloaded sites\n"
        printf "\t$0 list gith - List previously downloaded version of all sites that contain the character sequence \"gith\"\n"
        printf "\n\t$0 clean -  Delete all previously downloaded sites\n"
        printf "\t$0 clean google - Delete all downloaded versions of all sites that contain the word \"google\"\n"
    else
        msg "0" "Showing short help"
        printf "$usage"
    fi
    msg "0" "Help printing complete"
}

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
    if [ "$1" = "" ]; then
        msg "0" "Search term is empty"
        s="all"
    else
        s="$1"
    fi
    msg "0" "Parsing $dbfile for $s"
    parsedb "$1" | column -t -s "#"
    msg "0" "$(($(listdb $1 | wc -l) - 1)) results found"
    msg "0" "$dbfile parsed and printed as a table"
}

function cleanup {
	cleaned=0
    if [ "$(listdb $1)" = "" ]; then
        msg "2" "There's nothing to clean"
    fi
    printf "The following entries will be removed:\n"
    msg "0" "Parsing $dbfile"
    parsedb_table "$1"
    msg "0" "Pausing for confirmation"
    read -r -p "Proceed? [y/N] " response
        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
        then
            for l in `listdb "$1" | cut -d "#" -f3`
            do
                msg "0" "Recursively removing $(parsedb $1 | grep -i $l | cut -d "#" -f1) directory"
                rm -rf *$l*
            done
            echo > "$dbfile"
        else
            msg "2" "Aborted"
        fi
}

function downloadsite {
	msg "1" "Downloading $1..."
	wget -q -E -H -k -K -p "$1"
}

function organize {
	if [ -d "$1" ]; then
	        msg "1" "Reorganizing files and directories..."
	        if [ -d "www.$1" ]; then
	                mv "www.$1" "$1"/
	        fi
	        contenthash="$(find $1 -type f -exec cat {} \; | sha256sum | cut -d ' ' -f1)"
	        mv "$1" "$curdate#$1#$curid#$contenthash"
	        htmlhash="$(find $curdate#$1#$curid#$contenthash -name "*.html" -type f -exec cat {} \; | sha256sum | cut -d ' ' -f1)"
	        mv "$curdate#$1#$curid#$contenthash" "$curdate#$1#$curid#$contenthash#$htmlhash"
	        msg "0" "Downloaded, writing to arbitrary flatfile database: $dbfile"
	        printf "$curdate#$1#$curid#$contenthash#$htmlhash\n" >> "$dbfile"
	else
	        msg "3" "There was nothing to organize. Either the website reditected, or there was an internal error"
	fi
}

function compare {
    if [ -z "$1" ] || [ -z "$2" ]; then
        return 0 #error
    else
        if [ "$1" = "$2" ]; then
            return 1 #match
        else
            return 2 #difference
        fi
    fi
}

function searchnewest {
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
}

function urlvalid {
    msg "0" "Validating $1"
    resp="$(curl -s --head "$1" | head -n 1 | grep "HTTP/1.[01] [23]..")"
    msg "0" "URL response was: $resp"
    if [ "$resp" != "" ]; then
        msg "0" "URL gives a response"
        return $(true)
    else
        msg "0" "URL doesn't give a response"
        return $(false)
    fi
}
# == USERSPACE == #

function clean {
    cleanup "$1"
    exit 0
}

function help {
    show_help 0
    exit 0
}

function list {
	if [ "`listdb "$1"`" == "" ]; then
		msg "2" "There are no downloaded sites matching your query!"
	else
		parsedb_table "$1"
	fi
	exit 0
}

verbose=false
while getopts "vdh?:" opt; do
    case "$opt" in
        h|\?)
            show_help 0
            shift $((OPTIND-1))
            [ "$1" = "--" ] && shift
            exit 0
            ;;
        v|d)
            verbose=true
            msg "0" "Running on verbose mode"
            shift $((OPTIND-1))
            [ "$1" = "--" ] && shift
            ;;
    esac
done

if [ $# -lt $minargs ]; then
    msg "3" "Argument count must be $minargs, you provided $#\n"
fi

if [ ! -f "$dbfile" ]; then
    msg "0" "Creating $dbfile"
	touch "$dbfile"
fi

#if [ "$1" = "clean" ]; then
#	cleanup "$2"
#	exit 0
#fi
#
#if [ "$1" = "help" ]; then
#	show_help 0
#	exit 0
#fi
#
#if [ "$1" = "list" ]; then
#	if [ "`listdb "$2"`" == "" ]; then
#		msg "2" "There are no downloaded sites matching your query!\n"
#	else
#		parsedb_table "$2"
#	fi
#	exit 0
#fi

curdate="$(date +""%s"")"
curid="$(echo $1#$curdate | sha256sum | cut -d " " -f1)"
msg "0" "All arguments right now: $@"

if urlvalid "$1"; then
    msg "0" "URL validation succeeded, downloading..."
    downloadsite "$1"
    organize "$1"
    searchnewest
    if [ "$(cat $dbfile | wc -l)" -gt "2" ]; then
        newest_n="$(($(cat $dbfile | wc -l)))"
        secondnewest_n="$(($(cat $dbfile | wc -l) - 1))"
        newest_chash=$(head -n"$newest_n" $dbfile | tail -1 | cut -d '#' -f4)
        secondnewest_chash=$(head -n"$secondnewest_n" $dbfile | tail -1 | cut -d '#' -f4)
        newest_hhash=$(head -n"$newest_n" $dbfile | tail -1 | cut -d '#' -f5)
        secondnewest_hhash=$(head -n"$secondnewest_n" $dbfile | tail -1 | cut -d '#' -f5)

        if [ "$secondnewest_chash" != "" ] && [ "$newest_chash" != "" ]; then
            if [ "$secondnewest_chash" = "$newest_chash" ]; then
                msg "1" "There has been no change since last time"
            else
                printf "The site has changed since last time\n"
			if [ "$secondnewest_hhash" = "$newest_hhash" ]; then
				msg "1" "This was a resource change, the HTML is the same!"
			else
				msg "1" "There is a change in HTML, but resources could have been altered as well!"
			fi
			#echo "$SCRIPTPATH clean"
		fi
	else
		msg "3" "There has been an internal error, quitting..."
	fi
    else
        msg "2" "We don't have enough copies of the site yet to compare"
    fi
    exit 0
else
    msg "0" "URL validation failed, trying to run functions..."
fi

msg "0" "Running function as command: $@"
eval "$@"
if [ "$?" = 0 ]; then
    msg "0" "Running \"$@\" was successful"
else
    msg "2" "Running \"$@\" was unsuccessful, please check your arguments!"
fi
msg "0" "Shifting arguments"
shift $((OPTIND-1))
[ "$1" = "--" ] && shift
msg "0" "Remaining arguments: $@"

## == End script == ##
printf "\n"
