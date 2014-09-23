#!/bin/bash
#usage rip-dvd.sh [dev [mode|title1[,title2[,title3...]]]]

/usr/bin/ionice -c3 -p$$

USERGROUP="me:mine"

HOME=/root
LOGNAME=root

cd /root
. /etc/profile

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

/usr/bin/lsdvd ${TARGET} -qas > ${REPORT}

if [ -z "$2" ]; then 
	rawtitles=`/usr/bin/lsdvd -q ${TARGET} | /bin/grep '00:[2-5][0-9]:[0-9][0-9]' | /bin/grep Length | /usr/bin/sort -k4,2 `
	/bin/echo "${rawtitles}"
	if [ -z "$rawtitles" ] ; then
		/bin/echo "No episodes, ripping over an hour."
		/usr/bin/time -v /opt/bin/makemkvcon --profile="/root/.MakeMKV/default.mmcp.xml" mkv --minlength=3600 -r --decrypt --directio=true dev:${TARGET} all ${DESTDIR}
	else
		/bin/echo "episodes present, ripping all"
		/usr/bin/time -v /opt/bin/makemkvcon --profile="/root/.MakeMKV/default.mmcp.xml" mkv --minlength=120 -r --decrypt --directio=true dev:${TARGET} all ${DESTDIR}
		/usr/bin/find  ${DESTDIR} -size +4G -delete
	fi
else
	if [ "$2" = "long" ] ; then 
		/bin/echo "ripping over an hour, as instructed"
		/usr/bin/time -v /opt/bin/makemkvcon --profile="/root/.MakeMKV/default.mmcp.xml" mkv --minlength=3600 -r --decrypt --directio=true dev:${TARGET} all ${DESTDIR}
	elif [ "$2" = "all" ] ; then
		/bin/echo "ripping all over 30s, as instructed"
		/usr/bin/time -v /opt/bin/makemkvcon --profile="/root/.MakeMKV/default.mmcp.xml" mkv --minlength=30 -r --decrypt --directio=true dev:${TARGET} all ${DESTDIR}
	else		
		titles=`/bin/echo $2 | /bin/sed "s:,: :g"`
		/bin/echo "Ripping ${titles} as instructed"
		for title in ${titles} 
			do
			/bin/echo title = $title
			/usr/bin/time -v /opt/bin/makemkvcon --profile="/root/.MakeMKV/default.mmcp.xml" mkv --minlength=0 -r --decrypt --directio=true dev:${TARGET} $((10#$title-1)) ${DESTDIR}
		done
	fi
fi

cd ${DESTDIR}

for VIDEO in *.mkv
	do
	/bin/echo ${VIDEO} >> ${REPORT}
	PROBE=`/usr/bin/ffprobe -select_streams v -show_streams -count_frames -i ${VIDEO} 2>&1`
	/bin/echo "$PROBE" | /bin/grep 'Duration\|Stream\|read_frames' >> ${REPORT}
	DSTRING=`/bin/echo "$PROBE" | /bin/grep Duration | /usr/bin/cut -d" " -f4 | /bin/sed -e "s/,//" -e "s/:/)*60+/g"`
	FC=`/bin/echo "$PROBE" | /bin/grep nb_read_frames | /usr/bin/cut -d"=" -f2`
	/bin/echo "fps: "`/bin/echo $FC"/((("$DSTRING")" | /usr/bin/bc -l` >> ${REPORT}
done

/bin/chown -R ${USERGROUP} ${DESTDIR}
if [ -z "$2" ]; then 
	/usr/bin/eject ${TARGET}
fi
/bin/date
