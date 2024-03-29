#!/bin/bash

#DOMAIN=$3
#DKIM_KEY=$(sudo grep -v -- ^- /etc/domainkeys/"${DOMAIN}"/rsa.public 2>/dev/null | tr -d '\n')

help(){
    # Displays Help message
    echo "This bash script can be used to check if a DKIM key exists for a domain and generate one if needed."
    echo "It can also find the DKIM public key file and output the DKIM value in a DNS record format."
    echo 
    echo "Syntax: sup_dkim3.sh [-h|c|f] [domain]"
    echo "options:"
    echo "  -h    Print this Help message."
    echo "  -c    Create a DKIM Key for a specific domain and formats it in DNS record values."
    echo "  -f    Can be used to Force a new DKIM key to be generated."
    echo
}

usage(){
    echo "Syntax: sup_dkim3.sh [-h|c|f] [domain]"
    echo "options:"
    echo "  -h    Print this Help message."
    echo "  -c    Create a DKIM Key for a specific domain and formats it in DNS record values."
    echo "  -f    Can be used to Force a new DKIM key to be generated."
    echo
}

dkim_gen(){
    if [[ "$option" == "f" ]] && [[ -e "/etc/domainkeys/${DOMAIN}/rsa.public" ]]; then
        echo "Generating new DKIM Key"
        if [[ $(hostname -s) == "cloudhost-"* ]]; then
            echo "sudo -u iworx ~iworx/bin/domainkeys.pex --domain $DOMAIN"
        else
            echo "~iworx/bin/domainkeys.pex --domain $DOMAIN"
        fi
        #wait

        #sudo cat -n /etc/domainkeys/"${DOMAIN}"/rsa.public
    elif [[ -e "/etc/domainkeys/${DOMAIN}/rsa.public" ]]; then
        echo "The domain $DOMAIN already has a DKIM Key."
    else
        echo "Generating DKIM Key"
        if [[ $(hostname -s) == "cloudhost-"* ]]; then
            echo "sudo -u iworx ~iworx/bin/domainkeys.pex --domain $DOMAIN"
        else
            echo "~iworx/bin/domainkeys.pex --domain $DOMAIN"
        fi
        #wait

        #sudo cat -n /etc/domainkeys/"${DOMAIN}"/rsa.public
    fi 
    dkim_find
    #exit 0
}

dkim_find(){
    DKIM_KEY=$(sudo grep -v -- ^- /etc/domainkeys/"${DOMAIN}"/rsa.public 2>/dev/null | tr -d '\n')
    echo -e "\nType:\t" "TXT"
    echo -e "Host:\t" "default._domainkey.${DOMAIN}"
    echo -e "Value:\t" "v=DKIM1; k=rsa; p=${DKIM_KEY};"
}

if [[ $# == 0 || "${#1}" -gt 2 ]]; then
    usage
    exit 1
fi

# Get options for script

while getopts "hc:f:" option; do
    case $option in
        h) # Displays help message
            help
            exit 1
            ;;
        c) # Creates DKIM Key
            DOMAIN="${OPTARG}"
            if [[ "${DOMAIN}" == "-f" || "${DOMAIN}" == "-c" ]]; then
                usage
                exit 1
            fi
            dkim_gen
            ;;
        f) # Forces DKIM key to generate if it needs to be regenerated
            DOMAIN="${OPTARG}"
            if [[ "${DOMAIN}" == "-f" || "${DOMAIN}" == "-c" ]]; then
                usage
                exit 1
            fi
            dkim_gen
            ;;
        \?) # If an option is given that doesn't exist
            usage
            exit 1
            ;;
    esac
done

echo -e "\nNumber of args: ${#}"
echo "All args: ${*}"
echo "First arg: ${1}"
echo "Second arg: ${2}"
echo "Third arg: ${3}"

shift "$(( OPTIND - 1 ))"
