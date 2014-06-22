#!/bin/sh
# $Revision$
#############################################################
# Das große Backupskript für zu Hause 
# Die sechste Inkarnation...
#############################################################
# $HeadURL$
# $Id$
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
mkdir -p $TMP
#logger -s -puser.info -t$BASE.$$ started
HOST=`hostname`
#############################################################
# main configuration
#############################################################
TARGET=admin@quokka
MOUNTDIR=/share/HDA_DATA/Public
TODIR=$MOUNTDIR/af5backup.dir
OLDDIR=$TODIR/old
LEGACYLIST=$TODIR/af5backup.names
NAMESDIR=$TODIR/af6backup.names
#############################################################
MAILTO="alexander.franz.1411@gmail.com"
#############################################################
# canonical path name
############################################################
abspath () { 
   case "$1" in 
       /*)printf "%s\n" "$1";;
       *)printf  "%s\n" "$PWD/$1";; 
   esac; 
}
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
############################################################
# do the backup (client side)
############################################################
af6_backup () {

    if [ -d "$1" ] ; then
        echo "Backup directory $1:"                  | tee -a $TMP/mail |logger -s -puser.info -t$BASE.$$
        find $1 -type f $LAZY > $TMP/file.lst
    elif [ -z "$1" ] ; then 
        DIR=`pwd`
        echo "Backup directory $DIR:"                | tee -a $TMP/mail |logger -s -puser.info -t$BASE.$$
        find $DIR -type f $LAZY > $TMP/file.lst
    elif [ -f "$1" ] ; then
       echo $1 > $TMP/file.lst
    fi

    while read THISFILE
      do
        MD5=`md5sum $THISFILE|cut -d' ' -f1`

        MD51=`echo $MD5|cut -c1,1`
        MD52=`echo $MD5|cut -c2,2`
        MD53=`echo $MD5|cut -c3,3`

        MYPATH=$TODIR/$MD51/$MD52/$MD53/$MD5
        LOCKDIR=$MYPATH.lock
        COMMAND="mkdir $LOCKDIR;echo \$?"

        RES=`ssh -n $TARGET $COMMAND`
        if [ "$RES" = "0" ] ; then
            LS=`ls -l --time-style="+%Y%m%d%H%M%S" $THISFILE`
            SIZE=`echo $LS|cut -d' ' -f5`
            MDATE=`mdate $THISFILE`
            ABS=`abspath $THISFILE`

            scp $TARGET:$MYPATH.af6 $TMP/$MD5.af6_0 >/dev/null 2>&1

            echo "$MD5;$SIZE;$MDATE;$HOST;\"$ABS\"" >> $TMP/$MD5.af6_0
            sort < $TMP/$MD5.af6_0 > $TMP/$MD5.af6_1
            uniq < $TMP/$MD5.af6_1 > $TMP/$MD5.af6

            NUMTARGET=`ssh -n $TARGET ls $MYPATH $MYPATH.bz2 2>/dev/null|wc -l`
            if [ "$NUMTARGET" = "0" ] ; then
                echo "DOBACKUP file $ABS"                          |tee -a $TMP/mail |logger -s -puser.info -t$BASE.$$
                bzip2 --best --stdout --force $THISFILE > $TMP/$MD5.bz2
                BZSIZE=`ls -l $TMP/$MD5.bz2|cut -d' ' -f5`  
	        
                if [ $SIZE -gt $BZSIZE ] ; then
                    echo "BZIPPED file $ABS. ($SIZE > $BZSIZE)"    |tee -a $TMP/mail |logger -s -puser.info -t$BASE.$$
                    scp $TMP/$MD5.af6 $TMP/$MD5.bz2 $TARGET:$TODIR/$MD51/$MD52/$MD53                   >/dev/null 2>&1
                else
                    echo "COPIED  file $ABS. ($SIZE)"              |tee -a $TMP/mail |logger -s -puser.info -t$BASE.$$
                    scp $TMP/$MD5.af6  $TARGET:$TODIR/$MD51/$MD52/$MD53                                >/dev/null 2>&1
                    scp $THISFILE $TARGET:$MYPATH                                                      >/dev/null 2>&1
                fi
            else
                echo "ALREADYDONE file $ABS"                       |tee -a $TMP/mail |logger -s -puser.info -t$BASE.$$
                diff $TMP/$MD5.af6_0 $TMP/$MD5.af6                                                     >/dev/null 2>&1  
                if [ "$?" -ne "0" ] ; then
                    scp $TMP/$MD5.af6 $TARGET:$TODIR/$MD51/$MD52/$MD53                                 >/dev/null 2>&1  
                fi
            fi

            ssh -n $TARGET "rmdir $LOCKDIR"
        fi
      done < $TMP/file.lst
}
############################################################
# stats & send mail
############################################################
af6_end () {
    if [ ! "$NOMAIL" = "true" ] ; then
        echo '-------------------------------------------------------------'|\
             tee -a $TMP/mail|logger -s -puser.info -t$BASE.$$
        STOP=`date +%s`
        DIFF=`expr $STOP - $START`
        DIFFH=`expr $DIFF / 3600`
        DIFFM=`expr \( $DIFF - \( $DIFFH \* 3600 \) \) / 60`
        DIFFS=`expr $DIFF % 60`
        echo|awk "{printf(\"It took me %d:%02d:%02d to get here with RC %d\n\",$DIFFH,$DIFFM,$DIFFS,$1)}"|\
             tee -a $TMP/mail|logger -s -puser.info -t$BASE.$$

        NUMDO=`grep DOBACKUP < $TMP/mail|wc -l`
        NUMDONE=`grep ALREADYDONE < $TMP/mail|wc -l`
        echo|awk "{printf(\"I backed up %d files, %d where already done\n\",$NUMDO,$NUMDONE)}"|tee -a $TMP/mail|logger -s -puser.info -t$BASE.$$

        NUMBZ=`grep BZIPPED < $TMP/mail|wc -l`
        NUMCP=`grep COPIED  < $TMP/mail|wc -l`
        echo|awk "{printf(\"%d files bzipped, %d files copied\n\",$NUMBZ,$NUMCP)}"|tee -a $TMP/mail|logger -s -puser.info -t$BASE.$$

        ssh $TARGET df | grep _DATA |tee -a $TMP/mail|logger -s -puser.info -t$BASE.$$

        if [ $1 -ne 99 ] ; then
            #
            # We only have a sendmail on the qnap, prepare the mail the hard way
            #
            echo "Subject: AF6Backup $HOST"  >  $TMP/mail2
            echo "From: $MAILTO"             >> $TMP/mail2
            echo "To: $MAILTO"               >> $TMP/mail2
            echo ""                          >> $TMP/mail2
            cat $TMP/mail                    >> $TMP/mail2
            ssh $TARGET sendmail -t           < $TMP/mail2
        fi
        rm -rf $TMP
        exit $1
    else 
        cat $TMP/mail        
        rm -rf $TMP
    fi
}
#############################################################
# frame if called from cron
#############################################################
af6_fromcron () {

    # only once daily
    NOW=`date +%s`
    if [ -f $TMP/stamp ] ; then
        LAST=`cat $TMP/stamp`
        DIFF=`expr $NOW - $LAST`
        # slightly drifting backwards
        if [ "$DIFF" -lt "64800" ] ; then
            echo Not necessary yet.|logger -s -puser.info -t$BASE.$$
            af6_end 99
        else 
            echo $NOW > $TMP/stamp
        fi
    else 
        echo $NOW > $TMP/stamp
    fi

    export FROMCRON=1
    if [ "$HOST" = "elefant" ] ; then

        af6_backup /3data/Fotos
        af6_backup /1data/Video
        af6_backup /1data/astrid
        af6_backup /1data/ich
        af6_backup /0data/Musik
        af6_backup /root
        af6_backup /etc
        af6_backup /1data/physhome/astrid
        af6_backup /1data/physhome/astrid.old
        af6_backup /1data/physhome/ich.old
        af6_backup /home/ich
        af6_backup /data/repository/repos
	
        af6_backup /lost+found
        af6_backup /0data/lost+found
        af6_backup /1data/lost+found
        af6_backup /2data/lost+found
        af6_backup /3data/lost+found
            
    else
        af6_backup /home/ich
    fi
    FROMCRON=0
    af6_end 0 
}
############################################################
# main
############################################################
if [ "$1" = "--nomail" ] ; then
    export NOMAIL=true
    shift
fi
if [ "$1" = "--lazy"  ] ; then
    export LAZY="-mtime -3"
    shift
fi
if [ "$1" = "--nomail" ] ; then
    export NOMAIL=true
    shift
fi

if [ "$1" = "backup" ] ; then
    af6_backup $2
    af6_end 0 
elif [ "$1" = "fromcron" ] ; then
    af6_fromcron
else
    cat<<EOF

usage:
    af6backup <opts> backup <dir>

<opts>:
    --nomail  no mail sent
    --lazy    consider only changes of last days
EOF
    af6_end 1
fi
