#!/usr/bin/bash

TERRAFORM_VERSION="1.10.5"
TERRAGRUNT_VERSION="v0.72.9"

curl -LO https://github.com/gruntwork-io/terragrunt/releases/download/$TERRAGRUNT_VERSION/terragrunt_linux_amd64
curl -LO https://github.com/gruntwork-io/terragrunt/releases/download/$TERRAGRUNT_VERSION/SHA256SUMS

expected_hash=$(grep terragrunt_linux_amd64 SHA256SUMS | awk '{print $1}')
computed_hash=$(sha256sum terragrunt_linux_amd64 | awk '{print $1}')

if [ "$expected_hash" == "$computed_hash" ]; then
        echo "Hashes match: Terragrunt binary is valid."
        chmod +x terragrunt_linux_amd64
        sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
else
        echo "Hashes do not match: Terragrunt binary may be corrupted."
fi

wget https://releases.hashicorp.com/terraform/$TERRAFORM_VERSION/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
wget https://releases.hashicorp.com/terraform/$TERRAFORM_VERSION/terraform_${TERRAFORM_VERSION}_SHA256SUMS

expected_hash=$(grep terraform_${TERRAFORM_VERSION}_linux_amd64.zip terraform_${TERRAFORM_VERSION}_SHA256SUMS | awk '{print $1}')
computed_hash=$(sha256sum terraform_${TERRAFORM_VERSION}_linux_amd64.zip | awk '{print $1}')

if [ "$expected_hash" == "$computed_hash" ]; then
        echo "Hashes match: Terraform binary is valid."
        unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
        sudo mv terraform /usr/local/bin/
else
        echo "Hashes do not match: Terraform binary may be corrupted."
fi

echo "Removing temporary files.."
rm -v terraform_${TERRAFORM_VERSION}_linux_amd64.zip terraform_${TERRAFORM_VERSION}_SHA256SUMS SHA256SUMS
