#!/bin/bash

# STUB -  will start working on a sensible update system!!!
# This file is for updating smartcoin.
# It will let me change yoyur database schema, and other things on the fly, instead of needing a
# full reinstall!
# TODO:
# make a safe option, which will look at a file 'smartcoin_safeupdate.txt' or similar.
# When it increments, you are safe to do the update!


Log "Preparing to do an Update..." 1
svn_rev_start=`svn info | grep "^Revision" | awk '{print $2}'`
svn_current_repo=`svn info | grep "^URL" | awk '{print $2}'`
svn_rev_end=`svn info $svn_current_repo | grep "^Revision" | awk '{print $2}'`

if [[ "$svn_rev_start" == "$svn_rev_end" ]]; then
  Log "You are already at the current revision r$svn_rev_start!" 1
else

  Log "Preparing to update from r$svn_revision_start to r$svn_revision_end" 1
  #svn -r $svn_rev_end update

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
fi
