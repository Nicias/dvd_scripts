#!/bin/bash
#usage rip-dvd.sh [dev [title1[,title2[,title3...]]]]

/usr/bin/ionice -c3 -p$$

USERGROUP="me:mine"
TEMPDIR=/var/tmp/dvd-import/
DESTBASE=/var/srv/media/videos/NO-BACKUP-holding/ripping/

if [ -z "$1" ]; then 
	TARGET=/dev/sr0
else
	TARGET=$1
fi

DISC=`/usr/bin/lsdvd ${TARGET} | /bin/grep Disc | /bin/sed 's/Disc\ Title:\ //'`

DESTDIR=${DESTBASE}/`/bin/date +%F-%a-%R| /bin/sed 's/:/-/'`-${DISC}

REPORT=${DESTDIR}/report.txt

/bin/date

/bin/mkdir -p ${DESTDIR}
/bin/mkdir -p ${TEMPDIR}

/bin/rm -f ${TEMPDIR}/*.mkv

/usr/bin/lsdvd ${TARGET} -qas > ${REPORT}

if [ -z "$2" ]; then 
	rawtitles=`/usr/bin/lsdvd -q ${TARGET} | /bin/grep '00:[1-5][0-9]:[0-9][0-9]\|01:[0-9][0-9]:[0-9][0-9]' | /bin/grep Length | /usr/bin/sort -k4,2 `
	/bin/echo "${rawtitles}"
	if [ -z "$rawtitles" ] ; then
		/bin/echo "No episodes ripping longest"
		titles=`/usr/bin/lsdvd -q ${TARGET} | /bin/grep Longest | /usr/bin/cut -f3 -d" "`
	else
		#titles=`/bin/echo "${rawtitles}" | /usr/bin/uniq -f3 | /usr/bin/cut -b 8-9  | /bin/sed 's/^[0]*//'` 
		titles=`/bin/echo "${rawtitles}"  | /usr/bin/cut -b 8-9  | /bin/sed 's/^[0]*//'` 
	fi
else
	titles=`/bin/echo $2 | /bin/sed "s:,: :g"`
	/bin/echo "Ripping ${titles} as instructed"
fi

cd ${TEMPDIR}
for title in $titles
	do 
	/bin/echo title = $title
	/usr/bin/time -v /opt/bin/makemkvcon mkv --minlength=0 -r --decrypt --directio=true dev:${TARGET} $((10#$title-1)) ${TEMPDIR}
	VIDEO=*.mkv
	/bin/echo ${VIDEO} >> ${REPORT}
	PROBE=`/usr/bin/ffprobe -select_streams v -show_streams -count_frames -i ${VIDEO} 2>&1`
	/bin/echo "$PROBE" | /bin/grep 'Duration\|Stream\|read_frames' >> ${REPORT}
	DSTRING=`/bin/echo "$PROBE" | /bin/grep Duration | /usr/bin/cut -d" " -f4 | /bin/sed -e "s/,//" -e "s/:/)*60+/g"`
	FC=`/bin/echo "$PROBE" | /bin/grep nb_read_frames | /usr/bin/cut -d"=" -f2`
	/bin/echo "fps: "`/bin/echo $FC"/((("$DSTRING")" | /usr/bin/bc -l` >> ${REPORT}
	/bin/mv ${VIDEO} ${DESTDIR}/.
done

/bin/chown -R ${USERGROUP} ${DESTDIR}
/usr/bin/eject ${TARGET}
/bin/date
