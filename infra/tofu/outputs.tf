output "vm_ip" {
  description = "Public IP of the Ubuntu VM"
  value       = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}
