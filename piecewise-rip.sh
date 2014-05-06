#!/bin/bash

/usr/bin/ionice -c3 -p$$

USERGROUP="me:mine"
TMPDIR=/var/tmp/dvd-import/
SUBDIR=/tmp/sub-import/


if [ -z "$1" ]; then 
	TARGET=/dev/sr0
else
	TARGET=$1
fi



DISC=`/usr/bin/lsdvd ${TARGET} | /bin/grep Disc | /bin/sed 's/Disc\ Title:\ //'`

DESTDIR=/var/srv/media/videos/NO-BACKUP-holding/ripping/`/bin/date +%F-%a-%R| /bin/sed 's/:/-/'`-${DISC}

REPORT=${DESTDIR}/report.txt


/bin/date

/bin/mkdir -p ${DESTDIR}
/bin/mkdir -p ${SUBDIR}
/bin/mkdir -p ${TMPDIR}

/usr/bin/lsdvd ${TARGET} -qas > ${REPORT}

rawtitles=`/usr/bin/lsdvd -q ${TARGET} | /bin/grep '00:[1-5][0-9]:[0-9][0-9]\|01:[0-9][0-9]:[0-9][0-9]' | /bin/grep Length | /usr/bin/sort -k4,2 `
/bin/echo "${rawtitles}"
if [ -z "$rawtitles" ] ; then
	echo "No episodes ripping longest"
	titles=`/usr/bin/lsdvd -q ${TARGET} | /bin/grep Longest | /usr/bin/cut -f3 -d" "`
else
	titles=`/bin/echo "${rawtitles}"  | /usr/bin/cut -b 8-9  | /bin/sed 's/^[0]*//'` 
fi

for title in $titles
	do 
	/bin/echo title = $title
		listing=`/usr/bin/lsdvd ${TARGET} -qast ${title}`
		/usr/bin/dvdxchap -t ${title} ${TARGET} > ${SUBDIR}/${DISC}-${title}.chap
		VOBNAME=${TMPDIR}/${DISC}-${title}.vob
		NOVIDNAME=${SUBDIR}/${DISC}-${title}-novid.mkv
		/usr/bin/mplayer -dvd-device ${TARGET} dvd://${title} -dumpfile ${VOBNAME} -dumpstream 
		SUBOPTS=" "
		subtracks=`/bin/echo "${listing}" | /bin/grep Subtitle | /usr/bin/cut -d":" -f2,3 | /bin/sed "s:,::g" | /usr/bin/cut -d" " -f2,4  | /bin/sed "s: :-:" `
		for subtrack in ${subtracks}
		do
			echo $subtrack
			set -- `/bin/echo $subtrack | /usr/bin/tr -C [:print:][:space:] x | /bin/sed -e "s:-: :" -e "s:xx:en:" `
			N=$((10#$1-1))
			/bin/echo "Extracting subtitle track ${N} of langauge ${2}"
			/usr/bin/mencoder -really-quiet ${VOBNAME} -nosound -ovc copy -o /dev/null \
				-vobsubout ${SUBDIR}/${DISC}-${title}-SUBS-${N} -sid ${N} -vobsuboutindex ${N} -vobsuboutid ${2}
			if [ -s ${SUBDIR}/${DISC}-${title}-SUBS-${N}.sub ] 
			then
				SUBOPTS="${SUBOPTS} --default-track 0:0  --language 0:${2} =${SUBDIR}/${DISC}-${title}-SUBS-${N}.idx =${SUBDIR}/${DISC}-${title}-SUBS-${N}.sub "
			fi
		done
		AUDOPTS=" "
		audiotracks=`/bin/echo "${listing}" | /bin/grep Frequency | /usr/bin/cut -d":" -f2,3 | /bin/sed "s:,::g" | /usr/bin/cut -d" " -f2,4  | /bin/sed "s: :-:" `
		for audiotrack in ${audiotracks}
		do
			set -- `/bin/echo $audiotrack | /usr/bin/tr -C [:print:][:space:] x  | /bin/sed -e "s:-: :"  -e "s:xx:en:"`
			AUDOPTS="${AUDOPTS} --language ${1}:${2}"
		done

		AUDOPTS=" -a `/bin/echo "${audiotracks}" | /usr/bin/cut -d"-" -f1 | /usr/bin/tr "\n" "," | /bin/sed -e  's/\(.*\),/\1/g'` ${AUDOPTS} " 
		/usr/bin/mkvmerge --default-language en -o ${NOVIDNAME} -D -S ${AUDOPTS} =${VOBNAME} ${SUBOPTS} --chapters ${SUBDIR}/${DISC}-${title}.chap
		/usr/bin/ffmpeg  -fflags +genpts -benchmark -i ${VOBNAME}  -i ${NOVIDNAME} -map 0:v -map 1 -c copy  ${DESTDIR}/${DISC}-${title}.mkv
		#/usr/bin/mkvmerge --default-language en -o ${DESTDIR}/${DISC}-${title}.mkv --engage no_simpleblocks \
		#	 -S  ${AUDOPTS} =${VOBNAME}  ${SUBOPTS} --chapters ${SUBDIR}/${DISC}-${title}.chap
done

/bin/rm -rf ${TMPDIR}/*.vob
/bin/rm -rf ${SUBDIR}/*.chap
/bin/rm -rf ${SUBDIR}/*.sub
/bin/rm -rf ${SUBDIR}/*.idx
/bin/rm -rf ${SUBDIR}/*.mkv

/bin/chown -R ${USERGROUP} ${DESTDIR}
/usr/bin/eject ${TARGET}
/bin/date
