#!/bin/bash

BUILD_DIR=build/contracts

echo "123456789" | 
for fn in $(ls $BUILD_DIR) 
do 
	[[ $fn = Test* ]] && continue
	[[ $fn = I* ]] && continue
	[[ $fn = Lib* ]] && continue
	bytecode=$(cat ${BUILD_DIR}/${fn} | jq .deployedBytecode | awk -F "\"" '{print $2}') 
	[[ $bytecode = 0x ]] && continue
	let size=${#bytecode}/2
	printf "%-30s%s\n" "${fn}~" "~${size}" | tr ' ~' '- '
done
