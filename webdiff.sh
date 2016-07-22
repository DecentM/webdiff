#!/bin/bash
OPTIND=1
minargs=1
dbfile="db.webdiff"
dateformat="+%d/%m/%Y %H:%M.%S"
tableheader="URL#Date (D/M/Y H:M.S)#Name + Date hash#Content hash#HTML hash"
tmpdir="/tmp/webdiff"

function msg {
    case "$1" in
        0) sev="Debug";;
        1) sev="Info";;
        2) sev="Error";;
        3) sev="Critical";;
    esac
    if [ "$sev" = "Debug" ] && $verbose || [ "$sev" != "Debug" ]; then
        printf "$(date "$dateformat"): [""$sev""] $(eval echo "$2")\n"
    fi
    case "$1" in
        2)  over 1
            show_help 1
            ;;
        3)  over 2;;
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
    msg "1" "The following entries will be removed:"
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
                mv "$dbfile" "tmp.$dbfile"
                sed "/$l/d" "tmp.$dbfile" > "$dbfile"
                rm -f "tmp.$dbfile"
            done
        else
            msg "2" "Aborted"
        fi
}

function downloadsite {
	msg "1" "Downloading $1..."
    mkdir -p "$tmpdir"
    cd "$tmpdir"
    msg "0" "Switched to $(pwd)"
	wget -e robots=off -q -E -H -k -K -p "$1"
    cd - > /dev/null
    msg "0" "Switched to $(pwd)"
}

function organize {
msg "1" "Reorganizing files and directories..."
mv "$tmpdir" "$1"
	if [ -d "$1" ]; then
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
        return $(true)
    else
        return $(false)
    fi
}

function over {
    msg "0" "Exiting with code $1"
    exit "$1"
}
# == USERSPACE FUNCTIONS == #

function clean {
    cleanup "$1"
    over 0
}

function help {
    show_help 0
    over 0
}

function list {
	if [ "`listdb "$1"`" == "" ]; then
		msg "2" "There are no downloaded sites matching your query!"
	else
		parsedb_table "$1"
	fi
	over 0
}

verbose=false
while getopts "vdh?:" opt; do
    case "$opt" in
        h|\?)
            show_help 0
            shift $((OPTIND-1))
            [ "$1" = "--" ] && shift
            over 0
            ;;
        v|d)
            verbose=true
            msg "0" "Running in verbose mode"
            shift $((OPTIND-1))
            [ "$1" = "--" ] && shift
            ;;
    esac
done

if [ $# -lt $minargs ]; then
    msg "2" "Argument count must be $minargs, you provided $#"
fi

if [ ! -f "$dbfile" ]; then
    msg "0" "Creating $dbfile"
	touch "$dbfile"
fi

curdate="$(date +""%s"")"
curid="$(echo $1#$curdate | sha256sum | cut -d " " -f1)"
msg "0" "All arguments right now: $@"

if urlvalid "$1"; then
    msg "0" "URL validation succeeded, downloading..."
    downloadsite "$1"
    organize "$1"
    #searchnewest "$1"
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
                msg "1" "The site has changed since last time"
			if [ "$secondnewest_hhash" = "$newest_hhash" ]; then
				msg "1" "This was a resource change, the HTML is the same!"
			else
				msg "1" "There is a change in HTML, but resources could have been altered as well!"
			fi
		fi
	else
		msg "3" "There has been an internal error, quitting..."
	fi
    else
        msg "1" "We don't have enough copies of the site yet to compare"
    fi
    over 0
else
    msg "0" "URL validation failed, trying to run functions..."
fi

msg "0" "Running function as command: $@"
eval "$@"
if [ "$?" = 0 ]; then
    msg "0" "Running \"$1\" was successful"
else
    msg "2" "Running \"$1\" was unsuccessful, please check your arguments!"
fi
msg "0" "Shifting arguments"
shift $((OPTIND-1))
[ "$1" = "--" ] && shift
msg "0" "Remaining arguments: $@"

## == End script == ##
#printf "\n"
