#!/bin/bash

/usr/bin/ionice -c3 -p$$

SUBDIR=/tmp/sub-import/
SUBLANG=dut
SHORTTEMPDIR=/tmp/transcode/
LONGTEMPDIR=/var/tmp/transcode/
LOGFILE=transcode-log.txt
DETFILE=/tmp/transcode/transcode-det.txt
#POLITE=17
SPEED=veryfast
CRF=17
#for debuging
#SPEED=ultrafast
#CRF=40
HOLDDIR=/var/srv/media/videos/NO-BACKUP-holding/transcoding/`/bin/date +%F-%a-%R| /bin/sed 's/:/-/'`

LogString () {
	/bin/echo "$@" >> $LOGFILE
	/bin/echo "$@" 
}


if [ -z "$1" ]; then 
	/bin/echo usage: $0 directories-or-files
	exit
fi

/bin/mkdir -p ${SUBDIR}
/bin/mkdir -p ${SHORTTEMPDIR}
/bin/mkdir -p ${LONGTEMPDIR}

LogString "`/bin/date`: Starting Transcoding of $@" 

LIST=`/usr/bin/find $@ -name "*.mkv" | /usr/bin/sort`

LogString "Possible targets:"
LogString "${LIST}" 

/bin/mkdir -p ${HOLDDIR}

