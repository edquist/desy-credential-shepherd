#!/bin/bash
###########################################
# DESY HTCondor Config                    #
###########################################
VERSION="Version 2017/02/20 (10:00)"      #
###########################################

#set -x
DEBUGFILE="/tmp/htckrb5debug"
LOGFILE="/var/log/condor/CredMonLog"
if [[ ! -f $LOGFILE ]]; then
	touch $LOGFILE
fi
CREDSDONE="/var/lib/condor/credential/CREDMON_COMPLETE"
SIGNAL="/var/lib/condor/credential/CREDMON_SIGNAL"
TIMER="/var/lib/condor/credential/CREDMON_TIMER"
ATWORK="/var/lib/condor/credential/CREDMON_ATWORK"
OLDSIGNAL="/var/lib/condor/credential/CREDMON_OLDSIGNAL"
OLDTIMER="/var/lib/condor/credential/CREDMON_OLDTIMER"
PIDFILE="/var/lib/condor/credential/pid"
TOKENCMD="/var/lib/condor/util/set_batchtok_cmd"

COMMAND=$(basename $0)
if [[ ${COMMAND%worker} != $COMMAND || -f /etc/condor/config.d/00worker.conf ]]; then
	WORKER="true"
else
	WORKER="false"
fi
TIMEOUT="300"

function shepherding {
	touch $ATWORK
	DATE=$(date +'%T %x')
	if [[ -f $DEBUGFILE ]]; then
		if [[ -f $SIGNAL ]]; then
			echo "$DATE $COMMAND $1 signal" >> $DEBUGFILE
		else
			echo "$DATE $COMMAND $1" >> $DEBUGFILE
		fi
	fi
	echo "$DATE $COMMAND $1" >> $LOGFILE

	until [[ ! -f $SIGNAL && ! -f $TIMER ]];
	do
		/bin/rm -f $SIGNAL $TIMER
		for TICKET in /var/lib/condor/credential/*.cred
		do
			[[ -e $TICKET ]] || continue
			export USER=${TICKET%.cred}
			export USER=${USER#/}
			export USER=${USER##*/}
			DATE=$(date +'%T %x')
			if [[ ! -f ${TICKET%cred}cc ]]; then
				# .cc file does not exist replace user ticket by new batch ticket
				if [[ $WORKER = "true" ]]; then
					ACTION="prolong"
				else
					ACTION="renew"
				fi
				$TOKENCMD $USER 86000 ${TICKET} $ACTION
				cp $TICKET ${TICKET%cred}cc.tmp
				mv ${TICKET%cred}cc.tmp ${TICKET%cred}cc
		        	if [[ -f $DEBUGFILE ]]; then
					echo "$DATE $COMMAND created ($ACTION, worker=$WORKER) ${USER}.cc KRB5CCNAME($USER)=FILE:${TICKET}" >> $DEBUGFILE
 				fi
			else
				# Check ticket
				export KRB5CCNAME="FILE:$TICKET"
				if [[ $WORKER = "true" ]]; then
					# On worker only prolongation
					ACTION="prolong"
					$TOKENCMD $USER 86000 ${TICKET} prolong
				else
					# On scheduler full program
					ACTION="default"
					$TOKENCMD $USER 86000 ${TICKET}
				fi
				if [[ ${TICKET%cred}cc -ot $TICKET ]]; then
					# .cc file exists and checked ticket is older than actual token
					cp $TICKET ${TICKET%cred}cc.tmp
					mv ${TICKET%cred}cc.tmp ${TICKET%cred}cc
					if [[ -f $DEBUGFILE ]]; then
						echo "$DATE $COMMAND renewed ($ACTION, worker=$WORKER) ${USER}.cc KRB5CCNAME($USER)=$KRB5CCNAME" >> $DEBUGFILE
					fi
				else
					if [[ -f $DEBUGFILE ]]; then
						echo "$DATE $COMMAND checked ($ACTION, worker=$WORKER) ${USER}.cc KRB5CCNAME($USER)=$KRB5CCNAME" >> $DEBUGFILE
					fi
				fi
			fi
		done
		for TICKET in /var/lib/condor/credential/*.mark
		do
			[[ -e $TICKET ]] || continue
			DATE=$(date +'%T %x')
			export USER=${TICKET%.mark}
			export USER=$(basename $USER)
			echo "$DATE $COMMAND removed marked $USER" >> $LOGFILE
			/bin/rm -f $TICKET ${TICKET%mark}cc ${TICKET%mark}cred
			if [[ -f $DEBUGFILE ]]; then
				echo "$DATE $COMMAND removed marked ${USER}.cc ${USER}.cred ${USER}.mark" >> $DEBUGFILE
			fi
		done
	done
	touch $CREDSDONE
	/bin/rm -f $ATWORK
}


function signalling {
	DATE=$(date +'%T %x')
	touch $SIGNAL
	if [[ -f $OLDSIGNAL ]]; then
		if [[ -f $DEBUGFILE ]]; then
			echo "$DATE $COMMAND received signal (oldstyle run)" >> $DEBUGFILE
		fi
		shepherding oldstyle
	else
		if [[ -f $DEBUGFILE ]]; then
			echo "$DATE $COMMAND received signal (new signal)" >> $DEBUGFILE
		fi
	fi

}

if [[ -f $PIDFILE ]] ; then
	rm $PIDFILE
fi
echo $$ > $PIDFILE

DATE=$(date +'%T %x')
if [[ -f $CREDSDONE ]]; then
	if [[ -f $DEBUGFILE ]]; then
		echo "$DATE $COMMAND Startup: Exists $CREDSDONE" >> $DEBUGFILE
	fi
else
	if [[ -f $DEBUGFILE ]]; then
		echo "$DATE $COMMAND Startup: No $CREDSDONE" >> $DEBUGFILE
	fi
fi
DATE=$(date +'%T %x')
echo "$DATE $COMMAND $VERSION" >> $LOGFILE
shepherding startup
DATE=$(date +'%T %x')
if [[ -f $DEBUGFILE ]]; then
	echo "$DATE $COMMAND Startup: Touched $CREDSDONE" >> $DEBUGFILE
fi

trap 'signalling signal' SIGHUP

while :
do
	sleep $TIMEOUT &
	wait
	if [[ -f $ATWORK ]]; then
		DATE=$(date +'%T %x')
		if [[ -f $OLDTIMER ]]; then
			if [[ -f $DEBUGFILE ]]; then
				echo "$DATE $COMMAND timer: Already at work (continue)" >> $DEBUGFILE
			fi
			continue
		else
			if [[ -f $DEBUGFILE ]]; then
				echo "$DATE $COMMAND timer: Already at work (oldstyle2)" >> $DEBUGFILE
			fi
		fi
	fi
	touch $TIMER
	shepherding timer
done


