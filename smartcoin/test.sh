#!/bin/bash
#clear
#echo "Starting..."
. $HOME/smartcoin/smartcoin_ops.sh




M=$(AddMenuItem "15	1	First Item")
M=$M$(AddMenuItem "27	2	Second Item")
M=$M$(AddMenuItem "88	3	Third Item")



for item in $M; do
	num=$(Field 2 "$item")
	listing=$(Field 3 "$item")
	echo -e  "$num) $listing"
done
echo ""
echo "Choose choice:"
read choose

for item in $M; do
	chosen=$(Field 2 "$item")
	if [[ "$chosen" == "$choose" ]]; then
		echo $(Field 1 "$item")
	fi
done