for FULLPATH in ${LIST} ;do 

	while [[ $POLITE &&  `date +%H` > "${POLITE}" ]]
		do sleep 15m
	done

	DIR=$(dirname ${FULLPATH})
	NAME=$(basename ${FULLPATH})
	LogString "${FULLPATH}: `/bin/ls -lh ${FULLPATH} | /usr/bin/cut -d" " -f5` `/usr/bin/mkvinfo ${FULLPATH} | /bin/grep MPEG`"

	/usr/bin/mkvinfo ${FULLPATH} | /bin/grep MPEG2 -q
	if [ $? -ne 0  ]; then 
		LogString "does not need transcoding" 
		NEWPATH=`/bin/echo ${FULLPATH} | /bin/sed -e 's/\(.*\)ivtc./\1/' -e  's/\(.*\)bbc./\1/' -e  's/\(.*\)tvdvd./\1/'  -e 's/\(.*\)b5./\1/'\
				 -e 's/\(.*\)nostrip./\1/' -e 's/\(.*\)film./\1/' -e 's/\(.*\)partial./\1/' -e 's/\(.*\)mixed./\1/' -e 's/\(.*\)laced./\1/'`
		if [ "${FULLPATH}" != "${NEWPATH}" ]; then 
			/bin/mv ${FULLPATH} ${NEWPATH}
		fi
	else
		LogString "needs transcoding" 
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
				#ILACEOPTS="-vf fps=fps=24000/1001:round=zero"
				ILACEOPTS="-r 24000/1001"
				;;
			*b5*)
				LogString "marked as b5 mixed telecine/progressive"
				NEWPATH=`/bin/echo ${FULLPATH} | /bin/sed 's/\(.*\)b5./\1/'`
				ILACEOPTS="-vf pullup,dejudder,fps=fps=60000/1001 "
				#ILACEOPTS="-vf pullup,dejudder -r 60000/1001 "
				;;
			*partial*)
				LogString "marked as partial film rate/telecine"
				NEWPATH=`/bin/echo ${FULLPATH} | /bin/sed 's/\(.*\)partial./\1/'`
				ILACEOPTS="-vf pullup,dejudder -r 24000/1001 "
				;;
			*mixed*)
				LogString "marked as mixed telecine/interlaced"
				NEWPATH=`/bin/echo ${FULLPATH} | /bin/sed 's/\(.*\)mixed./\1/'`
				ILACEOPTS="-vf pullup,dejudder,idet,yadif=mode=1:deint=interlaced,fps=fps=60000/1001 "
				#ILACEOPTS="-vf pullup,dejudder,idet,yadif=mode=1:deint=interlaced -r 60000/1001 "
				;;
			*tvdvd*)
				LogString "marked as mixed progressive/interlaced"
				NEWPATH=`/bin/echo ${FULLPATH} | /bin/sed 's/\(.*\)mixed./\1/'`
				ILACEOPTS="-vf idet,yadif=mode=1:deint=interlaced,fps=fps=60000/1001 "
				#ILACEOPTS="-vf idet,yadif=mode=1:deint=interlaced -r 60000/1001 "
				;;
			*laced*)
				LogString "marked as interlaced"
				NEWPATH=`/bin/echo ${FULLPATH} | /bin/sed 's/\(.*\)laced./\1/'`
				ILACEOPTS="-vf yadif=mode=1 "
				;;
			*)
				/usr/bin/mkvinfo ${FULLPATH} | /bin/grep 'Interlaced: 1' -q
				if [ $? -eq 0 ]; then
					ILACEOPTS="-vf yadif=deint=interlaced:mode=1,fps=fps=60000/1001"
					#ILACEOPTS="-vf yadif=deint=interlaced:mode=1 -r 60000/1001"
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
		/usr/bin/ffmpeg -hide_banner -benchmark -i ${HOLDNAME} -map 0 -c:a copy -c:s copy -c:v libx264 \
			-preset ${SPEED} -crf ${CRF} ${ILACEOPTS} ${TEMPNAME} 2>&1 | /usr/bin/tee -a ${DETFILE}

		LogString "`/bin/date`: starting remuxing"

		SUBOPTS=" "
		SUBLIST=" "
		FSUBOPTS=" "
		/usr/bin/mkvmerge -i ${TEMPNAME} | /bin/grep VOBSUB -q
		if [ $? -eq 0 ]; then
			LogString "has subtitles"
			subtracks=`/usr/bin/ffprobe ${TEMPNAME} 2>&1 | /bin/grep Subtitle | /bin/sed -e "s/[()]/:/g" | /usr/bin/cut -d":" -f2,3`
			for subtrack in ${subtracks} 
				do
				set -- `/bin/echo ${subtrack} | /bin/sed -e "s/:/ /"`
				if [ "$2" = "eng" ] ; then
					SUBOPTS="${SUBOPTS} --default-track ${1}:0 "				
					SUBLIST="${SUBLIST},${1}"
				fi
			done
			ONEOPTS=`/bin/echo $SUBLIST | sed -e "s/,/ -map 0:/g"`
			/usr/bin/ffmpeg -hide_banner -benchmark -i ${TEMPNAME} ${ONEOPTS} -c:s dvdsub ${SUBDIR}/one.mkv 2>&1 | /usr/bin/tee -a ${DETFILE}
			/usr/bin/ffmpeg -hide_banner -benchmark -forced_subs_only 1 -i ${SUBDIR}/one.mkv -map 0:s -metadata:s:s language=${SUBLANG} \
				-c:s dvdsub ${SUBDIR}/two.mkv 2>&1 | /usr/bin/tee -a ${DETFILE}

			LogString "`/bin/date`: splitting subs"

			count=0
			while ( /usr/bin/mkvextract tracks ${SUBDIR}/two.mkv ${count}:${SUBDIR}${count}.idx )  ; do
				let count+=1
			done
			LogString "`/bin/ls -l ${SUBDIR}`"
			if [ -s `/bin/ls -S ${SUBDIR}/*.sub  | /usr/bin/head -1` ] ; then
				SUBTRACK=`/bin/ls -S ${SUBDIR}/*.idx  | /usr/bin/head -1`
				FSUBOPTS="--default-track 0:0 --language 0:dut ${SUBTRACK}"
			else
				LogString "No Forced subtitles"
			fi

			if [ "${SUBLIST}" = " " ] ; then
				LogString "no English subtitles"
				SUBLIST="-S"
			else
				SUBLIST=`/bin/echo $SUBLIST | /bin/sed -e "s:,:-s :"`
 			fi
		else
			LogString "does not have subtitles" 
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
					AUDLIST="-a `/usr/bin/ffprobe  ${TEMPNAME}  2>&1 |  /bin/grep Audio  | /bin/grep "(eng)\|(default)" \
						| /bin/sed -e "s/(/:/" | /usr/bin/cut -d":" -f2 | /usr/bin/tr  '\n' ',' | /bin/sed -e 's/\(.*\),/\1/g'`"
				fi
				;;
		esac
		/usr/bin/mkvmerge -o ${NEWPATH} --engage no_simpleblocks  ${AUDLIST} ${SUBLIST} ${SUBOPTS} ${TEMPNAME} ${FSUBOPTS}  2>&1 | /usr/bin/tee -a ${DETFILE}
		/bin/rm ${TEMPNAME}
		/bin/rm ${SUBDIR}/*.{mkv,idx,sub}
		LogString "`/bin/date`: finished: `/bin/ls -lh ${NEWPATH} | /usr/bin/cut -d" " -f5`"
	fi
done
LogString "Transcoding complete"
