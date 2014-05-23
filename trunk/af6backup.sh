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
# do the backup (client side)
############################################################
af6_backup () {

    if [ -d "$1" ] ; then
        echo "Backup directory $1:"                  | tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
        find $1 -type f $LAZY -exec $MYSELF --nomail backup {} \; >> $TMP.mail
    elif [ -z "$1" ] ; then 
        DIR=`pwd`
        echo "Backup directory $DIR:"                | tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
        find . -type f $LAZY -exec $MYSELF --nomail backup {} \; >> $TMP.mail
    elif [ -f "$1" ] ; then
        MD5=`md5sum $1|cut -d' ' -f1`

        MD51=`echo $MD5|cut -c1,1`
        MD52=`echo $MD5|cut -c2,2`
        MD53=`echo $MD5|cut -c3,3`

        LS=`ls -l --time-style="+%Y%m%d%H%M%S" $1`
        SIZE=`echo $LS|cut -d' ' -f5`
        MDATE=`echo $LS|cut -d' ' -f6`
        ABS=`abspath $1`

        MYPATH=$TODIR/$MD51/$MD52/$MD53/$MD5
        LOCKDIR=$MYPATH.lock
        COMMAND="mkdir $LOCKDIR;echo \$?"
        RES=`ssh $TARGET $COMMAND`
        if [ "$RES" = "0" ] ; then
            mkdir -p $TMP 2>/dev/null
            scp $TARGET:$MYPATH.af6 $TMP 2>/dev/null
            echo $?

            echo "$MD5;$SIZE;$MDATE;$HOST;\"$ABS\"" >> $TMP/$MD5.af6
            sort < $TMP/$MD5.af6 > $TMP/$MD5.tmp
            uniq < $TMP/$MD5.tmp > $TMP/$MD5.af6
            cat $TMP/$MD5.af6

            NUMTARGET=`ssh $TARGET ls $MYPATH $MYPATH.bz2 2>/dev/null|wc -l`
            if [ "$NUMTARGET" = "0" ] ; then
                echo "DOBACKUP file $ABS"                                              |tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
                bzip2 --best --stdout --force $1 > $TMP/$MD5.bz2
                BZSIZE=`ls -l $TMP/$MD5.bz2|cut -d' ' -f5`  
	        
                if [ $SIZE -gt $BZSIZE ] ; then
                    echo "BZIPPED file $ABS."                                          |tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
                    scp $TMP/$MD5.af6 $TMP/$MD5.bz2 $TARGET:$TODIR/$MD51/$MD52/$MD53   |tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
                else
                    echo "COPIED  file $ABS."                                          |tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
                    scp $TMP/$MD5.af6  $TARGET:$TODIR/$MD51/$MD52/$MD53                |tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
                    scp $1 $TARGET:$MYPATH
                fi
            else
                echo "ALREADYDONE file $ABS"                                           |tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
                scp $TMP/$MD5.af6 $TARGET:$TODIR/$MD51/$MD52/$MD53                     |tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
            fi

            ssh $TARGET "rmdir $LOCKDIR"
        fi
    fi
    af6_end 0
}
############################################################
af6_end () {
    if [ ! "$NOMAIL" = "true" ] ; then
        echo '-------------------------------------------------------------'|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$
        STOP=`date +%s`
        DIFF=`expr $STOP - $START`
        DIFFH=`expr $DIFF / 3600`
        DIFFM=`expr \( $DIFF - \( $DIFFH \* 3600 \) \) / 60`
        DIFFS=`expr $DIFF % 60`
        echo|awk "{printf(\"It took me %d:%02d:%02d to get here with RC %d\n\",$DIFFH,$DIFFM,$DIFFS,$1)}"|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$

        NUMDO=`grep DOBACKUP < $TMP.mail|wc -l`
        NUMDONE=`grep ALREADYDONE < $TMP.mail|wc -l`
        echo|awk "{printf(\"I backed up %d files, %d where already done\n\",$NUMDO,$NUMDONE)}"|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$

        NUMBZ=`grep BZIPPED < $TMP.mail|wc -l`
        NUMCP=`grep COPIED  < $TMP.mail|wc -l`
        echo|awk "{printf(\"%d files bzipped, %d files copied\n\",$NUMBZ,$NUMCP)}"|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$

        if [ $1 -ne 99 ] ; then
            #
            # We only have a sendmail on the qnap, prepare the mail the hard way
            #
            echo "Subject: Backup $HOST"  >  $TMP.mail2
            echo "From: $MAILTO"          >> $TMP.mail2
            echo "To: $MAILTO"            >> $TMP.mail2
            echo ""                       >> $TMP.mail2
            cat $TMP.mail                 >> $TMP.mail2
            ssh $TARGET sendmail -t        < $TMP.mail2
        fi
        rm -rf $TMP.* 
        exit $1
    else 
        cat $TMP.mail        
    fi
}
#############################################################
# 
#############################################################
af6_fromcron () {

    # only once daily
    NOW=`date +%s`
    if [ -f $TODIR/$BASE.stamp ] ; then
        LAST=`cat $TODIR/$BASE.stamp`
        DIFF=`expr $NOW - $LAST`
        # slightly drifting backwards
        if [ "$DIFF" -lt "64800" ] ; then
            echo Not necessary yet.|logger -s -puser.info -t$BASE.$$
            af6_end 99
        else 
            echo $NOW > $TODIR/$BASE.stamp
        fi
    else 
        echo $NOW > $TODIR/$BASE.stamp
    fi

    export FROMCRON=1
    af6_clean
    if [ "$HOST" = "elefant" ] ; then
        af6_combine

        #DOM=`date +%d`
        #if [ "$DOM" = "13" ] ; then
        #    # once a month checking
        #    af6_check
        #else
        #    if [ "$DOM" = "26" ] ; then
        #        # once a month not lazy
        #        export LAZY=""
        #    fi
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
            
            /sbin/mount.cifs //drache/C /dracheC -o user=ich,password=cc440a08 2>&1  > $TMP.mountout
            RC=$?
            echo "RC $RC" >>  $TMP.mountout
            cat $TMP.mountout >> $TMP.mail
            logger -s -puser.info -t$BASE.$$ < $TMP.mountout
            if [ "$RC" = "0" ] ; then
                 af6_backup /dracheC/Users/ich/Documents
                 af6_backup /dracheC/Users/ich/Videos
                 af6_backup /dracheC/Users/ich/Music
                 af6_backup /dracheC/Users/ich/AppData
                 sleep 3
                 /bin/umount /dracheC
            fi
                
            af6_combine
        #fi 

        df $MOUNTDIR |tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$
        df $MOUNTDIR2|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$
        #af6_finally
    fi
    FROMCRON=0
    af6_end 0 
}
############################################################
# main
############################################################
if [ "$1" = "--force" ] ; then
    export FORCE=true
    shift
fi
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
if [ "$1" = "--force" ] ; then
    export FORCE=true
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
elif [ "$1" = "fromcron" ] ; then
    af6_fromcron
else
    cat<<EOF

usage:
    af6backup <opts> backup <dir>

<opts>:
    --force   rebackup everything
    --nomail  no mail sent
    --lazy    consider only changes of last week
EOF
    af6_end 1
fi
