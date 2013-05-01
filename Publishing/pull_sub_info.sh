#!/bin/bash

BOLD=`tput bold`
NORM=`tput sgr0`

WHITE="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
PURPLE="\e[35m"

for sub in "$@"
do
    echo -e "-+-+- ${BOLD}${BLUE}$sub${WHITE}${NORM} -+-+-"
    echo -e "${BOLD}Name:   ${PURPLE}$(cat $HOME/Data/nih_spreadsheet | awk -v s=$sub 'BEGIN { FS = "\t" } $18 == s' | cut -f1)${WHITE}${NORM}"
    echo -e "${BOLD}Lab:    ${RED}$(cat $HOME/Data/nih_spreadsheet | awk -v s=$sub 'BEGIN { FS = "\t" } $18 == s' | cut -f2,3 | sed 's/\t/, /')${WHITE}${NORM}"
    echo "Assay:  $(cat $HOME/Data/nih_spreadsheet | awk -v s=$sub 'BEGIN { FS = "\t" } $18 == s' | cut -f4)"
    echo "Org.:   $(cat $HOME/Data/nih_spreadsheet | awk -v s=$sub 'BEGIN { FS = "\t" } $18 == s' | cut -f10)"
    echo "Status: $(cat $HOME/Data/nih_spreadsheet | awk -v s=$sub 'BEGIN { FS = "\t" } $18 == s' | cut -f17)"
    echo "GEO:    $(cat $HOME/Data/nih_spreadsheet | awk -v s=$sub 'BEGIN { FS = "\t" } $18 == s' | cut -f19)"
    echo
done
