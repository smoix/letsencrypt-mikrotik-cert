# Lets's Encrypt Mikrotik SSL/TLS certificate

This is a script to upload a Let's Encrypt (or any other valid certificate for that matter) SSL/TLS certificate to a Mikrotik router and activate it on SSL Webfig and SSL API services. The certificate can then also be used for SSTP or other VPN requiring a certificate. It losely based on https://github.com/gitpel/letsencrypt-routeros with a focus on simplicity.

What you will need to do manually is:
* Generate a Let's Encrypt certificate
* Create an user to SSH to your Mikrotik
* Run the script to transfer and activate the certificate

### Generate a Let's Encrypt certificate
To generate a valid (not auto-signed) SSL/TLS certificate we can either buy one or generate a free certificate using Let's Encrypt. Generating a Let's Encrypt certificate is out of the scope of this readme but the easiest way is to have a Web Server and generate a certificate there, adding a second domain to an already existing certificate for our Mikrotik. 

Documentation on how to install certbot is available on https://certbot.eff.org/ In this example, on a CentOS 8 Stream Web Server, I added "mikrotik.mydmain.com" to the certificate for "www.mydomain.com". Here is a certificate generation example using the HTTP-01 challenge (it creates a challenge in /var/www/www.mydomaion.com/, which is the root directory of the www.mydomain.com domain):
```sh
certbot-auto certonly --webroot --webroot-path /var/www/www.mydomain.com/ --domain www.mydomain.com --domain mikrotik.amydomain.com --email webmaster@mydomain.com
```

So, now we have a valid certificate in /etc/letsencrypt/live/www.mydomain.com/fullchain.pem and the private key in /etc/letsencrypt/live/www.mydomain.com/privkey.pem and it's time to automate the transfer to our Mikrotik router as we don't want to manually do this every 90 days or so when it is renewed. 

### Install the script 
It's simple, clone this repository
```sh
cd /opt
git clone https://github.com/smoix/letsencrypt-mikrotik-cert
```

### Configure an user on your Mikrotik to do SSH transfers
Go to the Mikrotik, and using Winbox enable the SSH service under IP > Services. Enable it only on your local network for security reasons (remember that the web server where we generated the SSL/TLS certificate is on the same local network). Don't forget to create a firewall rule for port 22 in the "Input" chain.

Then create an user under System > Users > Users. Mine is called "letsencrypt", has full privileges and a long password we will only use once.

From our Web Server, we then need to create an SSH RSA certificate so we can login to our Mikrotik server remotely using the user we just created, to create and upload this key to our Mikrotik
```sh
ssh-keygen -f /opt/letsencrypt-mikrotik-cert/id_rsa_letsencrypt -N ""
scp /opt/letsencrypt-mikrotik-cert/id_rsa_letsencrypt.pub letsencrypt@192.168.0.1:id_rsa_letsencrypt.pub
```

And import the newly uploaded certificate in Mikrotik, under System > Users > SSH Keys

After that you should be able to login without password to your server:
```sh
ssh letsencrypt@192.168.0.1 -i /opt/letsencrypt-mikrotik-cert/id_rsa_letsencrypt
```

### Configure the script, upload and activate a certificate
Start by editing the script and setup the 5 following variables accordong to your environment:
```sh
MIKROTIK_HOST=192.168.0.1
MIKROTIK_PORT=22
MIKROTIK_USER=letsencrypt
MIKROTIK_SSH_KEY=/opt/letsencrypt-mikrotik-cert/id_rsa_letsencrypt
LE_DOMAIN=www.mydomain.com
```
Make the script executable and run it:
```sh
chmod +x letsencrypt-mikrotik-cert.sh
./letsencrypt-mikrotik-cert.sh
```

That's pretty much it, you should be able to access 
