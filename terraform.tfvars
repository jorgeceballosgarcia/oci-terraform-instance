instance_name       = "oci-instance"
instance_shape      = "VM.Standard.E4.Flex"
ssh_public_key_path = "server.key.pub"
subnet_cidr         = "10.0.20.0/24"
vcn_cidr            = "10.0.20.0/16"
region              = "eu-paris-1"
os                  = "Oracle Linux"
os_image_build      = "^Oracle-Linux-8([\\.0-9-]+)$"
memory_in_gbs       = "16"
ocpus               = "1"