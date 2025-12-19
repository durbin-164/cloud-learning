output "instance_1_name" {
  description = "Name of instance 1"
  value       = google_compute_instance.tf-instance-1.name
}

output "instance_2_name" {
  description = "Name of instance 2"
  value       = google_compute_instance.tf-instance-2.name
}
