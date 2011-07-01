#!/bin/bash

# STUB -  will start working on a sensible update system!!!
# This file is for updating smartcoin.
# It will let me change yoyur database schema, and other things on the fly, instead of needing a
# full reinstall!
# TODO:
# make a safe option, which will look at a file 'smartcoin_safeupdate.txt' or similar.
# When it increments, you are safe to do the update!
. $HOME/smartcoin/smartcoin_ops.sh
experimental_update=$1

Log "Preparing to do an Update..." 1
svn_rev_start=`svn info | grep "^Revision" | awk '{print $2}'`
svn_current_repo=`svn info | grep "^URL" | awk '{print $2}'`
svn_rev_end=`svn info $svn_current_repo | grep "^Revision" | awk '{print $2}'`
safe_update=1 #TODO: UNCOMMENT THIS WHEN READY FOR STABLE UPDATES!`svn diff -r $svn_rev_start:$svn_rev_end update.ver`



if [[ "$svn_rev_start" == "$svn_rev_end" ]]; then
  Log "You are already at the current revision r$svn_rev_start!" 1
else
  if [[ "$experimental_update" ]]; then
    #Do an experimental update!
    Log "Preparing experimental update from r$svn_rev_start to r$svn_rev_end" 1
    svn update
  else
    if [[ "$safe_update" ]]; then
     Log "Preparing safe update from r$svn_rev_start to r$svn_rev_end" 1
     svn update
    else
      Log "There are new experimental updates, but they aren't proven safe yet. Not updating." 1
    fi
  fi




 
  #svn -r $svn_rev_end update

  for i in {"$svn_rev_start".."$svn_rev_end"}; do
	
     case $i in
	

     257)
        # Update schema going into r255
         echo "Applying r255 patch..."
        # Set up by default for stable updates!
        Q="DELETE FROM settings WHERE data='dev_branch';"
        RunSQL "$Q"
        Q="INSERT INTO settings (data,value,description) VALUES ('dev_branch','stable','Development branch to follow (stable/experimental)');"
        RunSQL "$Q"
        ;;
    *)
        echo "No post install updates to apply to r$i"
        ;;
     esac
	
  done
fi

Log "Update task complete." 1
