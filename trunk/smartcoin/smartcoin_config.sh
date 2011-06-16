#!/bin/bash

if [[ -n "$HEADER_smartcoin_config" ]]; then
        return 0
fi
HEADER_smartcoin_config="included"


# BEGIN USER CONFIGURABLE OPTIONS
sessionName="smartcoin"
export sessionName

statusRefresh="2"

MySqlHost="127.0.0.1"
MySqlPort=""
MySqlUser="jondecker76"
MySqlPassword="ohio98yo"

# END USER CONFIGURABLE OPTIONS






