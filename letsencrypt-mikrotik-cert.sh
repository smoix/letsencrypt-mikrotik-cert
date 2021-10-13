#!/bin/bash

# Variable comes from the environment, making this script configurable for multiple MTK units
# Some have reasonable defaults like SSH port set to 22 and username to "letsencrypt", environment
# provided values overhide defaults.
MIKROTIK_HOST="${MTK_HOSTIP}"
MIKROTIK_HOSTNAME="${MTK_HOSTNAME}"
MIKROTIK_PORT="${MTK_SSH_PORT:-22}"
MIKROTIK_USER="${MTK_SSH_USERNAME:-letsencrypt}"
MIKROTIK_SSH_KEY=/opt/letsencrypt-mikrotik-cert/id_rsa_letsencrypt
LE_DOMAIN="${MTK_LE_DOMAIN:-mikrotik.myhome.lan}"
LE_CERTIFICATE=/etc/letsencrypt/live/tls.crt
LE_KEY=/etc/letsencrypt/live/tls.key

if [[ -z ${MIKROTIK_HOST} ]]; then
        MIKROTIK_HOST=${MIKROTIK_HOSTNAME}
fi

MTK_CERT_TMP="$(mktemp)"
K8S_CERT_TMP="$(mktemp)"

#Create alias for Mikrotik ssh access command
ssh_params=(-i "$MIKROTIK_SSH_KEY" -p "$MIKROTIK_PORT" "$MIKROTIK_USER@$MIKROTIK_HOST")

#Check connection to RouterOS
ssh -oStrictHostKeyChecking=no "${ssh_params[@]}" /system resource print
RESULT=$?

#Check if the SSH login works
if [[ ! $RESULT == 0 ]]; then
        echo -e "\nError in ssh command"
        echo "Your automatic SSH login does not work, check your SSH keys and user"
        exit 1
else
        echo -e "\nConnection to RouterOS Successful!\n"
fi

#Check if we have a Letsencrypt key
if [ ! -f "$LE_KEY" ]; then
        echo -e "\nLetsencrypt key not found:\n$LE_KEY\n"
        exit 1
fi

#Check if we have a Letsencrypt certificate
if [ ! -f "$LE_CERTIFICATE" ]; then
        echo -e "\nLetsencrypt certificate not found:\n$LE_CERTIFICATE\n"
        exit 1
fi

# Read current certificate from Mikrotik and the one provided by K8S, compare both.
# If different, then proceed with update, otherwise abort
echo | openssl s_client -showcerts -servername "${MIKROTIK_HOSTNAME}" -connect "${MIKROTIK_HOST}:443" 2>/dev/null | openssl x509 -inform pem -noout -text > "${MTK_CERT_TMP}"
if ! grep Validity "${MTK_CERT_TMP}" > /dev/null; then
        echo -e "\nThere is no validity on Mikrotik read certificate. Reading error?\n"
        echo -e "\n\n"
        cat "${MTK_CERT_TMP}"
        exit 1
fi

openssl x509 -inform pem -noout -text < "$LE_CERTIFICATE" > "${K8S_CERT_TMP}"
if ! grep Validity "${K8S_CERT_TMP}" > /dev/null; then
        echo -e "\nThere is no validity on K8S provided certificate. Reading error?\n"
        echo -e "\n\n"
        cat "${K8S_CERT_TMP}"
        exit 1
fi

if cmp "${MTK_CERT_TMP}" "${K8S_CERT_TMP}"; then
        echo -e "\nCertificates are equal, no need to install\n"
        exit 0
fi

# Remove previous certificates and certificate files
echo -e "\nDeleting old files and certificates from Mikrotik device"
ssh "${ssh_params[@]}" /certificate remove [find name="$LE_DOMAIN"-fullchain.pem_0]
ssh "${ssh_params[@]}" /certificate remove [find name="$LE_DOMAIN"-fullchain.pem_1]
ssh "${ssh_params[@]}" /certificate remove [find name="$LE_DOMAIN"-fullchain.pem_2]
ssh "${ssh_params[@]}" /file remove "$LE_DOMAIN"-fullchain.pem > /dev/null
ssh "${ssh_params[@]}" /file remove "$LE_DOMAIN"-privkey.pem > /dev/null
sleep 2
# Upload new certificate and key to RouterOS
echo -e "\nUploading new certificate files to Mikrotik device"
scp -q -i $MIKROTIK_SSH_KEY -P "$MIKROTIK_PORT" "$LE_CERTIFICATE" "$MIKROTIK_USER@$MIKROTIK_HOST:$LE_DOMAIN-fullchain.pem"
scp -q -i $MIKROTIK_SSH_KEY -P "$MIKROTIK_PORT" "$LE_KEY" "$MIKROTIK_USER@$MIKROTIK_HOST:$LE_DOMAIN-privkey.pem"
sleep 2
# Import new certificate and key to RouterOS
echo -e "\nImporting certificates into Mikrotik keyring"
ssh "${ssh_params[@]}" /certificate import file-name="$LE_DOMAIN"-fullchain.pem passphrase=\"\"
ssh "${ssh_params[@]}" /certificate import file-name="$LE_DOMAIN"-privkey.pem passphrase=\"\"
sleep 2
#Clean up the uploaded files as they are not needed anymore after import
echo -e "\nDelete uplodaed files"
ssh "${ssh_params[@]}" /file remove "$LE_DOMAIN"-fullchain.pem > /dev/null
ssh "${ssh_params[@]}" /file remove "$LE_DOMAIN"-privkey.pem > /dev/null
#Activate the certificate on the www-ssl and api-ssl services:
echo -e "\nActivate imported certificate into Mikrotik services"
ssh "${ssh_params[@]}" /ip service set www-ssl certificate="$LE_DOMAIN"-fullchain.pem_0
ssh "${ssh_params[@]}" /ip service set api-ssl certificate="$LE_DOMAIN"-fullchain.pem_0

exit 0