#!/bin/bash

DOMAIN=$2
DKIM_KEY=$(sudo grep -v -- ^- /etc/domainkeys/"${DOMAIN}"/rsa.public 2>/dev/null | tr -d '\n')

help(){
    # Displays Help message
    echo "This bash script can be used to check if a DKIM key exists for a domain and generate one if needed."
    echo "It can also find the DKIM public key file and output the DKIM value in a DNS record format."
    echo 
    echo "Syntax: <sup_dkim1.sh> [-h|c|f] [<domain>]"
    echo "options:"
    echo "-h    Print this Help message."
    echo "-c    Create a DKIM Key for a specific domain and formats it in DNS record values."
    echo "-f    Can be used to Force a new DKIM key to be generated."
}

function usage(){
    echo "Syntax: <sup_dkim1.sh> [-h|c|f] [<domain>]"
    echo "options:"
    echo "-h    Print this Help message."
    echo "-c    Create a DKIM Key for a specific domain and formats it in DNS record values."
    echo "-f    Can be used to Force a new DKIM key to be generated."
}

function dkim_gen(){
    if [[ -e "/etc/domainkeys/${DOMAIN}/rsa.public" ]]; then
        dkim_find
        exit;
    else
        echo "Generating DKIM Key"
        echo "sudo -u iworx ~iworx/bin/domainkeys.pex --domain "$DOMAIN""
        #if [[ $(hostname -s) == "cloudhost-"* ]]; then
        #    sudo -u iworx ~iworx/bin/domainkeys.pex --domain "$DOMAIN"
        #else
        #    ~iworx/bin/domainkeys.pex --domain "$DOMAIN"
        #fi
        #wait

        #sudo cat -n /etc/domainkeys/"${DOMAIN}"/rsa.public
    fi  
}

function dkim_find(){
        echo -e "\nType:\t" "TXT"
        echo -e "Host:\t" "default._domainkey.${DOMAIN}"
        echo -e "Value:\t" "v=DKIM1; k=rsa; p=${DKIM_KEY};"
}

if (( $# == 0 )); then
    usage
fi

# Get options for script

while getopts "hc:f:" option; do
    case $option in
        h) # Displays help message
            help
            exit;;
        c) # Creates DKIM Key
            dkim_gen
            ;;
        f) # Finds DKIM key and Formats in DNS value
            dkim_find
            ;;
        \?) # If an option is given that doesn't exist
            usage
            exit;;
    esac
done