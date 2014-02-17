#!/bin/bash
#usage transcode.sh paths-containing-mkv's

/usr/bin/ionice -c3 -p$$

SHORTTEMPDIR=/tmp/transcode/
LONGTEMPDIR=/var/tmp/transcode/
LOGFILE=transcode-log.txt
DETFILE=/tmp/transcode/transcode-det.txt
SPEED=veryfast
CRF=17
HOLDDIR=/var/srv/media/videos/NO-BACKUP-holding/transcoding/`/bin/date +%F-%a-%R| /bin/sed 's/:/-/'`

LogString () {
	/bin/echo "$@" >> $LOGFILE
	/bin/echo "$@" 
}

if [ -z "$1" ]; then 
              /bin/echo usage: $0 paths-containing-mkvs
              exit
fi

/bin/mkdir -p ${SHORTTEMPDIR}
/bin/mkdir -p ${LONGTEMPDIR}

LogString "`/bin/date`: Starting Transcoding of $@" 

LIST=`/usr/bin/find $@ -name "*.mkv" | /usr/bin/sort`

LogString "Possible targets:"
LogString "${LIST}" 

/bin/mkdir -p ${HOLDDIR}

for FULLPATH in ${LIST} ;do 
	DIR=$(dirname ${FULLPATH})
	NAME=$(basename ${FULLPATH})
	LogString "${FULLPATH}: `/bin/ls -lh ${FULLPATH} | /usr/bin/cut -d" " -f5` `/usr/bin/mkvinfo ${FULLPATH} | /bin/grep MPEG`"

	/usr/bin/mkvinfo ${FULLPATH} | /bin/grep MPEG2 -q
	if [ $? -ne 0  ]; then 
		LogString "does not need transcoding" 
		NEWPATH=`/bin/echo ${FULLPATH} | /bin/sed -e 's/\(.*\)ivtc./\1/' -e  's/\(.*\)bbc./\1/' -e 's/\(.*\)b5./\1/'\
				 -e 's/\(.*\)nostrip./\1/' -e 's/\(.*\)film./\1/'`		
		if [ "${FULLPATH}" != "${NEWPATH}" ]; then 
			mv ${FULLPATH} ${NEWPATH}
		fi
	else
		LogString "needs transcoding" 
		DURATION=`/usr/bin/ffprobe ${FULLPATH}   2>&1 >/dev/null   | /bin/grep  Duration | /usr/bin/cut -f4 -d" "   | /usr/bin/awk -F: '{ print ($1*60)+ $2}'`
		if [ $DURATION -lt 80 ] ; then
        		LogString "is short"
			TEMPDIR=${SHORTTEMPDIR}
       		else
        		LogString "is long" 
			TEMPDIR=${LONGTEMPDIR}
		fi

		HOLDNAME=${HOLDDIR}/${NAME}
		TEMPNAME=${TEMPDIR}/${NAME}

		case ${NAME} in
			*ivtc*)
				LogString "marked as telecined"
				NEWPATH=`/bin/echo ${FULLPATH} | /bin/sed 's/\(.*\)ivtc./\1/'`
				ILACEOPTS="-vf fieldmatch,decimate"
				;;
			*bbc*)
				LogString "marked as bbc-telecined"
				NEWPATH=`/bin/echo ${FULLPATH} | /bin/sed 's/\(.*\)bbc./\1/'`
				ILACEOPTS="-vf fieldmatch,decimate=6"
				;;
			*film*)
				LogString "marked as film-rate"
				NEWPATH=`/bin/echo ${FULLPATH} | /bin/sed 's/\(.*\)film./\1/'`
				ILACEOPTS="-vf fps=24000/1001"
				;;
			*b5*)
				LogString "marked as b5 mixed telecine"
				NEWPATH=`/bin/echo ${FULLPATH} | /bin/sed 's/\(.*\)b5./\1/'`
				ILACEOPTS="-vf pullup,dejudder,fps=60000/1001 "
				;;
			*)
				/usr/bin/mkvinfo ${FULLPATH} | /bin/grep 'Interlaced: 1' -q
				if [ $? -eq 0 ]; then
					ILACEOPTS="-vf idet,yadif=deint=interlaced"
					LogString "is interlaced"
					else
					ILACEOPTS=" "
					LogString "is not interlaced"					
				fi
				NEWPATH=${FULLPATH}
				;;
		esac
		/bin/mv ${FULLPATH} ${HOLDDIR} 
		LogString "`/bin/date`: starting transcode"
		/usr/bin/ffmpeg -benchmark -i ${HOLDNAME} -map 0 -c:a copy -c:s copy  -c:v libx264 -preset ${SPEED} -crf ${CRF} ${ILACEOPTS} ${TEMPNAME} 2>&1 | /usr/bin/tee -a ${DETFILE}

		LogString "`/bin/date`: starting remuxing"

		/usr/bin/mkvmerge -i ${TEMPNAME} | /bin/grep VOBSUB -q
		if [ $? -eq 0 ]; then
			LogString "has subtitles" 
			SUBOPTS=" "
			SUBLIST=" " 
			subtracks=`/usr/bin/ffprobe ${TEMPNAME} 2>&1 | /bin/grep Subtitle | /bin/sed -e "s/[()]/:/g" | /usr/bin/cut -d":" -f2,3` 
			for subtrack in ${subtracks} 
				do
				set -- `/bin/echo ${subtrack} | /bin/sed -e "s/:/ /"`
				if [ "$2" = "eng" ] ; then
					SUBOPTS="${SUBOPTS} --default-track ${1}:0 "				
					SUBLIST="${SUBLIST},${1}"
				fi
			done
			if [ "${SUBLIST}" = " " ] ; then
				SUBLIST="-S"
				else
				SUBLIST=`/bin/echo $SUBLIST | /bin/sed -e "s:,:-s :"`
 			fi
			else
			LogString "does not have subtitles" 
			SUBOPTS=" "
		fi
		case ${NAME} in
			*nostrip*)
				LogString "keeping non-english audio tracks"
				AUDLIST=" "
				NEWPATH=`/bin/echo ${NEWPATH} | /bin/sed 's/\(.*\)nostrip./\1/'`		
				;;
			*)
				/usr/bin/ffprobe  ${TEMPNAME}  2>&1 |  /bin/grep Audio  | /bin/grep -q -v  "(eng)"
				if [ $? -ne 0  ]; then 
					LogString "does not need audio stripping"
				AUDLIST=" " 
				else
					LogString "does need audio stripping"
					AUDLIST="-a `/usr/bin/ffprobe  ${TEMPNAME}  2>&1 |  /bin/grep Audio  | /bin/grep "(eng)" \
						| /bin/sed -e "s/(/:/" | /usr/bin/cut -d":" -f2 | /usr/bin/tr  '\n' ',' | /bin/sed -e 's/\(.*\),/\1/g'`"
				fi
				;;
		esac
		/usr/bin/mkvmerge -o ${NEWPATH} --engage no_simpleblocks  ${AUDLIST} ${SUBLIST} ${SUBOPTS} ${TEMPNAME}  2>&1 | /usr/bin/tee -a ${DETFILE}
		/bin/rm ${TEMPNAME}
		LogString "`/bin/date`: finished: `/bin/ls -lh ${NEWPATH} | /usr/bin/cut -d" " -f5`"
	fi
done
LogString "Transcoding complete"
