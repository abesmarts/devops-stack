terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.40.0"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
  zone    = var.gcp_zone
}

resource "google_compute_network" "vpc" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "ssh_allow" {
  name    = "${var.name}-allow-ssh"
  network = google_compute_network.vpc.name
  allow { protocol = "tcp" ports = ["22"] }
  source_ranges = var.ssh_source_ranges
}

resource "google_compute_instance" "vm" {
  name         = "${var.name}-vm"
  machine_type = var.machine_type
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = var.ubuntu_image         # ubuntu-os-cloud/ubuntu-2404-lts
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
      sudo mkdir -p /var/log/vm_state /var/log/bot_logger
      sudo chown -R root:root /var/log/vm_state /var/log/bot_logger
      sudo chmod 755 /var/log/vm_state /var/log/bot_logger

      sudo apt-get update -y
      sudo apt-get install -y curl gnupg apt-transport-https

      # Install Filebeat 9.x
      curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch \
        | sudo gpg --dearmor -o /usr/share/keyrings/elastic-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/elastic-archive-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" \
        | sudo tee /etc/apt/sources.list.d/elastic-9.x.list
      sudo apt-get update -y
      sudo apt-get install -y filebeat

      sudo bash -c 'cat > /etc/filebeat/filebeat.yml' <<FBYML
filebeat.inputs:
  - type: filestream
    id: vm-state-json
    enabled: true
    paths: ["/var/log/vm_state/*.json"]
    parsers: [{ndjson: {target: "", add_error_key: true, overwrite_keys: true}}]
    index: "vm_state"

  - type: filestream
    id: bot-logger-json
    enabled: true
    paths: ["/var/log/bot_logger/*.json"]
    parsers: [{ndjson: {target: "", add_error_key: true, overwrite_keys: true}}]
    index: "bot_logger"

processors:
  - add_host_metadata: ~
  - add_process_metadata: {match_pids: ["process.pid","process.ppid"], ignore_missing: true}

output.elasticsearch:
  hosts: ["${var.elasticsearch_host}"]
  protocol: "http"
  index: "filebeat-%{[agent.version]}-%{+yyyy.MM.dd}"

setup.template.enabled: false
logging.metrics.enabled: false
FBYML

      sudo systemctl enable filebeat
      sudo systemctl restart filebeat
    EOT
  }

  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  labels = { role = "semaphore-target" }
}

resource "null_resource" "update_inventory" {
  triggers = {
    vm_ip = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
  }

  provisioner "local-exec" {
    command = <<EOT
      echo -e "[targets]\nvm ansible_host=${self.triggers.vm_ip} ansible_user=ubuntu\n\n\[all:vars]\nansible_python_interpreter=/usr/bin/python3" > ../ansible/inventory.ini
      echo "ansible/inventory.ini updated with IP ${self.triggers.vm_ip}"
    EOT

  }
}