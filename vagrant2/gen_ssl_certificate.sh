#!/bin/bash
 
#Required
 
#Change to your company details

mkdir /root/keys
cd /root/keys
openssl req -x509 -sha256 -newkey rsa:2048 -keyout selfkey.key -out selfcert.crt -days 1024 -nodes \
-subj "/C=TH/ST=Bangkok/L=Bankok/O=ITBAKERY/OU=IT Department/CN=controller.example.com/emailAddress=sawangpong@itbakery.net"

cp selfkey.key /etc/pki/tls/private/
cp selfcert.crt /etc/pki/tls/certs/

mkdir -p /root/packstackca/certs

