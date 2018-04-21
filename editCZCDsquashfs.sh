#!/bin/sh
# editCZCD version 12. May 26th, 2015. Updated by Michael Munger <michael@highpoweredhelp.com>
# Updates:
# 1. Support for Clonezilla v2.x+
# 2. No longer attempts to download the iso. This breaks too easily.
# 3. BASEDIR now defaults to /tmp/
# 4. OUTPUTDEV deprecated. Restircted to ISO output, since we usually use UBS sticks now-a-days.
# 
# Original script information and credits retained below:
#
# editCZCD version Fr 11. Jan 18:02:48 CET 2008
# Use the editCzCD script to modify clonezilla live cd content and burn a CD from it.
# Copyright (c) Casual J. Programmer <cprogrammer@users.sourceforge.net> partially
# based on script ocs-iso by Steven Shiau <steven _at_ nchc org tw>
# The script is provided as is under GPL, no responsibilty taken for any damage caused using it.
# Suggestions and Feedback welcome, have a lot of fun ...
# Maybe freely used and copied provided this header remains intact.

# TecnologÃ­a de la InformaciÃ³n <ti@imm.gub.uy>
# Modified to handle new versions of Clonezilla (since 1.2.0-1) which use squashfs

# Use genisoimage instead of mkisofs. genisoimage is a fork of mkisofs
# Details on mkisofs with man mkisofs. Parameters used here:
#
# -A Application ID written to Volume Header
# -b Eltorito boot image
# -boot-load-size Load # sectors on boot
# -c Boot catalog, required for eltorito CD
# -J Generate Joliet directory records
# -r Files and directories are globally readable on the client.
# -l Allow full 31-character filenames
# -no-emul-boot No disk emulation for boot
# -o Filename of the iso image to generate
# -p Preparer
# -publisher
# -V Volume label-V $VOLUME 

usage() {
  echo ""
  echo "This program MUST be run as root"
  echo ""
  echo "Usage: editCZCDsquashfs.sh [/path/to/downloaded/iso/file]"
  echo ""
  exit 1
}

if [ $(whoami) != "root" ]; then
  echo "$0 should be run as root! You're not root. Magic 8 ball says: RTFM."
  usage
fi

