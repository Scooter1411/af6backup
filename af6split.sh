#!/bin/sh
# $Revision$
#############################################################
# Das große Backupskript für zu Hause 
# Die sechste Inkarnation...
#############################################################
# $Url$
#############################################################
# Settings & Lock
#############################################################
DATE=`date +%Y%m%d%H%M%S`
START=`date +%s`
BASE=`basename $0 .sh`
SDIR=`dirname $0`
if [ "$SDIR" = "." ] ; then
    SDIR=`pwd`
fi
MYSELF=$SDIR/$BASE.sh
TMP=/tmp/$BASE.$$
#logger -s -puser.info -t$BASE.$$ started
HOST=`hostname`
#############################################################
# main configuration
#############################################################
MOUNTDIR=/share/HDA_DATA/Public
TODIR=$MOUNTDIR/af5backup.dir
OLDDIR=$TODIR/old
LEGACYLIST=$TODIR/af5backup.names
#############################################################
if [ ! -d "$TODIR/f/f/f" ] ; then
    mkdir -p $TODIR  2>/dev/null
    for I in 0 1 2 3 4 5 6 7 8 9 a b c d e f
      do
        for J in 0 1 2 3 4 5 6 7 8 9 a b c d e f
          do
            for K in 0 1 2 3 4 5 6 7 8 9 a b c d e f
              do
                mkdir -p $TODIR/$I/$J/$K 2>/dev/null
                chmod 6755 $TODIR/$I/$J/$K 
              done
          done
      done
fi

wc -l $LEGACYLIST 

while read LINE
  do
    MD5=`echo $LINE|cut -c1-32`

    MD51=`echo $MD5|cut -c1-1`
    MD52=`echo $MD5|cut -c2-2`
    MD53=`echo $MD5|cut -c3-3`

    MYPATH=$TODIR/$MD51/$MD52/$MD53/$MD5
    rm $MYPATH.check 2>/dev/null
    rm $MYPATH.bz2.check 2>/dev/null

    LS=`ls -l --time-style="+%Y%m%d%H%M%S" $MYPATH 2>/dev/null`
    if [ -z "$LS" ] ; then
        LS=`ls -l --time-style="+%Y%m%d%H%M%S" $MYPATH.bz2 2>/dev/null`
    fi 
    MDATE=`echo $LS|cut -d' ' -f6`
    if [ -z "$MDATE" ] ; then
        MDATE=20131111111111
    fi 

    SIZE=`echo $LINE|cut -f2 -d';'`
    ABS=`echo $LINE|sed -e's+[^;]*;[^;]*;[^;]*;++'`

    echo "$MD5;$SIZE;$MDATE;$HOST;\"$ABS\"" >> $MYPATH.af6
    sort < $MYPATH.af6 > $TMP.af6
    uniq < $TMP.af6 > $MYPATH.af6

  done < $LEGACYLIST 

exit 0
