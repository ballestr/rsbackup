#!/bin/bash
## test out correct shell expansion
## for different cases
## Correct run:
#deimos-3:tests$ ./teststatus.sh 
#logs1 NOSTATUS ''
#logs2 OK 'logs2/t1.status'
#logs3 FAIL 'logs3/t1.status logs3/t2.status'

rm -rf logs1 logs2 logs3
mkdir -p logs1 logs2 logs3
# empty logs1
echo "OK"  >logs2/t1.status
echo "OK"  >logs3/t1.status
echo "FAIL">logs3/t2.status

function st() {
	local status="OK"
    shopt -s nullglob
    local F="$(find $LOGDIR -name '*.status')"
    if [ "$F" ] ; then
        if grep -q FAIL $F ; then
            status="FAIL"
        fi
    else
        status="NOSTATUS"
    fi
    echo "$LOGDIR $status '"$F"'"
}

echo "" | {
#set -x
LOGDIR=logs1 ; st
LOGDIR=logs2 ; st
LOGDIR=logs3 ; st
}
rm -rf logs1 logs2 logs3

