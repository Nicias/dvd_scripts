#!/bin/bash

/usr/bin/ionice -c3 -p$$

REPORT=report.txt
for VIDEO in *.mkv
	do 
	/bin/echo ${VIDEO} >> ${REPORT}
	PROBE=`/usr/bin/ffprobe -select_streams v -show_streams -count_frames -i ${VIDEO} 2>&1`
	/bin/echo "$PROBE" | /bin/grep 'Duration\|Stream\|read_frames' >> ${REPORT}
	DSTRING=`/bin/echo "$PROBE" | /bin/grep Duration | /usr/bin/cut -d" " -f4 | /bin/sed -e "s/,//" -e "s/:/)*60+/g"`
	FC=`/bin/echo "$PROBE" | /bin/grep nb_read_frames | /usr/bin/cut -d"=" -f2`
	/bin/echo "fps: "`/bin/echo $FC"/((("$DSTRING")" | /usr/bin/bc -l` >> ${REPORT}
done
