# tf-aws-infra

#### This Repository contains code for Terraform

Clone the Repository to your wokrspace.
create a .tfvars file to give unput to the variables defined in the code.

#### Run the following commands sequencially:

1. terraform init
2. terraform validate
3. terraform plan
4. terraform apply

#### By now the required resources will be created

To bring down the resources run the following command:
terraform destroy

To create certificate, go inside the cert directory.
The directory will contain cert files.
###### Run the following command:

aws acm import-certificate \
--certificate fileb://certificate.crt \
--private-key fileb://private.key \
--certificate-chain fileb://ca_bundle.crt \
--region us-east-1
