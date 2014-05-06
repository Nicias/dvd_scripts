#!/bin/bash

if [ -z "$2" ]; then 
              /bin/echo usage: $0 rip-dir season-dir [suffix] 
              exit
fi


if [ -n "$3" ]; then
	SUFFIX="${3}.mkv"
else
	SUFFIX="mkv"
fi

echo $SUFFIX


declare -a ripfiles=(`/bin/ls ${1}/*.mkv | /usr/bin/sort -V`)
numfiles=${#ripfiles[@]}

seasondir=`/usr/bin/readlink -f ${2}`
basename=`/bin/echo $seasondir | /bin/sed -e 's:/Season:.S:'  -e 's/\/.*\///g'`

declare -a alreadylinked=(`/bin/ls $seasondir/$basename*.mkv  | /usr/bin/sort -V -r`)
lastlinked=`/bin/echo ${alreadylinked[0]} | /bin/sed -e 's/^.*E//' | /usr/bin/cut -f1 -d"."`

eval "counter=({1..${numfiles}})"
for i in  ${counter[@]}
do
	j=$((i-1))
	echo /bin/ln ${ripfiles[$j]} `/usr/bin/printf "${seasondir}/${basename}E%02u.${SUFFIX}" $((${lastlinked#0}+i))`
	/bin/ln ${ripfiles[$j]} `/usr/bin/printf "${seasondir}/${basename}E%02u.${SUFFIX}" $((${lastlinked#0}+i))`
done
