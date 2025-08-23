variable "name"             { type = string  default = "semproj" }
variable "gcp_project"      { type = string }
variable "gcp_region"       { type = string  default = "us-central1" }
variable "gcp_zone"         { type = string  default = "us-central1-c" }
variable "machine_type"     { type = string  default = "e2-medium" }
variable "ubuntu_image"     { type = string  default = "ubuntu-os-cloud/ubuntu-2404-lts" }
variable "ssh_public_key"   { type = string }
variable "ssh_source_ranges"{ type = list(string) default = ["0.0.0.0/0"] }
variable "elasticsearch_host" {
  description = "Elasticsearch URL reachable by the VM (e.g., http://localhost:9200)"
  type        = string
}
