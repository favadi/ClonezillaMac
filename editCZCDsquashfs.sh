#!/bin/sh
# editCZCD version Fr 11. Jan 18:02:48 CET 2008
# Use the editCzCD script to modify clonezilla live cd content and burn a CD from it.
# Copyright (c) Casual J. Programmer <cprogrammer@users.sourceforge.net> partially
# based on script ocs-iso by Steven Shiau <steven _at_ nchc org tw>
# The script is provided as is under GPL, no responsibilty taken for any damage caused using it.
# Suggestions and Feedback welcome, have a lot of fun ...
# Maybe freely used and copied provided this header remains intact.

# Tecnología de la Información <ti@imm.gub.uy>
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

#CZVERSION="clonezilla-live-1.0.9-1.iso"
CZVERSION="clonezilla-live-1.2.2-31.iso"
#clonezilla-live-1.0.7-18.iso
#Set to the version you want to use, for details see http://clonezilla.sourceforge.net/

PREFIX="cjp-"
ISO_FILE="${PREFIX}${CZVERSION}"

APPLICATION="Clonezilla Live CD"
PUBLISHER="DRBL/Clonezilla http://drbl.name http://clonezilla.org"
#Leave application and publisher alone

VOLUME="CJP's special CZCD"
PREPARER="Casual J. Programmer <cprogrammer@users.sourceforge.net>"
#Set volume to your liking, preparer to your name and email or leave blank

DLFROM="http://mesh.dl.sourceforge.net/sourceforge/clonezilla"
# http://puzzle.dl.sourceforge.net/sourceforge/clonezilla
# The download host that suits you best

BASEDIR=/tmp
TMPDIRO=$BASEDIR/clonezilla
TMPDIRN=$BASEDIR/clonezillan
MAKE="-makeiso"
##OUTPUTDEV=$(cdrecord --devices | grep 0 | cut --characters=10-18)
#may be /dev/scd0 or other on your system, use cdrecord --devices to identify

# use wodim instead of cdrecord. wodim is a fork of cdrecord
# identify devices only when -b is specified
#OUTPUTDEV=$(wodim --devices | grep 0 | cut --delimiter=\' --fields=2)

if [ $(whoami) != "root" ]; then
  echo "$0 should be run as root!"
  exit 1
fi

if ! type genisoimage &>/dev/null; then
  echo "Program genisoimage is not available! You have to install it."
  exit 1
fi

if [ "$1" = "-b" ]; then
  if ! type wodim &>/dev/null; then
    echo "Program wodim is not available! You have to install it."
    exit 1
  fi
  OUTPUTDEV=$(wodim --devices | grep 0 | cut --delimiter=\' --fields=2)
  [ -z "$OUTPUTDEV" ] && echo "-b option specified but no drive found!" && exit 1
fi

if ! type unsquashfs &>/dev/null; then
  echo "Program unsquashfs is not available! You have to install it."
  exit 1
fi

if ! type mksquashfs &>/dev/null; then
  echo "Program mksquashfs is not available! You have to install it."
  exit 1
fi

rm -rf $TMPDIRO
rm -rf $TMPDIRN

if [ "$( ls $BASEDIR/$CZVERSION 2>/dev/null)" != "$BASEDIR/$CZVERSION" ]; then 
        wget -P $BASEDIR $DLFROM/$CZVERSION
fi

mkdir $TMPDIRO
mkdir $TMPDIRN

echo "Preparing to decompress filesystem.squashfs..."
mount -o loop $BASEDIR/$CZVERSION $TMPDIRO

cp -a $TMPDIRO/* $TMPDIRN
##chmod -R 755 $TMPDIRN

umount $TMPDIRO

##cd $TMPDIRN/pkg
##tar xzf opt_drbl.tgz

cd $TMPDIRN/live
unsquashfs filesystem.squashfs

echo "Now edit any part of clonezilla live-cd in ${TMPDIRN}/live/squashfs-root/opt/drbl/"
echo "when finished leave this shell by typing exit, if called with -b option"
echo "place an empty CD or CD/RW in the drive."

##cd $TMPDIRN/pkg/opt/drbl
cd $TMPDIRN/live/squashfs-root/opt/drbl

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
 -b isolinux/isolinux.bin -c isolinux/boot.cat \
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