if [ $# -eq 0 ]; then
  echo "Oops. Perhaps you didn't RTFM?"
  usage
fi

#Changed, 5/25/2015 - Michael Munger - Updated for current version of CZ
CZVERSION=$1


echo -n "Verifying presence of the Clonazilla ISO file..."
if [ ! -f ${CZVERSION} ]; then
  echo "Cannot find the ISO file for Clonezilla. Perhaps you didn't pass it correctly as the first parameter to this script?"
  usage()
  exit 1
else
  echo "[OK]"
fi

#Set to the version you want to use, for details see http://clonezilla.sourceforge.net/

#Set to czrr, (Clonezilla remote restore)
PREFIX="czrr-"
ISO_FILE="${PREFIX}${CZVERSION}"

APPLICATION="Clonezilla Live Remote Restore CD"
PUBLISHER="DRBL/Clonezilla http://drbl.name http://clonezilla.org"
#Leave application and publisher alone

VOLUME="RRCZ"
PREPARER="Michael Munger <michael@highpoweredhelp.com>"

#Set volume to your liking, preparer to your name and email or leave blank

#
BASEDIR=/tmp
TMPDIRO=$BASEDIR/clonezilla
TMPDIRN=$BASEDIR/clonezillan
MAKE="-makeiso"
## <deprecated>

##OUTPUTDEV=$(cdrecord --devices | grep 0 | cut --characters=10-18)
#may be /dev/scd0 or other on your system, use cdrecord --devices to identify

# use wodim instead of cdrecord. wodim is a fork of cdrecord
# identify devices only when -b is specified
#OUTPUTDEV=$(wodim --devices | grep 0 | cut --delimiter=\' --fields=2)

## </deprecated>

# Checks to see if a dependency is installed by using the whcih command. If
# the return value from the which command is 0 (zero), then we assume that the
# item is not installed because the string length of the path to an item can
# never be zero.
#
# Usage: check_dependency someprogram

check_dependency() {
  echo -n "Checking for $1..."

  TEST=`which $1`
  EXISTS=${#TEST}

  if [ ${EXISTS} -gt 0 ]; then
    echo "[OK]"
  else
    echo "[FAILED]"
    echo "You need to install $1 before proceeding."
    exit 1
  fi
}

#Check to see if genisoimage is installed.
check_dependency genisoimage
check_dependency unsquashfs
check_dependency mksquashfs

#This should probably be deprecated as well since we no longer support
#OUTPUTDEV. Leving it here in case someone really needs it.
#if [ "$1" = "-b" ]; then
#  # Check to see if wodim is installed
#  check_dependency wodim
#
#  OUTPUTDEV=$(wodim --devices | grep 0 | cut --delimiter=\' --fields=2)
#  [ -z "$OUTPUTDEV" ] && echo "-b option specified but no drive found!" && exit 1
#fi

#Remove the directories to start clean.
rm -rf $TMPDIRO
rm -rf $TMPDIRN

#Copy a fresh version of the iso to the BASEDIR to get started.
cp $CZVERSION $BASEDIR

mkdir $TMPDIRO
mkdir $TMPDIRN

echo "Preparing to decompress filesystem.squashfs..."
mount -o loop $BASEDIR/$CZVERSION $TMPDIRO

cp -a $TMPDIRO/* $TMPDIRN

umount $TMPDIRO

##cd $TMPDIRN/pkg
##tar xzf opt_drbl.tgz

cd $TMPDIRN/live
unsquashfs filesystem.squashfs

echo ""
echo "Now edit any part of clonezilla live-cd in ${TMPDIRN}/live/squashfs-root/"
echo ""
echo "This would be the proper time to chroot to ${TMPDIRN}/live/squashfs-root/ in a separate terminal."
echo ""
echo "If you have previously created a remastered disc, and would like to restore"
echo "a tar ball, now would be the time to do it!"
echo ""
echo "If you used the (deprecated) -b option, place an empty CD or CD/RW in the drive."
echo ""
echo "When you're done, type 'exit', and this will create your ISO."
echo ""

#Take you to the root!
cd $TMPDIRN/live/squashfs-root/

sh

echo "modified on $(date) by $PREPARER" >> $TMPDIRN/"Clonezilla-Live-Version"
##cd $TMPDIRN/pkg
##tar czf opt_drbl.tgz opt
##rm -rf opt

echo "Creating new filesystem.squashfs..."
cd $TMPDIRN/live/
#
blocksize=$(unsquashfs -s filesystem.squashfs | grep "Block size" | awk '{print $3}')
b=""
if [ -n "$blocksize" ]
then
  b="-b $blocksize"
fi
rm -f filesystem.squashfs
mksquashfs squashfs-root filesystem.squashfs $b
rm -rf squashfs-root
cd $BASEDIR

echo "Creating $BASEDIR/$ISO_FILE..."
# use genisoimage instead of mkisofs. genisoimage is a fork of mkisofs
genisoimage \
 -A "$APPLICATION" \
 -V "$VOLUME" \
 -p "$PREPARER" -publisher "$PUBLISHER" \
 -b syslinux/isolinux.bin -c syslinux/boot.cat \
 -no-emul-boot -boot-load-size 4 -boot-info-table \
  -r -J -l -input-charset iso8859-1 $TMPDIRN | \
  (
   case "$1" in
    "-b")
       umount $OUTPUTDEV 2>/dev/null
       ##cdrecord -dev=$OUTPUTDEV blank=fast
       ##cdrecord dev=$OUTPUTDEV -data -eject -v -
       wodim dev=$OUTPUTDEV blank=fast
       wodim dev=$OUTPUTDEV -data -eject -v -
       echo "Created $VOLUME"
       ;;
    *)
       # use /dev/stdout as the bridge
       cat - > $BASEDIR/$ISO_FILE
       echo "Created $BASEDIR/$ISO_FILE"
       ;;
   esac
  )

if type isohybrid &>/dev/null; then
  if [ -e $BASEDIR/$ISO_FILE ]; then
    echo -n "Isohybriding $BASEDIR/$ISO_FILE... "
    isohybrid $BASEDIR/$ISO_FILE
    echo "done!"
  fi
fi

# end editCZCD