#!/bin/bash

if [[ $( dirname "$0" ) == "/usr/bin" ]]; then
	CUR_LOCATION=$(dirname $(readlink -f $( dirname "$0" )/smartcoin))
else
	CUR_LOCATION="$( cd "$( dirname "$0" )" && pwd )"
fi
. $CUR_LOCATION/smartcoin_ops.sh
experimental_update=$1

Log "Preparing to do an Update..." 1
echo "Getting current revision..."
svn_rev_start=`svn info $CUR_LOCATION/ | grep "^Revision" | awk '{print $2}'`
echo "Getting the current repo..."
svn_current_repo=`svn info $CUR_LOCATION/ | grep "^URL" | awk '{print $2}'`
echo "Getting the repo current revision number..."
svn_rev_end=`svn info $svn_current_repo | grep "^Revision" | awk '{print $2}'`
echo "Checking stable update flag..."
safe_update=`svn diff -r $svn_rev_start:$svn_rev_end $CUR_LOCATION/update.ver`

# Make a list of "breakpoints"
# Breakpoints are revision numbers where the smartcoin software must be restarted before applying any more updates or patches.
# This way, users that are badly out of date will have to update several times to get to current, and the smartcoin software
# will be sure to be in the correct state to accept further updates and patches.
BP="300 "	# The database moves in this update
BP=$BP"360 "	# The database gets locking in r358 and procmail dependency gets satisfied in this update, so a restart is important!
BP=$BP"365 "	# Stable/experimental branch stuff goes live


bp_message=""
# Determine where the new svn_rev_end should be
for thisBP in $BP; do
	if [[ "$thisBP" -gt "$svn_rev_start" ]]; then
		if [[ "$thisBP" -lt "$svn_rev_end" ]]; then
			svn_rev_end="$thisBP"
			bp_message="Update breakpoints have been detected! "
			bp_message=$bp_message"This means that you will have to run a partial update, restart smartcoin, then run an update again. "
			bp_message=$bp_message"You may have to repeat this several time to get fully up to date!"
			break		
		fi	
	fi
done


if [[ "$svn_rev_start" == "$svn_rev_end" ]]; then
	Log "You are already at the current revision r$svn_rev_start!" 1
else
	echo "$bp_message"
	if [[ "$experimental_update" ]]; then
		#Do an experimental update!
		Log "Preparing experimental update from r$svn_rev_start to r$svn_rev_end" 1
		svn update -r $svn_rev_end $CUR_LOCATION/
	else
    		if [[ "$safe_update" ]]; then
     			Log "Preparing safe update from r$svn_rev_start to r$svn_rev_end" 1
     			svn update -r $svn_rev_end $CUR_LOCATION/
   		 else
      			Log "There are new experimental updates, but they aren't proven safe yet. Not updating." 1
    		fi
	fi 




 
	#make sure that we backup the database before playing around with it!
	cp $HOME/.smartcoin/smartcoin.db $HOME/.smartcoin/smarcoin.db.backup

	echo ""
	Log "Applying post update patches..." 1
	# We don't want to apply patches against the start revision, as it would have already been done the previous time... So make sure we increment it!
	patchStart=$svn_rev_start
	let patchStart++
	patchEnd=$svn_rev_end
  
	for ((i=$patchStart; i<=$patchEnd; i++)); do
		case $i in
		300)
			# Update schema going into r300
			Log "Applying r$i patch..." 1
			Log "Setting up ~/.smartcoin and copying over database"
			mkdir -p $HOME/.smartcoin && cp $CUR_LOCATION/smartcoin.db $HOME/.smartcoin/smartcoin.db
			rm $CUR_LOCATION/smartcoin.db	#No reason to have it here. It will be updated to current on the next update.
       
			Log "Setting the dev_branch setting variable"
		        # Set up by default for stable updates!
		        Q="DELETE FROM settings WHERE data='dev_branch';"
		        RunSQL "$Q"
		        Q="INSERT INTO settings (data,value,description) VALUES ('dev_branch','stable','Development branch to follow (stable/experimental)');"
		        RunSQL "$Q"
             		;;
           
		351)            
                	Log "Applying r$i patch..." 1
			Log "Altering the profile table for the new Failover system"
			Q="ALTER TABLE profile ADD down bool NOT NULL DEFAULT(0);"
			RunSQL "$Q"
			Q="ALTER TABLE profile ADD failover_order int NOT NULL DEFAULT(0);"
			RunSQL "$Q"
			Q="ALTER TABLE profile ADD failover_count int NOT NULL DFAULT(0);"
			RunSQL "$Q"
			;;
		360)
			Log "Applying r$i patch..." 1
			echo "The procmail package needs installed for the new database lock system"
			echo "Please enter your root passsword when prompted"

			sudo apt-get install -f -y procmail
			;;
		365)
			Log "Applying r$i patch..." 1
			Q="DELETE FROM settings WHERE data='dev_branch';"
			RunSQL "$Q"
			Q="INSERT INTO settings (data,value,description) VALUES ('dev_branch','stable','Development branch to follow (stable/experimental)');"
			RunSQL "$Q"

			;;
    		*)
        		Log "No patches to apply to r$i"

        		;;
     		esac
	done
fi

Log "Update task complete." 1

echo ""
echo "Update is now complete!  You should now restart smartcoin. Please hit any key to continue."
read blah

