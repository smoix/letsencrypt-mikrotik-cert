#!/usr/bin/bash

#Variables you shoud change according to your needs
MIKROTIK_HOST=192.168.0.1
MIKROTIK_PORT=22
MIKROTIK_USER=letsencrypt
MIKROTIK_SSH_KEY=/opt/letsencrypt-mikrotik-cert/id_rsa_letsencrypt
LE_DOMAIN=my.domain.com
LE_CERTIFICATE=/etc/letsencrypt/live/$LE_DOMAIN/fullchain.pem
LE_KEY=/etc/letsencrypt/live/$LE_DOMAIN/privkey.pem

#Create alias for Mikrotik ssh access command
ssh_params="-i $MIKROTIK_SSH_KEY -p $MIKROTIK_PORT $MIKROTIK_USER@$MIKROTIK_HOST"

#Check connection to RouterOS
ssh $ssh_params /system resource print
RESULT=$?

#Check if the SSH login works
if [[ ! $RESULT == 0 ]]; then
        echo -e "\nError in: $ssh_command"
        echo "Your automatic SSH login does not work, check your SSH keys and user"
        exit 1
else
        echo -e "\nConnection to RouterOS Successful!\n"
fi

#Check if we have a Letsencrypt key
if [ ! -f $LE_KEY ]; then
        echo -e "\nLetsencrypt key not found:\n$LE_KEY\n"
        exit 1
fi

#Check if we have a Letsencrypt certificate
if [ ! -f $LE_CERTIFICATE ]; then
        echo -e "\nLetsencrypt certificate not found:\n$LE_CERTIFICATE\n"
        exit 1
fi

# Remove previous certificates and certificate files
ssh $ssh_params /certificate remove [find name=$LE_DOMAIN-fullchain.pem_0]
ssh $ssh_params /certificate remove [find name=$LE_DOMAIN-fullchain.pem_1]
ssh $ssh_params /file remove $LE_DOMAIN-fullchain.pem > /dev/null
ssh $ssh_params /file remove $LE_DOMAIN-privkey.pem > /dev/null
sleep 2
# Upload new certificate and key to RouterOS
scp -q -i $MIKROTIK_SSH_KEY -P $MIKROTIK_PORT $LE_CERTIFICATE $MIKROTIK_USER@$MIKROTIK_HOST:$LE_DOMAIN-fullchain.pem
scp -q -i $MIKROTIK_SSH_KEY -P $MIKROTIK_PORT $LE_KEY $MIKROTIK_USER@$MIKROTIK_HOST:$LE_DOMAIN-privkey.pem
sleep 2
# Import new certificate and key to RouterOS
ssh $ssh_params /certificate import file-name=$LE_DOMAIN-fullchain.pem passphrase=\"\"
ssh $ssh_params /certificate import file-name=$LE_DOMAIN-privkey.pem passphrase=\"\"
sleep 2
#Clean up the uploaded files as they are not needed anymore after import
ssh $ssh_params /file remove $LE_DOMAIN-fullchain.pem > /dev/null
ssh $ssh_params /file remove $LE_DOMAIN-privkey.pem > /dev/null
#Activate the certificate on the www-ssl and api-ssl services:
ssh $ssh_params /ip service set www-ssl certificate=$LE_DOMAIN-fullchain.pem_0
ssh $ssh_params /ip service set api-ssl certificate=$LE_DOMAIN-fullchain.pem_0

exit 0