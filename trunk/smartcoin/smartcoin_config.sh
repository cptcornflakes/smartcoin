#!/bin/bash

if [[ -n "$HEADER_smartcoin_config" ]]; then
        return 0
fi
HEADER_smartcoin_config="included"


# BEGIN USER CONFIGURABLE OPTIONS
sessionName="smartcoin"
export sessionName
minerSession="miner"
export minerSession

statusRefresh="5"

MySqlHost="127.0.0.1"
MySqlPort=""
MySqlUser="smartcoin"
MySqlPassword="smartcoin"
# END USER CONFIGURABLE OPTIONS






