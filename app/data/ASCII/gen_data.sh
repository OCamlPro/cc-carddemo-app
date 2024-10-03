#!/bin/bash

copybook=../../cpy/
scripts=../../scripts/
cobc=cobc

gen_files () {
	# generate COBOL file generator program
	ruby ${scripts}seq2cob.rb ${input} ${output} $progname $copybook $copyname $recordname $key $altkeys > ${progname}.cob

	# compile, run and remove COBOL program
	$cobc -x -I$copybook ${progname}.cob -o $progname
	./$progname
	rm $progname
	rm ${progname}.cob
}

gen_str () {
	ruby ${scripts}cpy2str.rb $copybook$copyname > ${progname}.str
}

progname=usrsec
input=usrsec.txt
output=AWS.M2.CARDDEMO.USRSEC
key=SEC-USR-ID
altkeys=[]
copyname=CSUSR01Y
gen_files
gen_str
echo "${progname} generated."

progname=carddata
input=carddata.txt
output=AWS.M2.CARDDEMO.CARDDATA
key=CARD-NUM
altkeys=[]
copyname=CVACT02Y
gen_files
gen_str
echo "${progname} generated."

progname=acctdata
input=acctdata.txt
output=AWS.M2.CARDDEMO.ACCTDATA
key=ACCT-ID
altkeys=[]
copyname=CVACT01Y
gen_files
gen_str
echo "${progname} generated."

progname=transact
input=dailytran.txt
output=AWS.M2.CARDDEMO.TRANSACT
key=TRAN-ID
altkeys=[]
copyname=CVTRA05Y
gen_files
gen_str
echo "${progname} generated."
