terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key      = var.private_key
  region           = var.region
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ol8" {
  compartment_id   = var.compartment_ocid
  operating_system = "Oracle Linux"
  shape            = "VM.Standard.A1.Flex"
  sort_by          = "TIMECREATED"
  sort_order       = "DESC"
}

resource "tls_private_key" "cell" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "oci_core_instance" "cell" {
  compartment_id      = var.compartment_ocid
  display_name        = "monse-cell-${var.cell_id}"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = true
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ol8.images[0].id
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.cell.public_key_openssh
    user_data = base64encode(templatefile("${path.module}/cloud-init.yml", {
      subdomain      = var.subdomain
      base_domain    = var.base_domain
      customer_email = var.customer_email
    }))
  }
}

output "vm_public_ip" {
  value = oci_core_instance.cell.public_ip
}