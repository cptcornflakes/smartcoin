#!/bin/bash

if [[ $( dirname "$0" ) == "/usr/bin" ]]; then
	CUR_LOCATION=$(dirname $(readlink -f $( dirname "$0" )/smartcoin))
else
	CUR_LOCATION="$( cd "$( dirname "$0" )" && pwd )"
fi
. $CUR_LOCATION/smartcoin_ops.sh
experimental_update=$1

Log "Preparing to do an Update..." 1
svn_rev_start=`svn info $CUR_LOCATION/ | grep "^Revision" | awk '{print $2}'`
svn_current_repo=`svn info $CUR_LOCATION/ | grep "^URL" | awk '{print $2}'`
svn_rev_end=`svn info $svn_current_repo | grep "^Revision" | awk '{print $2}'`
safe_update=1 #TODO: UNCOMMENT THIS WHEN READY FOR STABLE UPDATES!`svn diff $CUR_LOCATION/ -r $svn_rev_start:$svn_rev_end update.ver`



if [[ "$svn_rev_start" == "$svn_rev_end" ]]; then
	Log "You are already at the current revision r$svn_rev_start!" 1
else
	if [[ "$experimental_update" ]]; then
		#Do an experimental update!
		Log "Preparing experimental update from r$svn_rev_start to r$svn_rev_end" 1
		svn update $CUR_LOCATION/
	else
    		if [[ "$safe_update" ]]; then
     			Log "Preparing safe update from r$svn_rev_start to r$svn_rev_end" 1
     			svn update $CUR_LOCATION/
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
       
			Log "Setting the dev_branch setting variable"
		        # Set up by default for stable updates!
		        Q="DELETE FROM settings WHERE data='dev_branch';"
		        RunSQL "$Q"
		        Q="INSERT INTO settings (data,value,description) VALUES ('dev_branch','stable','Development branch to follow (stable/experimental)');"
		        RunSQL "$Q"
             		;;
           
		346)            
                	Log "Applying r$i patch..." 1
			Log "Altering the profile table for the new Failover system"
			Q="ALTER TABLE profile ADD down bool NOT NULL DEFAULT(0);"
			RunSQL "Q"
			Q="ALTER TABLE profile ADD failover_order int NOT NULL DEFAULT(0);"
			RunSQL "Q"
			Q="ALTER TABLE profile ADD failover_count int NOT NULL DFAULT(0);"
			RunSQL "Q"
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

