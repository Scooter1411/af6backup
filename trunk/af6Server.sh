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
OLDTARGET=admin@quokka
#############################################################
# main configuration
#############################################################
MOUNTDIR=/share/HDA_DATA/Public
#MOUNTDIR2=/backup/mount2
#MAXPROC=20
#COMMITEVERY=1000
#SLEEP=10
#############################################################
TODIR=$MOUNTDIR/af5backup.dir
OLDDIR=$TODIR/old
LEGACYLIST=$TODIR/af5backup.names
NAMESDIR=$TODIR/af6backup.names

#KAPUTT=$OLDDIR/$BASE.$DATE.$$.kaputt
#LOSTDIR=/tmp/lost
#LOSTLIST=$OLDDIR/$BASE.$DATE.$$.lost

#ADDED=$OLDDIR/$BASE.$DATE.$$.added
#TRASHDIR=/tmp/trash
#TRASH=$TRASHDIR/$BASE.$DATE.$$.trash
MAILTO="alexander.franz.1411@gmail.com"
#############################################################
# Combine, awk-Teil
#############################################################
cat <<EOF > $TMP.combine.awk
BEGIN{
    if( ENVIRON["AF5_DEBUG"] == "true" ){
        print "Debug mode."
        debug=1
    }
    readnamelist( "$NAMELIST" );
}
{
    readnamelist( \$0 );
}
END{
    writenamelist();
    ## nonobvious way to clean arrays
    # split("",map_srcname_md5);
    # split("",map_md5_size);
    # split("",map_md5_crc);
    # readnamelist( "$NAMELIST" );
}
EOF
#############################################################
# awk-Bibliothek
#############################################################
cat <<EOF > $TMP.lib.awk
function tgtname( md5 ){
    return "$TODIR" "/" substr(md5,1,1) "/" substr(md5,2,1) "/" substr(md5,3,1) "/" md5;
}
function readerr( message, line, l_file ){
    if( debug ) print message line
    l_file = "$KAPUTT" "." message;
    print line >> l_file;
    errnum++;
}
## file format:
## <md5>;<size>;<crc>;<source path>
## parameters: filename (the file name)
## local variables: l_eof, l_line, l_list, l_num, l_diffnum, l_listcount, l_msg, l_tnull, l_teins
## global variables: errnum          (# errors encountered)
##                   map_srcname_md5 (map original file name -> md5)
##                   map_md5_size    (map md5 -> original size)
##                   map_md5_crc     (map md5 -> crc)
##                   map_md5_srcname (map md5 -> original file name)
##
function readnamelist( filename, l_eof, l_line, l_list, l_num, l_diffnum, l_listcount, l_msg, l_tnull, l_teins  ){
    l_tnull = systime();
    l_num = 0;
    l_diffnum = 0;
    errnum = 0;
    l_eof = getline l_line  < filename;
    while( l_eof == 1 ){
        l_listcount = split( l_line, l_list, ";" );
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
        else if( length(l_list[3]) < 1       ) readerr("crc.empty",l_line)
        else if( l_list[3] !~ "^[0-9]*\$"    ) readerr("crc.empty",l_line)
        else if( length(l_list[4]) < 1       ) readerr("file.name.empty",l_line)
        else {
            # all is well
            map_srcname_md5[l_list[4]";"l_list[1]] = 1;
            if( length( map_md5_size[l_list[1]] ) == 0 ){
                l_diffnum++;
                map_md5_size[l_list[1]]       = l_list[2];
                map_md5_crc[l_list[1]]        = l_list[3];
            } else {
                if( map_md5_size[l_list[1]] != l_list[2] ) readerr("size.collision",l_line);
                if( map_md5_crc[l_list[1]] != l_list[3]  ) readerr("crc.collision", l_line);
            }
            map_md5_srcname[l_list[1]]=l_list[4];
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
## <md5>;<size>;<crc>;<source path>
function writenamelist( l_key, l_list, l_md5, l_srcname, l_num, l_tnull, l_teins, l_tzwei, l_tdrei ){
    l_num  = 0;
    l_diff = 0;
    l_tnull = systime();
    system("cat /dev/null > $NAMELIST.$$");
    l_teins = systime();
    for( l_key in map_srcname_md5) {
         split( l_key, l_list, ";" );
         l_srcname = l_list[1];
         l_md5     = l_list[2];
         if( length( map_md5_size[l_md5] ) > 0 ){
             printf("%s;%s;%s;%s\n",l_md5,map_md5_size[l_md5],map_md5_crc[l_md5],l_srcname) >> "$NAMELIST.$$";
             l_num++;
         }
    }
    close("$NAMELIST");   
    l_tzwei = systime();
    system("mv $NAMELIST.$$ $NAMELIST");
    l_tdrei = systime();
    printf("Wrote %7d lines to $NAMELIST.\n",l_num);
    if( debug ) {
        printf("   time to clean temporary file: %d sec.\n", l_teins - l_tnull );
        printf("   time to write temporary file: %d sec.\n", l_tzwei - l_teins );
        printf("   time to move to final file:   %d sec.\n", l_tdrei - l_tzwei );
        printf("   total time:                   %d sec.\n", l_tdrei - l_tnull );
    }    
}
function filesize( name, l_cmd, l_line, l_word ){
    l_cmd = "ls -l \\"" name "\\" 2>/dev/null";
    l_cmd | getline l_line;
    close(l_cmd);
    split( l_line, l_word );
    if( length( l_word[5] > 0 )) {
        l_res = l_word[5];
    } else {
        l_res = 0;
    }
    return l_res;
}
function filecrc( name, l_cmd, l_line, l_word ){
    l_cmd = "cksum \\"" name "\\"";
    l_cmd | getline l_line;
    close(l_cmd);
    split( l_line, l_word );
    return l_word[1];
}
function filemd5( name, l_cmd, l_line, l_word ){
    l_cmd = "md5sum \\"" name "\\"";
    l_cmd | getline l_line;
    close(l_cmd);
    split( l_line, l_word );
    return l_word[1];
}
function filetype( name, l_cmd, l_line, l_word ){
    l_cmd = "file \\"" name "\\"";
    l_cmd | getline l_line;
    close(l_cmd);
    split( l_line, l_word );
    if( l_word[2] == "TIFF" && name ~ "[.]nef\$" ) {
        return "nef";
    }else{
        return l_word[2];
    }
}
EOF
cat $TMP.lib.awk >> $TMP.backup.awk
cat $TMP.lib.awk >> $TMP.check.awk
cat $TMP.lib.awk >> $TMP.combine.awk
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
abspath () { case "$1" in /*)printf "%s\n" "$1";; *)printf "%s\n" "$PWD/$1";; esac; }
############################################################
# do the backup
############################################################
af6_checkBackup () {

    # todo check params    
    MD5=$1
    echo "MD5=$MD5"|logger -s -puser.info -t$BASE.$$
    SIZE=$2
    echo "SIZE=$SIZE"|logger -s -puser.info -t$BASE.$$
    MDATE=$3
    echo "MDATE=$MDATE"|logger -s -puser.info -t$BASE.$$
    HOST=$4
    echo "HOST=$HOST"|logger -s -puser.info -t$BASE.$$
    ABS=$5
    echo "ABS=$ABS"|logger -s -puser.info -t$BASE.$$

    SUBMD5=`echo $MD5|cut -c1-3`
    echo $SUBMD5

    #echo 'DOBACKUP'
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
        rm $TMP.* 
        af6_mutex_out 
        exit $1
    fi
}
############################################################
af6_combine () {

    mkdir -p $NAMESDIR  2>/dev/null
    if [ -z "$1" ] ; then 
        for I in 0 1 2 3 4 5 6 7 8 9 a b c d e f
          do
            for J in 0 1 2 3 4 5 6 7 8 9 a b c d e f
              do
                for K in 0 1 2 3 4 5 6 7 8 9 a b c d e f
                  do
                    $MYSELF $I$J$K
                  done
              done
          done
    else 
        PATTERN=`echo $1|cut -c1-3|grep '^[0-9a-f][0-9a-f][0-9a-f]$'`
        if [ -n "$PATTERN" ] ; then 
            if [ -s $LEGACYLIST ] ; then
                if [ -s $NAMESDIR/$PATTERN ] ; then
                    echo '123'
                else
                    echo '456'
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

if [ "$1" = "checkBackup" ] ; then
    af6_mutex_in
    shift
    af6_checkBackup $*
elif [ "$1" = "combine" ] ; then
    af6_mutex_in
    af6_combine $2
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
EOF