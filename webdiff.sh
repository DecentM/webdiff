#!/bin/bash
minargs=1
if [ $# != $minargs ]; then
    printf "Argument count must be $minargs, you provided $#\n"
    exit 1
fi

curdate="$(date +""%s"")"
curid="$(echo $curdate | sha256sum | cut -d " " -f1)"
printf "ID: $curid\n"

wget -nv -E -H -k -K -p "$1"
mv "www.$1" "$1"/
mv "$1" "$1#$curid"

printf "$curdate#$1#$curid"


## == End script == ##
printf "\n"
