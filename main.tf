# Create datasource of images from the image list
data "oci_core_images" "images" {
  compartment_id = var.compartment_ocid
  operating_system = var.os
  filter {
    name = "display_name"
    values = [var.os_image_build]
    regex = true
  }
}

# Create a compute instance with a public IP address using oci provider
resource "oci_core_instance" "instance" {
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = var.instance_name
  shape               = var.instance_shape

  shape_config {
    #Optional
    memory_in_gbs = var.memory_in_gbs
    ocpus = var.ocpus
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.images.images[0].id
    boot_volume_size_in_gbs = 100
  }

  create_vnic_details {
    assign_public_ip = "false"
    subnet_id        = oci_core_subnet.private_subnet.id
  }
  # Add private key
  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
#    user_data           = base64encode(file("setup-instance-ol8.sh"))
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false
    plugins_config {
      desired_state = "ENABLED"
      name = "Bastion"
    }
  }

}

# Create datasource for availability domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.compartment_ocid
}

# Create a NAT Gateway
resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "${var.instance_name}-nat-gateway"
}

resource "oci_core_route_table" "route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "${var.instance_name}-route-table-private"
  route_rules {
    destination = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.nat_gateway.id
  }
}

# Create security list with ingress and egress rules
resource "oci_core_security_list" "security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "${var.instance_name}-security-list-private"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    description = "Allow all outbound traffic"
  }

  ingress_security_rules {
    protocol    = "all"
    source      = "0.0.0.0/0"
    description = "Allow all inbound traffic"
  }

  # ingress rule for ssh
    ingress_security_rules {
        protocol    = "6" # tcp
        source      = "0.0.0.0/0"
        description = "Allow ssh"
        tcp_options {
            max = 22
            min = 22
        }
    }
}


# Create private subnet
resource "oci_core_subnet" "private_subnet" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  cidr_block     = var.subnet_cidr
  display_name   = "${var.instance_name}-subnet-private"

  prohibit_public_ip_on_vnic = true

  route_table_id    = oci_core_route_table.route_table.id
  dhcp_options_id   = oci_core_virtual_network.vcn.default_dhcp_options_id
  security_list_ids = ["${oci_core_security_list.security_list.id}"]
}

# Create a virtual network
resource "oci_core_virtual_network" "vcn" {
  cidr_block     = var.vcn_cidr
  compartment_id = var.compartment_ocid
  display_name   = "${var.instance_name}-vcn"
}


resource "oci_bastion_bastion" "bastion" {

  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_ocid
  target_subnet_id = oci_core_subnet.private_subnet.id

  client_cidr_block_allow_list = [
    "0.0.0.0/0"
  ]
  name = "${var.instance_name}-bastion"
  
}

resource "time_sleep" "wait_for_bastion_agent_active" {
  create_duration = "180s"
  depends_on = [
    oci_bastion_bastion.bastion
  ]
}

resource "oci_bastion_session" "oci_bastion_session" {

  depends_on = [
    time_sleep.wait_for_bastion_agent_active
  ]

  bastion_id = oci_bastion_bastion.bastion.id
  key_details {
    public_key_content = file(var.ssh_public_key_path)
  }
  target_resource_details {
    session_type       = "MANAGED_SSH"
    target_resource_id = oci_core_instance.instance.id
    target_resource_operating_system_user_name = "opc"
    target_resource_port                       = "22"
  }
  session_ttl_in_seconds = 3600
  display_name = "${var.instance_name}-bastion-session-ssh"
}


# resource "null_resource" "retry" {
#   count = 100  # Change this to the number of retries you want to perform
  
#   triggers = {
#     wait = "${timeadd(timestamp(), "10s")}"  # Change the duration to the time you want to wait between retries
#   }
  
#   provisioner "local-exec" {
#     command = "terraform apply -target=oci_bastion_session.oci_bastion_session"  # Change the target to the resource you want to retry
#   }
# }

# resource "oci_bastion_session" "oci_bastion_session" {

#   bastion_id = oci_bastion_bastion.bastion.id
#   key_details {
#     public_key_content = file(var.ssh_public_key_path)
#   }
#   target_resource_details {
#     session_type       = "MANAGED_SSH"
#     target_resource_id = oci_core_instance.instance.id
#     target_resource_operating_system_user_name = "opc"
#     target_resource_port                       = "22"
#   }
#   session_ttl_in_seconds = 3600
#   display_name = "${var.instance_name}-bastion-session-ssh"
# }

output "connection_details" {
  value = <<EOF
  
  Bastion ssh: ${oci_bastion_session.oci_bastion_session.ssh_metadata.command} 

  Change <privateKey> with server.key

EOF
}
