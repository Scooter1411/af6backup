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
MOUNTDIR=/share/HDA_DATA/Public
TODIR=$MOUNTDIR/af5backup.dir
OLDDIR=$TODIR/old
LEGACYLIST=$TODIR/af5backup.names
MASTERLIST=$TODIR/af6backup.master
#############################################################
# serverBackup, awk-Teil
#############################################################
cat <<EOF > $TMP.retention.awk
BEGIN{
}
{
    key=\$5;
    #printf("a %5d;%s <<<\n",countMap[key],key) 

    if( length(countMap[key]) == 0 ){
        countMap[key] = 1
    }else{
        countMap[key] += 1
    }
    #printf("b %5d;%s <<<\n",countMap[key],key) 
}
END{
    for( key in countMap ) {
         if( countMap[key] > 1 ){
             printf("%d;%s\n",countMap[key],key) 
         }
    }
}
EOF
#############################################################
bzip2 --stdout $MASTERLIST > $OLDDIR/af6backup.$DATE.master.bz2

find $TODIR -type f -name '*.af6' > $TMP.filelist

cat $TMP.filelist| while read FILE
  do
    cat $FILE >> $MASTERLIST
  done
sort < $MASTERLIST > $TMP.master
uniq < $TMP.master > $MASTERLIST

sort -t';' -k3 < $MASTERLIST > $TODIR/af6backup.byTime
sort -t';' -k5 < $MASTERLIST > $TODIR/af6backup.byName

cut -d';' -f4 < $MASTERLIST|sort|uniq > $TMP.hostlist
cat $TMP.hostlist|while read THISHOST
  do
    grep ";$THISHOST;" < $MASTERLIST | sort -t';' -k5 > $TODIR/af6backup.byName.$THISHOST
  done

cat $TMP.retention.awk
awk -F';' -f $TMP.retention.awk < $MASTERLIST

wc -l $TODIR/af6backup.*
exit 0
