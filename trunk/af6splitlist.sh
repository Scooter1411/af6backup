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
LISTDIR=$TODIR/list
mkdir -p $LISTDIR
############################################################
# canonical path name
############################################################
cat <<EOF > $TMP.split.awk
BEGIN{
}
{
    key = substr(\$0,1,3)
    print key
    file = "$LISTDIR/" key
    print file
    print \$0 >> file
}
END{
}
EOF
############################################################
# canonical path name
############################################################
awk -F';' -f $TMP.split.awk < $LEGACYLIST

exit 0
