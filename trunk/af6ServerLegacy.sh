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
#############################################################
# main configuration
#############################################################
MOUNTDIR=/share/HDA_DATA/Public
#############################################################
TODIR=$MOUNTDIR/af5backup.dir
OLDDIR=$TODIR/old
LEGACYLIST=$TODIR/af5backup.names
NAMESDIR=$TODIR/af6backup.names
MAILTO="alexander.franz.1411@gmail.com"
#############################################################
# Combine, awk-Teil
#############################################################
cat <<EOF > $TMP.legacy.awk
BEGIN{
    if( ENVIRON["AF5_DEBUG"] == "true" ){
        print "Debug mode."
        debug=1
    }
}
{
    ## legacy file format:
    ## <md5>;<size>;<crc>;<source path>

    ## af6 file format:
    ## <md5>;<size>;<mdate>;<host>;<source path>

    if( substr(\$1,1,3) == pattern ){
        printf("%s;%s;%s;elefant;%s\n",\$1,\$2,filedate(\$1),\$4)
    }
}
END{
}
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
EOF
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
af6_end () {
    if [ ! "$FROMCRON" = "1" ] ; then
        STOP=`date +%s`
        DIFF=`expr $STOP - $START`
        DIFFH=`expr $DIFF / 3600`
        DIFFM=`expr \( $DIFF - \( $DIFFH \* 3600 \) \) / 60`
        DIFFS=`expr $DIFF % 60`
        echo|awk "{printf(\"It took me %d:%02d:%02d to get here with RC %d\n\",$DIFFH,$DIFFM,$DIFFS,$1)}"|tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$
        if [ $1 -ne 99 ] ; then
            #mail -s Backup $MAILTO < $TMP.mail
            #ssh astrid@elefant mail -s Backup $MAILTO < $TMP.mail
            echo bla
        fi
        rm $TMP.* 
        af6_mutex_out 
        exit $1
    fi
}
############################################################
af6_combine () {

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
        af6_mutex_in
        PATTERN=`echo $1|cut -c1-3|grep '^[0-9a-f][0-9a-f][0-9a-f]$'`
        if [ -n "$PATTERN" ] ; then 
            if [ -s $LEGACYLIST ] ; then
                if [ -s $NAMESDIR/$PATTERN.legacy.bz2 ] ; then
                    bunzip2 --stdout $NAMESDIR/$PATTERN.legacy.bz2 > $NAMESDIR/$PATTERN.legacy.old
                else
                    cat /dev/null > $NAMESDIR/$PATTERN.legacy.old
                fi
                awk -f $TMP.legacy.awk -F';' -v pattern=$PATTERN < $LEGACYLIST > $NAMESDIR/$PATTERN.legacy
                diff $NAMESDIR/$PATTERN.legacy $NAMESDIR/$PATTERN.legacy.old | grep '^< ' | cut -c3- > $OLDDIR/$PATTERN.$DATE
                if [ ! -s $OLDDIR/$PATTERN.$DATE ] ; then
                     rm $OLDDIR/$PATTERN.$DATE
                fi
                if [ -s $NAMESDIR/$PATTERN ] ; then
                    cat $NAMESDIR/$PATTERN.legacy $NAMESDIR/$PATTERN | sort | uniq > $NAMESDIR/$PATTERN.sorted
                    rm $NAMESDIR/$PATTERN
                    mv $NAMESDIR/$PATTERN.sorted $NAMESDIR/$PATTERN
                else
                    cp $NAMESDIR/$PATTERN.legacy $NAMESDIR/$PATTERN
                fi
                bzip2 --best --force $NAMESDIR/$PATTERN.legacy
                rm $NAMESDIR/$PATTERN.legacy.old
            fi
        fi
    fi
}
############################################################
# main
############################################################
if [ "$1" = "--debug" ] ; then
    export AF6_DEBUG=true
    shift
fi

if [ "$1" = "combine" ] ; then
    af6_combine $2
else
    cat<<EOF

usage:
    afServerLegacy <opts> combine [<id>]

<opts>:
    --debug some output
EOF
    af6_end 1
fi
af6_end 0
EOF