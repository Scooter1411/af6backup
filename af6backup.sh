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
MYSELF=$SDIR/$0
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
#
# We only have a sendmail on the qnap, prepare the mail the hard way
#
echo "Subject: Backup $HOST"  >  $TMP.mail
echo "From: $MAILTO"          >> $TMP.mail
echo "To: $MAILTO"            >> $TMP.mail
echo ""                       >> $TMP.mail
#############################################################
# serverBackup, awk-Teil
#############################################################
cat <<EOF > $TMP.serverBackup.awk
BEGIN{
    if( ENVIRON["AF5_DEBUG"] == "true" ){
        print "Debug mode."
        debug=1
    }
    af6readlist(inlist);    
}
{
    ## legacy read from stdin

    ## legacy file format:
    ## <md5>;<size>;<crc>;<source path>

    ## af6 file format:
    ## <md5>;<size>;<mdate>;<host>;<source path>

    l_listcount = split( \$0, l_list, ";" );
    if( l_listcount == 6 ){
        # we allow for one semicolon in file name (but remove it for the list)
        l_list[5] = l_list[5] "_" l_list[6];
        l_listcount = 5;
    }
    if(      l_listcount != 5            ) readerr("wrong.listcount",l_line)
    else if( length(l_list[1]) != 32     ) readerr("wrong.length.of.md5.sum",l_line)
    else if( l_list[1] !~ "^[0-9a-f]*\$" ) readerr("md5.not.hexadecimal",l_line)
    else if( length(l_list[2]) < 1       ) readerr("size.empty",l_line)
    else if( l_list[2] !~ "^[0-9]*\$"    ) readerr("size.not.a.number",l_line)
    else if( length(l_list[3]) < 1       ) readerr("mdate.empty",l_line)
    else if( l_list[3] !~ "^[0-9]*\$"    ) readerr("mdate.empty",l_line)
    else if( length(l_list[4]) < 1       ) readerr("host.empty",l_line)
    else if( length(l_list[5]) < 1       ) readerr("file.name.empty",l_line)
    else {
        # all is well
        map_srcname_md5[l_list[5]";"l_list[1]] = 1;
        if( length( map_md5_size[l_list[1]] ) == 0 ){
            l_diffnum++;
            map_md5_size[l_list[1]]       = l_list[2];
            map_md5_mdate[l_list[1]]      = l_list[3];
            map_md5_host[l_list[1]]       = l_list[4];
            res = "DOBACKUP"
        } else {
            if( map_md5_size[l_list[1]] != l_list[2] ) readerr("size.collision",l_line);
            res = "ALREADYDONE"
        }
        map_md5_srcname[l_list[1]]=l_list[5];
        l_num++;
    }
}
END{
    af6writelist(outlist);    
    print res
}
EOF
#############################################################
# legacyCombine, awk-Teil
#############################################################
cat <<EOF > $TMP.legacyCombine.awk
BEGIN{
    if( ENVIRON["AF5_DEBUG"] == "true" ){
        print "Debug mode."
        debug=1
    }
    af6readlist(inlist);    
}
{
    ## legacy read from stdin

    ## legacy file format:
    ## <md5>;<size>;<crc>;<source path>

    ## af6 file format:
    ## <md5>;<size>;<mdate>;<host>;<source path>

    if( substr(\$1,1,3) == pattern ){
        l_listcount = split( \$0, l_list, ";" );
        if( l_listcount == 5 ){
            # we allow for one semicolon in file name (but remove it for the list)
            l_list[4] = l_list[4] "_" l_list[5];
            l_listcount = 4;
        }
        if(      l_listcount != 4            ) readerr("wrong.listcount",l_line)
        else if( length(l_list[1]) != 32     ) readerr("wrong.length.of.md5.sum",l_line)
        else if( l_list[1] !~ "^[0-9a-f]*\$" ) readerr("md5.not.hexadecimal",l_line)
        else if( length(l_list[2]) < 1       ) readerr("size.empty",l_line)
        else if( l_list[2] !~ "^[0-9]*\$"    ) readerr("size.not.a.number",l_line)
        else if( length(l_list[4]) < 1       ) readerr("file.name.empty",l_line)
        else {
            # all is well
            map_srcname_md5[l_list[4]";"l_list[1]] = 1;
            if( length( map_md5_size[l_list[1]] ) == 0 ){
                l_diffnum++;
                map_md5_size[l_list[1]]       = l_list[2];
                map_md5_mdate[l_list[1]]      = filedate( l_list[1] )
            } else {
                if( map_md5_size[l_list[1]] != l_list[2] ) readerr("size.collision",l_line);
            }
            map_md5_srcname[l_list[1]]=l_list[4];
            map_md5_host[l_list[1]]="elefant";
            l_num++;
        }
        
    }
}
END{
    af6writelist(outlist);    
}
EOF
#############################################################
# awk-Bibliothek
#############################################################
cat <<EOF > $TMP.lib.awk
function tgtname( md5 ){
    return "$TODIR" "/" substr(md5,1,1) "/" substr(md5,2,1) "/" substr(md5,3,1) "/" md5;
}
function filedate( name, l_cmd, l_line, l_word, l_res ){
    l_cmd = "ls -l --time-style=\"+%Y%m%d%H%M%S\" \\"" tgtname( name ) "\\" 2>/dev/null";
    l_cmd | getline l_line;
    close(l_cmd);
    split( l_line, l_word, " " );
    if( length( l_word[6] ) > 0 ) {
        l_res = l_word[6];
    } else {
        l_cmd = "ls -l --time-style=\"+%Y%m%d%H%M%S\" \\"" tgtname( name ) ".bz2\\" 2>/dev/null";
        l_cmd | getline l_line;
        close(l_cmd);
        split( l_line, l_word, " " );
        if( length( l_word[6] ) > 0 ) {
            l_res = l_word[6];
        } else {
            l_res = 20131111111111;
        }
    }
    return l_res;
}
function readerr( message, line, l_file ){
    print message line
    l_file = "$KAPUTT" "." message;
    print line >> l_file;
    errnum++;
}
##
## af6 file format:
## <md5>;<size>;<mdate>;<host>;<source path>
##
## parameters: filename (the file name)
## local variables: l_eof, l_line, l_list, l_num, l_diffnum, l_listcount, l_msg, l_tnull, l_teins
## global variables: errnum          (# errors encountered)
##                   map_srcname_md5 (map original file name -> md5)
##                   map_md5_size    (map md5 -> original size)
##                   map_md5_mdate   (map md5 -> mdate)
##                   map_md5_srcname (map md5 -> original file name)
##
function af6readlist( filename, l_eof, l_line, l_list, l_num, l_diffnum, l_listcount, l_msg, l_tnull, l_teins  ){

    l_tnull = systime();
    l_num = 0;
    l_diffnum = 0;
    errnum = 0;
    l_eof = getline l_line < filename;
    while( l_eof == 1 ){
        l_listcount = split( l_line, l_list, ";" );
        if( l_listcount == 6 ){
            # we allow for one semicolon in file name (but remove it for the list)
            l_list[4] = l_list[5] "_" l_list[6];
            l_listcount = 5;
        }
        if(      l_listcount != 5            ) readerr("wrong.listcount",l_line)
        else if( length(l_list[1]) != 32     ) readerr("wrong.length.of.md5.sum",l_line)
        else if( l_list[1] !~ "^[0-9a-f]*\$" ) readerr("md5.not.hexadecimal",l_line)
        else if( length(l_list[2]) < 1       ) readerr("size.empty",l_line)
        else if( l_list[2] !~ "^[0-9]*\$"    ) readerr("size.not.a.number",l_line)
        else if( length(l_list[3]) < 1       ) readerr("mdate.empty",l_line)
        else if( l_list[3] !~ "^[0-9]*\$"    ) readerr("mdate.empty",l_line)
        else if( length(l_list[4]) < 1       ) readerr("host.empty",l_line)
        else if( length(l_list[5]) < 1       ) readerr("file.name.empty",l_line)
        else {
            # all is well
            map_srcname_md5[l_list[5]";"l_list[1]] = 1;
            if( length( map_md5_size[l_list[1]] ) == 0 ){
                l_diffnum++;
                map_md5_size[l_list[1]]       = l_list[2];
                map_md5_mdate[l_list[1]]      = l_list[3];
                map_md5_host[l_list[1]]       = l_list[4];
            } else {
                if( map_md5_size[l_list[1]] != l_list[2] ) readerr("size.collision",l_line);
            }
            map_md5_srcname[l_list[1]]=l_list[5];
            l_num++;
        }
        l_eof = getline l_line  < filename;
    }
    l_teins = systime();
    printf("Read within %d sec %7d lines/%6d files of %s.\n",l_teins - l_tnull,l_num,l_diffnum,filename);
    if( debug || errnum > 0 ){
        printf("Found %s errors.\n",errnum);
    }
    close(filename);   
}
##
## af6 file format:
## <md5>;<size>;<mdate>;<host>;<source path>
##
## parameters: filename (the file name)
## local variables: l_eof, l_line, l_list, l_num, l_diffnum, l_listcount, l_msg, l_tnull, l_teins
## global variables: errnum          (# errors encountered)
##                   map_srcname_md5 (map original file name -> md5)
##                   map_md5_size    (map md5 -> original size)
##                   map_md5_mdate   (map md5 -> mdate)
##                   map_md5_srcname (map md5 -> original file name)
##
function af6writelist( filename, l_key, l_list, l_md5, l_srcname, l_num, l_tnull, l_teins, l_tzwei, l_tdrei ){

    l_num  = 0;
    l_diff = 0;
    l_tnull = systime();
    l_cmd = sprintf("cat /dev/null > %s",filename)
    system(l_cmd);
    l_teins = systime();
    for( l_key in map_srcname_md5) {
         split( l_key, l_list, ";" );
         l_srcname = l_list[1];
         l_md5     = l_list[2];
         if( length( map_md5_size[l_md5] ) > 0 ){
             printf("%s;%s;%s;%s;%s\n",l_md5,map_md5_size[l_md5],map_md5_mdate[l_md5],map_md5_host[l_md5],l_srcname) >> filename;
             l_num++;
         }
    }
    close(filename);   
    l_tzwei = systime();
    printf("Wrote %7d lines to %s.\n",l_num,filename);
    if( debug ) {
        printf("   time to clean temporary file: %d sec.\n", l_teins - l_tnull );
        printf("   time to write temporary file: %d sec.\n", l_tzwei - l_teins );
        printf("   time to move to final file:   %d sec.\n", l_tdrei - l_tzwei );
        printf("   total time:                   %d sec.\n", l_tdrei - l_tnull );
    }    
}
EOF
cat $TMP.lib.awk >> $TMP.serverBackup.awk
cat $TMP.lib.awk >> $TMP.legacyCombine.awk
############################################################
# start mutex section
############################################################
af6_mutex_in () {
    PID=/var/run/$BASE.pid
    if [ -s $PID ] ; then
        ps -e|grep `cat $PID` > /dev/null
        if [ "$?" == "0" ] ; then
            echo other process `cat $PID` still running|logger -s -puser.err -t$BASE.$$ 
            sleep 10
            if [ -s $PID ] ; then
                ps -e|grep `cat $PID` > /dev/null
                if [ "$?" == "0" ] ; then
                    echo other process `cat $PID` still running|logger -s -puser.err -t$BASE.$$ 
                    sleep 100
                    if [ -s $PID ] ; then
                        ps -e|grep `cat $PID` > /dev/null
                        if [ "$?" == "0" ] ; then
                            echo other process `cat $PID` still running|logger -s -puser.err -t$BASE.$$ 
                            sleep 1000
                            if [ -s $PID ] ; then
                                ps -e|grep `cat $PID` > /dev/null
                                if [ "$?" == "0" ] ; then
                                    echo other process `cat $PID` still running|logger -s -puser.err -t$BASE.$$ 
                                    exit 42
                                else
                                    echo other process `cat $PID` died some time ago|tee -a $TMP.mail|logger -s -puser.err -t$BASE.$$ 
                                fi
                           fi
                       else
                    echo other process `cat $PID` died some time ago|tee -a $TMP.mail|logger -s -puser.err -t$BASE.$$ 
                fi
            fi
                       else
                    echo other process `cat $PID` died some time ago|tee -a $TMP.mail|logger -s -puser.err -t$BASE.$$ 
                fi
            fi
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
# do the backup (client side)
############################################################
af6_backup () {

    if [ -d "$1" ] ; then
        find $1 -type f $LAZY -exec $MYSELF --nomail backup {} \;| tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
    elif [ -z "$1" ] ; then 
        find . -type f $LAZY -exec $MYSELF --nomail backup {} \;| tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
    elif [ -f "$1" ] ; then
        af6_mutex_in
        set -x
        MD5=`md5sum $1|cut -d' ' -f1`
        LS=`ls -l --time-style="+%Y%m%d%H%M%S" $1`
        SIZE=`echo $LS|cut -d' ' -f5`
        MDATE=`echo $LS|cut -d' ' -f6`
        ABS=`abspath $1`
        #ssh $TARGET af6Server backup $MD5 $SIZE $MDATE $HOST $ABS 
        echo "serverBackup $MD5 $SIZE $MDATE $HOST \"$ABS\""|logger -s -puser.info -t$BASE.$$
        #echo "DOBACKUP" > $TMP.serverOut
        ./af6backup.sh serverBackup $MD5 $SIZE $MDATE $HOST "$ABS" | tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$

        cat $TMP.mail
        RETCODE=`tail -1 < $TMP.mail`   
        if [ "$RETCODE" == "DOBACKUP" ] ; then
            echo "We really have to backup this file $ABS."|tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
            mkdir -p $TMP.dir
            bzip2 --best --stdout --force $1 > $TMP.dir/$MD5.bz2
            BZSIZE=`ls -l $TMP.dir/$MD5.bz2|cut -d' ' -f5`  
            EINS=`echo $MD5|cut -c1-1`
            ZWEI=`echo $MD5|cut -c2-2`
            DREI=`echo $MD5|cut -c3-3`
            DIR=$TODIR/$EINS/$ZWEI/$DREI
            if [ $SIZE -gt $BZSIZE ] ; then
                cp $TMP.dir/$MD5.bz2 $DIR
            else
                cp $1 $DIR/$MD5
            fi
        elif [ "$RETCODE" == "ALREADYDONE" ] ; then
            echo "This file $ABS was already backed up."|tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
        else
            echo "Strange retcode $RETCODE"|tee -a $TMP.mail |logger -s -puser.info -t$BASE.$$
        fi
        cat $TMP.mail
        af6_mutex_out 
    fi
    af6_end 0
}
############################################################
af6_end () {
    set -x
    if [ ! "$NOMAIL" = "true" ] ; then
        STOP=`date +%s`
        DIFF=`expr $STOP - $START`
        DIFFH=`expr $DIFF / 3600`
        DIFFM=`expr \( $DIFF - \( $DIFFH \* 3600 \) \) / 60`
        DIFFS=`expr $DIFF % 60`
        echo|awk "{printf(\"It took me %d:%02d:%02d to get here with RC %d\n\",$DIFFH,$DIFFM,$DIFFS,$1)}"|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$
        if [ $1 -ne 99 ] ; then
            ssh $TARGET sendmail -t < $TMP.mail
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
# do the backup (server side)
############################################################
af6_serverBackup () {

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

    # todo check params    
    MD5=$1
    #echo "MD5=$MD5"|logger -s -puser.info -t$BASE.$$
    SIZE=$2
    #echo "SIZE=$SIZE"|logger -s -puser.info -t$BASE.$$
    MDATE=$3
    #echo "MDATE=$MDATE"|logger -s -puser.info -t$BASE.$$
    HOST=$4
    #echo "HOST=$HOST"|logger -s -puser.info -t$BASE.$$
    ABS=$5
    #echo "ABS=$ABS"|logger -s -puser.info -t$BASE.$$

    PATTERN=`echo $MD5|cut -c1-3`
    af6_legacyCombine $PATTERN

    echo "$MD5;$SIZE;$MDATE;$HOST;$ABS" | awk -f $TMP.serverBackup.awk -F';' \
        -v pattern=$PATTERN -v inlist=$NAMESDIR/$PATTERN -v outlist=$NAMESDIR/$PATTERN.$$ 
    
    diff $NAMESDIR/$PATTERN $NAMESDIR/$PATTERN.$$ | grep '^< ' | cut -c3- > $OLDDIR/$PATTERN.$DATE

    bzip2 --best --force $NAMESDIR/$PATTERN
    mv $NAMESDIR/$PATTERN.$$ $NAMESDIR/$PATTERN 
}
############################################################
# merge legacy name list
############################################################
af6_legacyCombine () {

    mkdir -p $NAMESDIR  2>/dev/null
    mkdir -p $OLDDIR  2>/dev/null

    if [ -z "$1" ] ; then 
        for I in 0 1 2 3 4 5 6 7 8 9 a b c d e f
          do
            for J in 0 1 2 3 4 5 6 7 8 9 a b c d e f
              do
                for K in 0 1 2 3 4 5 6 7 8 9 a b c d e f
                  do
                    $MYSELF combine $I$J$K
                  done
              done
          done
    else 
        #af6_mutex_in
        PATTERN=`echo $1|cut -c1-3|grep '^[0-9a-f][0-9a-f][0-9a-f]$'`
        if [ -n "$PATTERN" ] ; then 
            if [ -s $LEGACYLIST ] ; then
                if [ $LEGACYLIST -nt $NAMESDIR/$PATTERN ] ; then
                    awk -f $TMP.legacyCombine.awk -F';' \
                        -v pattern=$PATTERN -v inlist=$NAMESDIR/$PATTERN \
                        -v outlist=$NAMESDIR/$PATTERN.$$ < $LEGACYLIST
                    diff $NAMESDIR/$PATTERN $NAMESDIR/$PATTERN.$$ | grep '^< ' | cut -c3- > $OLDDIR/$PATTERN.$DATE
    
                    bzip2 --best --force $NAMESDIR/$PATTERN
                    mv $NAMESDIR/$PATTERN.$$ $NAMESDIR/$PATTERN 
                fi
            fi
        fi
    fi
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

#set -x
if [ "$1" = "backup" ] ; then
    af6_backup $2
elif [ "$1" = "fromcron" ] ; then
    af6_fromcron
elif [ "$1" = "serverBackup" ] ; then
    #af6_mutex_in
    shift
    af6_serverBackup $*
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
af6_end 0
