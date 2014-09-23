#!/bin/bash

/usr/bin/ionice -c3 -p$$

SHORTTEMPDIR=/tmp/sub-import/
LONGTEMPDIR=/var/tmp/sub-import/
SUBDIR=/tmp/sub-import/
LOGFILE=sub-force.txt
DETFILE=/tmp/sub-import/sub-force-det.txt
SUBLANG=dut
HOLDDIR=/var/srv/media/videos/NO-BACKUP-holding/subbing/`/bin/date +%F-%a-%R| /bin/sed 's/:/-/'`
#POLITE=15

LogString () {
	/bin/echo "$@" >> $LOGFILE
	/bin/echo "$@" 
}


if [ -z "$1" ]; then 
	/bin/echo usage: $0 files-or-directories
	exit
fi

/bin/mkdir -p ${SUBDIR}
/bin/mkdir -p ${SHORTTEMPDIR}
/bin/mkdir -p ${LONGTEMPDIR}

LogString "`/bin/date`: Starting Transcoding of $@" 

LIST=`/usr/bin/find $@ -name "*.mkv" | /usr/bin/sort`

LogString "Targets:"
LogString "${LIST}" 

/bin/mkdir -p ${HOLDDIR}

for FULLPATH in ${LIST} ;do 

	while [[ $POLITE &&  `date +%H` > "${POLITE}" ]] 
		do sleep 15m
	done

	DIR=$(dirname ${FULLPATH})
	NAME=$(basename ${FULLPATH})
	LogString "${FULLPATH}: `ffprobe ${FULLPATH}  2>&1 | grep Subtitle`"

	DURATION=`/usr/bin/ffprobe ${FULLPATH}   2>&1 >/dev/null   | /bin/grep  Duration | /usr/bin/cut -f4 -d" "   | /usr/bin/awk -F: '{ print ($1*60)+ $2}'`
	if [ $DURATION -lt 60 ] ; then
		LogString "is short"
		TEMPDIR=${SHORTTEMPDIR}
	else
		LogString "is long" 
		TEMPDIR=${LONGTEMPDIR}
	fi
	
	HOLDNAME=${HOLDDIR}/${NAME}
	TEMPNAME=${TEMPDIR}/${NAME}
	SUBNAME=${SUBDIR}/${NAME}-subs.mkv
	SUBTNAME=${SUBDIR}/${NAME}-subs-temp.mkv

	/bin/mv ${FULLPATH} ${HOLDDIR} 
	/bin/cp ${HOLDNAME} ${TEMPDIR}
	LogString "`/bin/date`: ripping only forced subtitles"
	/usr/bin/ffmpeg -benchmark -i ${TEMPNAME} -map 0:s -an -vn -c:s dvdsub ${SUBTNAME} 2>&1 | /usr/bin/tee -a ${DETFILE}
	/usr/bin/ffmpeg -benchmark -forced_subs_only 1 -i ${SUBTNAME} -map 0:s -metadata:s:s language=${SUBLANG} \
		-c:s dvdsub ${SUBNAME} 2>&1 | /usr/bin/tee -a ${DETFILE}

	LogString "`/bin/date`: splitting subs"
	count=0
	while ( /usr/bin/mkvextract tracks ${SUBNAME} ${count}:${SUBDIR}${count}.idx )  ; do
		let count+=1
	done
	LogString "`/bin/ls -l ${SUBDIR}`"
	if [ -s `/bin/ls -S ${SUBDIR}/*.sub  | /usr/bin/head -1` ] ; then
		SUBTRACK=`/bin/ls -S ${SUBDIR}/*.idx  | /usr/bin/head -1`
		SUBOPTS="--default-track 0:0 --language 0:dut ${SUBTRACK}"  

		/usr/bin/mkvmerge -o ${DIR}/${FULLPATH} --engage no_simpleblocks ${TEMPNAME}  ${SUBOPTS}  2>&1 | /usr/bin/tee -a ${DETFILE}
		LogString "`/bin/date`: finished"
		LogString "`/usr/bin/ffprobe ${FULLPATH}  2>&1 | /bin/grep Subtitle`"
	else
		LogString "Actually no subtitles"
		/bin/mv ${HOLDDIR} ${FULLPATH}
	fi
	/bin/rm ${TEMPNAME}
	/bin/rm ${SUBDIR}/*.{idx,mkv,sub}
done
LogString "Transcoding complete"
