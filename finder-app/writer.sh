#!/bin/bash

writefile=$1
writestr=$2

if [ -z $writefile ] || [ -z $writestr ]
then
	echo "Not enough args"
	exit 1
fi

mkdir -p $(dirname $writefile)

echo $writestr > $writefile

