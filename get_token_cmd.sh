#!/bin/ksh
# Managed by Puppet (htcondor::krb5)
# # Do NOT edit, changes will be overwritten!
# #
# #
# #
# # puppet: ./modules/htcondor/manifests/krb5.pp  (Attention: changes will be overwritten by puppet)
# #
#
###########################################
# DESY HTCondor Config                    #
###########################################

DEBUGFILE="/tmp/htckrb5debug"
COMMAND="$0"
CCDIR="${@}"

function logging {
if [[ -f $DEBUGFILE ]]; then
    DATE=$(date +'%T %x')
    print "$DATE $COMMAND $CCDIR $1" >> $DEBUGFILE
fi
#DATE=$(date +'%T %x')
#print "$DATE $COMMAND $CCDIR $1"
}


if [[ -f /usr/heimdal/bin/klist ]]; then
        PRINCE=`/usr/heimdal/bin/klist 2>/dev/null | grep Principal:`
elif [[ -f /usr/kerberos/bin/klist ]]; then
        PRINCE=`/usr/kerberos/bin/klist 2>/dev/null | grep principal:`
elif [[ -f /usr/bin/klist ]]; then
        PRINCE=`/usr/bin/klist 2>/dev/null | grep principal:`
else
        PRINCE=""
fi

if [[ -n "$PRINCE" ]]; then
	logging "start get PRINCE ok"
else
        #echo "Reject: Could not verify user"
	logging "start get PRINCE failed"
        exit 1
fi
if [[ -n "$KRB5CCNAME" && -f "${KRB5CCNAME#FILE:}" ]]; then
#        /usr/bin/aklog
	/usr/sbin/condor_aklog
	TOKENFILE=${KRB5CCNAME#FILE:} 
	cat $TOKENFILE
	logging "start get TOKENFILE $TOKENFILE ok"
#        sleep 10 # Give Storage Time
	exit 0
else
	logging "start get TOKENFILE failed"
	exit 1
fi
