#!/bin/ksh

#-- gitk
eval "`ssmuse sh -d /home/ordenv/ssm-domains/ssm-development -p git_1.7.1.1_linux24-i386`"

export GIT_DIR=$1
gitk
