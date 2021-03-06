#!/bin/bash
#./gen_node_cert.sh <organisation name> <nodedn> <nodedns> <truststore password> <root ca passsord> 
#########################
# 'dname' and 'ext san' have to specified on two location in this file  
# For the meaning of oid:1.2.3.4.5.5 see:
#    https://github.com/floragunncom/search-guard-docs/blob/master/architecture.md
#    https://github.com/floragunncom/search-guard-docs/blob/master/installation.md
#########################

set -e
ORGA_NAME="$1"
NODE_NAME="$2"
NODE_DNS="$3"

if [ -z "$4" ] ; then
  unset CA_PASS KS_PASS
  read -p "Enter CA pass: " -s CA_PASS ; echo
  read -p "Enter Keystore pass: " -s KS_PASS ; echo
 else
  KS_PASS="$4"
  CA_PASS="$5"
fi

rm -f "$NODE_NAME-keystore.jks"
rm -f "$NODE_NAME.csr"
rm -f "$NODE_NAME-signed.pem"

echo Generating keystore and certificate for node "$NODE_NAME"

keytool -genkey \
        -alias     "$NODE_NAME" \
        -keystore  "$NODE_NAME-keystore.jks" \
        -keyalg    RSA \
        -keysize   2048 \
        -validity  712 \
        -sigalg SHA256withRSA \
        -keypass "$KS_PASS" \
        -storepass "$KS_PASS" \
        -dname "$NODE_NAME" \
        -ext san=dns:$NODE_DNS,oid:1.2.3.4.5.5 
        
#oid:1.2.3.4.5.5 denote this a server node certificate for search guard

echo Generating certificate signing request for node $NODE_NAME

keytool -certreq \
        -alias      "$NODE_NAME" \
        -keystore   "$NODE_NAME-keystore.jks" \
        -file       "$NODE_NAME.csr" \
        -keyalg     rsa \
        -keypass "$KS_PASS" \
        -storepass "$KS_PASS" \
        -dname "$NODE_NAME" \
        -ext san=dns:$NODE_DNS,oid:1.2.3.4.5.5
        
#oid:1.2.3.4.5.5 denote this a server node certificate for search guard

echo Sign certificate request with CA
openssl ca \
    -in "$NODE_NAME.csr" \
    -notext \
    -out "$NODE_NAME-signed.pem" \
    -config "etc/gen-signing-ca.conf.$ORGA_NAME" \
    -extensions v3_req \
    -batch \
	-passin "pass:$CA_PASS" \
	-extensions server_ext 

echo "Import back to keystore (including CA chain)"

cat ca/chain-ca.pem "$NODE_NAME-signed.pem" | keytool \
    -importcert \
    -keystore "$NODE_NAME-keystore.jks" \
    -storepass "$KS_PASS" \
    -noprompt \
    -alias "$NODE_NAME"
    
keytool -importkeystore -srckeystore "$NODE_NAME-keystore.jks" -srcstorepass "$KS_PASS" -srcstoretype JKS -deststoretype PKCS12 -deststorepass "$KS_PASS" -destkeystore "$NODE_NAME-keystore.p12"

echo All done for "$NODE_NAME"
	
