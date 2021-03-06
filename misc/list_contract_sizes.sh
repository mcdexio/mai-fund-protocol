#!/bin/bash

BUILD_DIR=build/contracts

for fn in $(ls $BUILD_DIR) 
do 
	[[ $fn = Test* ]] && continue
	[[ $fn = I* ]] && continue
	[[ $fn = Lib* ]] && continue
	bytecode=$(cat ${BUILD_DIR}/${fn} | jq .deployedBytecode | awk -F "\"" '{print $2}') 
	[[ $bytecode = 0x ]] && continue
	let size=${#bytecode}/2
	printf "%-40s%s\n" "${fn}~" "~${size}" | tr ' ~' '- '
done
