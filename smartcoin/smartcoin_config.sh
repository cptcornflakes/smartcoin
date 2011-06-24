#!/bin/bash

# TODO:
# These configuration variables ARE used currently.
# However, the long term plan is to migrate all of these
# to the database, and make them configurable at install-time.


if [[ -n "$HEADER_smartcoin_config" ]]; then
        return 0
fi
HEADER_smartcoin_config="included"


# BEGIN USER CONFIGURABLE OPTIONS
export sessionName="smartcoin"
export minerSession="miner"

statusRefresh="5"

MySqlHost="127.0.0.1"
MySqlPort=""
MySqlUser="smartcoin"
MySqlPassword="smartcoin"
# END USER CONFIGURABLE OPTIONS






