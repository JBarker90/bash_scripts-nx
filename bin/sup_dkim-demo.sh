#!/bin/bash

help(){
    # Displays Help message
    echo "This bash script can be used to check if a DKIM key exists for a domain and generate one if needed."
    echo "It can also find the DKIM public key file and output the DKIM value in a DNS record format."
    echo 
    echo "Syntax: sup_dkim-demo.sh [-h|c|f] [domain]"
    echo "options:"
    echo "  -h    Print this Help message."
    echo "  -c    Create a DKIM Key for a specific domain and formats it in DNS record values."
    echo "  -f    Can be used to Force a new DKIM key to be generated."
    echo
}

usage(){
    echo "Syntax: sup_dkim-demo.sh [-h|c|f] [domain]"
    echo "options:"
    echo "  -h    Print this Help message."
    echo "  -c    Create a DKIM Key for a specific domain and formats it in DNS record values."
    echo "  -f    Can be used to Force a new DKIM key to be generated."
    echo
}

dkim_gen(){
    if [[ "$option" == "f" ]] && [[ -e "/etc/domainkeys/${DOMAIN}/rsa.public" ]]; then
        echo "Replacing the old DKIM Key..."
        if [[ $(hostname -s) == "cloudhost-"* ]]; then
            sudo -u iworx ~iworx/bin/domainkeys.pex --domain "$DOMAIN"
        else
            ~iworx/bin/domainkeys.pex --domain "$DOMAIN"
        fi
        wait
        echo "Done..."
    elif [[ -e "/etc/domainkeys/${DOMAIN}/rsa.public" ]]; then
        echo "The domain $DOMAIN already has a DKIM Key."
    else
        echo "Generating a DKIM Key..."
        if [[ $(hostname -s) == "cloudhost-"* ]]; then
            sudo -u iworx ~iworx/bin/domainkeys.pex --domain "$DOMAIN"
        else
            ~iworx/bin/domainkeys.pex --domain "$DOMAIN"
        fi
        wait
        echo "Done..."
    fi 
    dkim_find
    exit 0
}

dkim_find(){
    NX_DKIM_KEY=$(sudo grep -v -- ^- /etc/domainkeys/"${DOMAIN}"/rsa.public 2>/dev/null | tr -d '\n')
    DKIM_KEY=$(sudo grep -v -- ^- /etc/domainkeys/"${DOMAIN}"/rsa.public 2>/dev/null | tr -d '\n' | awk '{print "v=DKIM1; k=rsa; p="$0";"}' | sed -e 's/.*/"&"/; s/.\{255\}/&"\n"/g' | tr -d '\n' | sed -e 's/""/" "/g')
    echo -e "\nType:\t" "TXT"
    echo -e "TTL:\t" "1800"
    echo -e "Host:\t" "default._domainkey.${DOMAIN}"
    echo -e "NX DNS Value:\t" "${NX_DKIM_KEY}"
    echo -e "Remote DNS Value:\t" "${DKIM_KEY}"
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

shift "$(( OPTIND - 1 ))"
