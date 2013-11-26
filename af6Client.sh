#!/bin/sh
#############################################################
# Das große Backupskript für zu Hause (Client)
# Die sechste Inkarnation...
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
MYSELF=$SDIR/$0
TMP=/tmp/$BASE.$$
#date 1>&2
logger -s -puser.info -t$BASE.$$ started
HOST=`hostname`
TARGET=admin@quokka
#############################################################
# main configuration
#############################################################
MOUNTDIR=/share/HDA_DATA/Public
MAXPROC=20
COMMITEVERY=1000
SLEEP=10
#############################################################
TODIR=$MOUNTDIR/af5backup.dir
OLDDIR=$TODIR/old
LEGACYLIST=$TODIR/af5backup.names
NAMESDIR=$TODIR/af6backup.names
MAILTO="alexander.franz.1411@gmail.com"
############################################################
# start mutex section
############################################################
af6_mutex_in () {
    PID=/var/run/$BASE.pid
    if [ -s $PID ] ; then
        ps -e|grep `cat $PID` > /dev/null
        if [ "$?" == "0" ] ; then
            echo other process `cat $PID` still running|logger -s -puser.err -t$BASE.$$ 
            exit 42
        else 
            echo other process `cat $PID` died some time ago|tee -a $TMP.mail|logger -s -puser.err -t$BASE.$$ 
        fi
    fi
    echo $$ > $PID
}
############################################################
# end mutex section
############################################################
af6_mutex_out () {
    rm -f $PID
}
############################################################
# canonical path name
############################################################
abspath () { 
   case "$1" in 
       /*)printf "%s\n" "$1";;
       *)printf  "%s\n" "$PWD/$1";; 
   esac; 
}
############################################################
# do the backup
############################################################
af6_backup () {

    if [ -d "$1" ] ; then
        find $1 -type f $LAZY -exec $MYSELF backup {} \;
    elif [ -z "$1" ] ; then 
        find . -type f $LAZY -exec $MYSELF backup {} \;
    elif [ -f "$1" ] ; then
        af6_mutex_in
        MD5=`md5sum $1|cut -d' ' -f1`
        LS=`ls -l --time-style="+%Y%m%d%H%M%S" $1`
        SIZE=`echo $LS|cut -d' ' -f5`
        MDATE=`echo $LS|cut -d' ' -f6`
        ABS=`abspath $1`
        #ssh $TARGET af6Server backup $MD5 $SIZE $MDATE $HOST $ABS 
        echo "checkBackup $MD5 $SIZE $MDATE $HOST \"$ABS\""|logger -s -puser.info -t$BASE.$$
        bash -x ./af6Server.sh checkBackup $MD5 $SIZE $MDATE $HOST "$ABS" | tee $TMP.serverOut
        RETCODE=`tail -1 < $TMP.serverOut`   
        if [ "$RETCODE" == "DOBACKUP" ] ; then
            echo "We really have to backup this file $ABS."
            mkdir -p $TMP.dir
            bzip2 --best --stdout --force $1 > $TMP.dir/$MD5.bz2
            BZSIZE=`ls -l $TMP.dir/$MD5.bz2|cut -d' ' -f5`  
            EINS=`echo $MD5|cut -c1-1`
            ZWEI=`echo $MD5|cut -c2-2`
            DREI=`echo $MD5|cut -c3-3`
            TARGET=$TODIR/$EINS/$ZWEI/$DREI
            mkdir -p $TARGET
            if [ $SIZE -gt $BZSIZE ] ; then
                cp $TMP.dir/$MD5.bz2 $TARGET
            else
                cp $1 $TARGET/$MD5
            fi
        elif [ "$RETCODE" == "ALREADYDONE" ] ; then
            echo "This file $ABS was already backed up."
        else
            echo "Strange retcode $RETCODE"
        fi
        af6_mutex_out 
    fi
}
#############################################################
# Erstmal räumen wir auf.
#############################################################
af6_clean () {
    find /tmp -type f -name "*mpg"  -mtime +1 -exec rm -f {} \;
    find /tmp -type f -name "*mpeg" -mtime +1 -exec rm -f {} \;
    find /tmp -type f -name "*avi"  -mtime +1 -exec rm -f {} \;
    find /tmp -type f -name "*wmv"  -mtime +1 -exec rm -f {} \;
    
    for i in `find /home -type d -name Trash`
      do 
        find $i -mtime +1 -type f -exec rm {} \; -print|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$ 2>&1 
      done
    
    for i in `find /home -type d -name .mozilla`
      do 
        for j in `find $i -type d -name "Cache*"`
          do
            find $j -mtime +1 -type f -exec rm {} \; -print|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$ 2>&1 
          done
      done
    
    for i in `find /home -type d -name .netscape`
      do 
        for j in `find $i -type d -name "cache"`
          do
            find $j -mtime +1 -type f -exec rm {} \; -print|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$ 2>&1 
          done
      done
    
    for i in `find /home -type d -name .kde`
      do 
        for j in `find $i -type d -name "cache"`
          do
            find $j -mtime +1 -type f -exec rm {} \; -print|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$ 2>&1 
          done
      done
    
    for i in `find /root -type d -name Trash`
      do 
        find $i -mtime +1 -type f -exec rm {} \; -print|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$ 2>&1 
      done
    
    for i in `find /root -type d -name .mozilla`
      do 
        for j in `find $i -type d -name "Cache*"`
          do
            find $j -mtime +1 -type f -exec rm {} \; -print|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$ 2>&1 
          done
      done
    
    for i in `find /root -type d -name .netscape`
      do 
        for j in `find $i -type d -name "cache"`
          do
            find $j -mtime +1 -type f -exec rm {} \; -print|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$ 2>&1 
          done
      done
    
    for i in `find /root -type d -name .kde`
      do 
        for j in `find $i -type d -name "cache"`
          do
            find $j -mtime +1 -type f -exec rm {} \; -print|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$ 2>&1 
          done
      done
}    
############################################################
af6_end () {
    if [ ! "$FROMCRON" = "1" ] ; then
        STOP=`date +%s`
        DIFF=`expr $STOP - $START`
        DIFFH=`expr $DIFF / 3600`
        DIFFM=`expr \( $DIFF - \( $DIFFH \* 3600 \) \) / 60`
        DIFFS=`expr $DIFF % 60`
        echo|awk "{printf(\"It took me %d:%02d:%02d to get here with RC %d\n\",$DIFFH,$DIFFM,$DIFFS,$1)}"|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$
        #umount $MOUNTDIR 2>&1 |logger -s -puser.info -t$BASE.$$
        #mount | grep $MOUNTDIR > /dev/null
        #if [ "$?" = "0" ] ; then
        #    echo "Sleeping somwhat" |logger -s -puser.info -t$BASE.$$
        #    sleep 300
        #    umount $MOUNTDIR 2>&1 |logger -s -puser.info -t$BASE.$$
        #fi
        if [ $1 -ne 99 ] ; then
            #mail -s Backup $MAILTO < $TMP.mail
            ssh astrid@elefant mail -s Backup $MAILTO < $TMP.mail
        fi
        rm -rf $TMP.* 
        exit $1
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
# prepare copy and bzip2 scripts (with .check file creation) 
############################################################
cat <<EOF > $TMP.cp
    #if [ "\$AF6_DEBUG" = "true" ] ; then    
    #    set -x
    #fi
    cp -p "\$1" \$2
    MD5=\`md5sum \$2|awk '{print \$1}'\`
    BUF=\`cksum \$2\`
    CRC=\`echo \$BUF|awk '{print \$1}'\`
    SIZ=\`echo \$BUF|awk '{print \$2}'\`
    echo \$MD5';'\$CRC';'\$SIZ';'\$2 > \$2.check
EOF
cat <<EOF > $TMP.bz
    #if [ "\$AF6_DEBUG" = "true" ] ; then    
    #    set -x
    #fi
    bzip2 --best --stdout --keep "\$1" > \$2
    MD5=\`md5sum \$2|awk '{print \$1}'\`
    BUF=\`cksum \$2\`
    CRC=\`echo \$BUF|awk '{print \$1}'\`
    SIZ=\`echo \$BUF|awk '{print \$2}'\`
    echo \$MD5';'\$CRC';'\$SIZ';'\$2 > \$2.check
EOF
#cat $TMP.cp
#cat $TMP.bz
#exit
chmod 777 $TMP.cp $TMP.bz
############################################################
# main
############################################################
if [ "$1" = "--force" ] ; then
    export FORCE=true
    shift
fi
if [ "$1" = "--debug" ] ; then
    export AF6_DEBUG=true
    shift
fi
if [ "$1" = "--lazy"  ] ; then
    export LAZY="-mtime -3"
    shift
fi
if [ "$1" = "--debug" ] ; then
    export AF6_DEBUG=true
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
if [ "$1" = "--debug" ] ; then
    export AF6_DEBUG=true
    shift
fi

if [ "$1" = "backup" ] ; then
    af6_backup $2
elif [ "$1" = "fromcron" ] ; then
    af6_fromcron
else
    cat<<EOF

usage:
    af6backup <opts> clean
    af6backup <opts> backup <dir>
    af6backup <opts> backupcheck <dir>
    af6backup <opts> check
    af6backup <opts> kill
    af6backup <opts> killlist <list>
    af6backup <opts> greplist <list>
    af6backup <opts> fromcron

<opts>:
    --force rebackup everything
    --debug some output
    --lazy  consider only changes of last week
EOF
    af6_end 1
fi
af6_end 0
