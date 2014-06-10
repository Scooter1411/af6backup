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
HOST=`hostname`
#############################################################
# main configuration
#############################################################
TARGET=admin@quokka
MOUNTDIR=/share/HDA_DATA/Public
TODIR=$MOUNTDIR/af5backup.dir
#############################################################
if [ -n "$1" ] ; then
    MD5=$1
    
    MD51=`echo $MD5|cut -c1,1`
    MD52=`echo $MD5|cut -c2,2`
    MD53=`echo $MD5|cut -c3,3`
    df $TODIR/$MD51/$MD52/$MD53
    rm $TODIR/$MD51/$MD52/$MD53/$MD5*
    df $TODIR/$MD51/$MD52/$MD53 |tail -1
fi
