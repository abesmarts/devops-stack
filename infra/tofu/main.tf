terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.40.0"
    }
  }
}



# ------------------------
# Provider
# ------------------------
provider "google" {
  project = gcp_project
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# ------------------------
# Networking
# ------------------------
resource "google_compute_network" "vpc" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "ssh_allow" {
  name    = "${var.name}-allow-ssh"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
}

# ------------------------
# VM Instance
# ------------------------
resource "google_compute_instance" "vm" {
  name         = "${var.name}-vm"
  machine_type = var.machine_type
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = var.ubuntu_image
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = google_compute_network.vpc.id
    access_config {}
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    startup-script = <<-EOT
      #!/usr/bin/env bash
      set -euo pipefail

      # Create log dirs
      sudo mkdir -p /var/log/vm_state /var/log/bot_logger
      sudo chown -R root:root /var/log/vm_state /var/log/bot_logger
      sudo chmod 755 /var/log/vm_state /var/log/bot_logger
    EOT
  }

  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  labels = {
    role = "semaphore-target"
  }
}

# ------------------------
# Ansible Inventory Update
# ------------------------
resource "null_resource" "update_inventory" {
  triggers = {
    vm_ip = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
  }

  provisioner "local-exec" {
    command = <<EOT
      echo -e "[targets]\nvm ansible_host=${self.triggers.vm_ip} ansible_user=ubuntu\n\n[all:vars]\nansible_python_interpreter=/usr/bin/python3" > ../ansible/inventory.ini
      echo "ansible/inventory.ini updated with IP ${self.triggers.vm_ip}"
    EOT
  }
}

# ------------------------
# Outputs
# ------------------------
output "vm_external_ip" {
  description = "External IP of the VM"
  value       = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}

output "vm_name" {
  description = "VM instance name"
  value       = google_compute_instance.vm.name
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.vpc.name
}
