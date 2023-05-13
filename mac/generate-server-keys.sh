#!/bin/bash

# Set key file names
key_name="$(date '+%Y-%m-%d_%H-%M-%S')"
folder_name="keys_$(date '+%Y-%m-%d_%H-%M-%S')"

# Create the folder if it doesn't exist
mkdir -p $folder_name

pem_file="${folder_name}/${key_name}.pem"
ppk_file="${folder_name}/${key_name}.ppk"
pub_file="${folder_name}/${key_name}.pub"

# Generate an RSA private key and save it as a .pem file
openssl genrsa -out $pem_file 2048
chmod 600 $pem_file

# Generate the corresponding public key (.pub) file in the standard format
ssh-keygen -t rsa -f $pem_file -y > temp_pub_file
public_key=$(<temp_pub_file)
echo "$public_key" > $pub_file
rm temp_pub_file

# Convert the .pem file to a .ppk file using puttygen (requires the 'putty' package to be installed)
if command -v puttygen >/dev/null 2>&1; then
    puttygen $pem_file -o $ppk_file -O private
else
    echo "Puttygen not found. Please install 'putty' package and run the script again."
    exit 1
fi

echo "Files generated:"
echo "  - $pem_file"
echo "  - $ppk_file"
echo "  - $pub_file"
