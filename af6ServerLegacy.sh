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
    print l_cmd
    system(l_cmd);
    print "bbb"
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

                touch $NAMESDIR/$PATTERN

                awk -f $TMP.legacy.awk -F';' \
                    -v pattern=$PATTERN -v inlist=$NAMESDIR/$PATTERN \
                    -v outlist=$NAMESDIR/$PATTERN.$$ < $LEGACYLIST
                diff $NAMESDIR/$PATTERN $NAMESDIR/$PATTERN.$$ | grep '^< ' | cut -c3- > $OLDDIR/$PATTERN.$DATE

                bzip2 --best --force $NAMESDIR/$PATTERN
                mv $NAMESDIR/$PATTERN.$$ $NAMESDIR/$PATTERN 
            fi
        fi
    fi
}
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
# cleanup & stats
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