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
############################################################
# canonical path name
############################################################

############################################################
# ls on busybox does not support --time-style
# so we need this funny workaround
############################################################
mdate () {
    if [ -f $1 ] ; then 
        _LS=`ls -l --time-style="+%Y%m%d%H%M%S" $1 2>/dev/null`
        _MDATE=`echo $_LS|cut -d' ' -f6`
        if [ -z "$_MDATE" ] ; then
            _LS=`ls -le $1 2>/dev/null`
            _Y=`echo $_LS|cut -d' ' -f10`
            _MO=`echo $_LS|cut -d' ' -f7|sed -e's+Jan+01+' -e's+Feb+02+' -e's+Mar+03+' -e's+Apr+04+' -e's+Ma.+05+' -e's+Jun+06+' -e's+Jul+07+' -e's+Aug+08+' -e's+Sep+09+' -e's+O.t+10+' -e's+Nov+11+' -e's+De.+12+'`
            _D=`echo $_LS|cut -d' ' -f8|awk '{printf("%02d",\$0)}'`
            _T=`echo $_LS|cut -d' ' -f9|sed -e's+:++g'`
            _MDATE=`echo $_Y$_MO$_D$_T`
        fi 
        echo $_MDATE
    fi
}

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

find $TODIR -type f -name '*.check' | sed -e's+^.*/++' -e's+[.].*++' > $TODIR/af5check
cat $TODIR/af5check

while read MD5
  do
    MD51=`echo $MD5|cut -c1-1`
    MD52=`echo $MD5|cut -c2-2`
    MD53=`echo $MD5|cut -c3-3`
    MD5FILE=$TODIR/list/`echo $MD5|cut -c1-3`
        
    grep $MD5 $MD5FILE | while read LINE
      do
        MYPATH=$TODIR/$MD51/$MD52/$MD53/$MD5
        rm $MYPATH.check 2>/dev/null
        rm $MYPATH.bz2.check 2>/dev/null
        
        MDATE=`mdate $MYPATH`
        if [ -z "$MDATE" ] ; then
            MDATE=`mdate $MYPATH.bz2`
        fi 
        if [ -z "$MDATE" ] ; then
            MDATE=`mdate $MYPATH.check`
        fi 
        if [ -z "$MDATE" ] ; then
            MDATE=`mdate $MYPATH.bz2.check`
        fi 
        if [ -z "$MDATE" ] ; then
            MDATE=20131111111111
        fi 
        
        SIZE=`echo $LINE|cut -f2 -d';'`
        ABS=`echo $LINE|sed -e's+[^;]*;[^;]*;[^;]*;++'`
        
        echo "$MD5;$SIZE;$MDATE;$HOST;\"$ABS\"" |tee -a $MYPATH.af6
        sort < $MYPATH.af6 > $TMP.af6
        uniq < $TMP.af6 > $MYPATH.af6
      done  
  done < $TODIR/af5check
exit 0
