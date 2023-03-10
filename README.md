# OCI TERRAFORM INSTANCE

Terraform script for provisioning a compute instance in OCI

## Requirements

- OCI CLI
- Terraform
- ssh-keygen

## Configuration

1. Follow the instructions to install and add the authentication to your tenant https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm

2. Clone this repository

```
# Stable diffusion 1.5
git clone --depth 1 --branch main https://github.com/jorgeceballosgarcia/oci-terraform-instance.git
```

3. Set two variables in your path. 
- The tenancy OCID, 
- The comparment OCID where the instance will be created.

```
export TF_VAR_tenancy_ocid='<tenancy-ocid>'
export TF_VAR_compartment_ocid='<comparment-ocid>'
```

4. Personalize your terraform.tfvars

```
instance_name       = "oci-instance"
instance_shape      = "VM.Standard.E4.Flex"
ssh_public_key_path = "server.key.pub"
subnet_cidr         = "10.0.0.0/24"
vcn_cidr            = "10.0.0.0/16"
region              = "eu-paris-1"
os                  = "Oracle Linux"
os_image_build      = "^Oracle-Linux-8([\\.0-9-]+)$"
memory_in_gbs       = "16"
ocpus               = "1"
```

5. Execute the script generate-keys.sh to generate private key to access the instance
```
sh generate-keys.sh
```

## Build
To build simply execute the next commands. 
```
terraform init
terraform plan
terraform apply
```

## Connect to compute instance

The output of the terraform script will give the ssh full command so you only need to copy and paste

```
ssh -i server.key -o ProxyCommand="ssh -i server.key -W %h:%p -p 22 ocid1.bastionsession.XXXX@host.bastion.XXXX.oci.oraclecloud.com" -p 22 opc@<instance_private_ip>
```
The instance created is located in a vcn with a private subnet, and "Bastion Service" is used to connect to it.
The life of the bastion service session is one hour, after that time it disappears. To be able to connect again, we will have to launch ```terraform apply``` again and it will create a new bastion session.

## Clean
To delete the instance execute.
```
terraform destroy
```

## Start&Stop Instance
To start or stop the instance just execute the script start-stop-instance.sh

If the instance is RUNNING the script STOP it and viceversa

```
/bin/bash start-stop-instance.sh
```
