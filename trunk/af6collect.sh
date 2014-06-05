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
#logger -s -puser.info -t$BASE.$$ started
HOST=`hostname`
#############################################################
# main configuration
#############################################################
MOUNTDIR=/share/HDA_DATA/Public
TODIR=$MOUNTDIR/af5backup.dir
OLDDIR=$TODIR/old
mkdir -p $OLDDIR 2>/dev/null
mkdir -p $TODIR/tmp 2>/dev/null
TMP=$TODIR/tmp/$BASE.$$
LEGACYLIST=$TODIR/af5backup.names
MASTERLIST=$TODIR/af6backup.master
MAILTO="alexander.franz.1411@gmail.com"
MAX=4
#############################################################
# retention, awk-Teil
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
         if( countMap[key] > $MAX ){
             printf("%d;%s\n",countMap[key],key) 
         }
    }
}
EOF
#############################################################
# main script
#############################################################
bzip2 --stdout $MASTERLIST > $OLDDIR/af6backup.$DATE.master.bz2

find $TODIR -type f -name '*.af6' > $TMP.filelist
wc -l  $TMP.filelist

cat /dev/null > $MASTERLIST
cat $TMP.filelist| while read FILE
  do
    cat $FILE >> $MASTERLIST
  done
sort < $MASTERLIST > $TMP.master
uniq < $TMP.master > $MASTERLIST
wc -l $TMP.master $MASTERLIST

#sort -t';' -k2 < $MASTERLIST > $TODIR/af6backup.bySize
awk -F';' '{printf("%s;%s;%s;%s;%s\n",$2,$1,$3,$4,$5)}' <$MASTERLIST |sort -n > $TODIR/af6backup.bySize
#sort -t';' -k3 < $MASTERLIST |head > $TODIR/af6backup.byTime
awk -F';' '{printf("%s;%s;%s;%s;%s\n",$3,$1,$2,$4,$5)}' <$MASTERLIST |sort    > $TODIR/af6backup.byTime
#sort -t';' -k5 < $MASTERLIST > $TODIR/af6backup.byName
awk -F';' '{printf("%s;%s;%s;%s;%s\n",$5,$1,$2,$3,$4)}' <$MASTERLIST |sort    > $TODIR/af6backup.byName

cut -d';' -f4 < $MASTERLIST|sort|uniq > $TMP.hostlist
rm $TODIR/af6backup.byName.* 2>/dev/null
cat $TMP.hostlist|while read THISHOST
  do
    grep ";$THISHOST\$" < $TODIR/af6backup.byName > $TODIR/af6backup.byName.$THISHOST
  done

rm $TODIR/af6backup.retention.* 2>/dev/null
awk -F';' -f $TMP.retention.awk < $MASTERLIST | sort -n > $TODIR/af6backup.retention
cut -d';' -f1 < $TODIR/af6backup.retention|sort|uniq > $TMP.retentionCounts
cat $TMP.retentionCounts
cat $TMP.retentionCounts|while read THISCOUNT
  do
    grep "^$THISCOUNT;" < $TODIR/af6backup.retention > $TODIR/af6backup.retention.$THISCOUNT
    cut -d';' -f2 < $TODIR/af6backup.retention.$THISCOUNT|sort|uniq > $TMP.retentionNames
    cat $TMP.retentionNames
    echo '*****************************************' >> $TODIR/af6backup.retention.$THISCOUNT
    cat $TMP.retentionNames|while read THISNAME
      do
        grep ";$THISNAME" < $TODIR/af6backup.byTime >> $TODIR/af6backup.retention.$THISCOUNT
        echo '-----------------------------------------' >> $TODIR/af6backup.retention.$THISCOUNT
      done
  done
#############################################################
# stats & mail
#############################################################
wc -l $TODIR/af6backup.* |tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$


echo '-------------------------------------------------------------'|\
     tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$
STOP=`date +%s`
DIFF=`expr $STOP - $START`
DIFFH=`expr $DIFF / 3600`
DIFFM=`expr \( $DIFF - \( $DIFFH \* 3600 \) \) / 60`
DIFFS=`expr $DIFF % 60`
echo|awk "{printf(\"It took me %d:%02d:%02d to get here.\n\",$DIFFH,$DIFFM,$DIFFS)}"|\
     tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$
echo '-------------------------------------------------------------'|\
     tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$
df | grep _DATA |tee -a $TMP.mail|logger -s -puser.info -t$BASE.$$

echo "Subject: AF6Collect $HOST" >  $TMP.mail2
echo "From: $MAILTO"             >> $TMP.mail2
echo "To: $MAILTO"               >> $TMP.mail2
echo ""                          >> $TMP.mail2
cat $TMP.mail                    >> $TMP.mail2
sendmail -t                      <  $TMP.mail2

#rm -rf $TMP.* 
exit 0
