#!/bin/bash

# STUB -  will start working on a sensible update system!!!
# This file is for updating smartcoin.
# It will let me change yoyur database schema, and other things on the fly, instead of needing a
# full reinstall!
# TODO:
# make a safe option, which will look at a file 'smartcoin_safeupdate.txt' or similar.
# When it increments, you are safe to do the update!


# Either of these will work for getting Subversion working copy revision number
#svn_rev_start=`svn info | sed -ne 's/^Revision: //p'`
#svn_rev_start=`svn info | grep "^Revision" | awk '{print $2}'`

#then...
#svn update
#TODO: Copy files to other host machines!


#then...
#svn_rev_end=`svn info | grep "^Revision" | awk '{print $2}'`



for i in {"$svn_rev_start".."$svn_rev_end"}; do
	
	case $i in;
	
	190)
		# Update schema going into r190
		;;
	201)
		# Update schema going into r200
		;;

	esac
	
done
