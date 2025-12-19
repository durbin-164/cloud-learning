variable "region" {
  description = "The region for GCP resources"
  type        = string
  default     = "us-east4"
}

variable "zone" {
  description = "The zone for GCP resources"
  type        = string
  default     = "us-east4-b"
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "qwiklabs-gcp-04-76f782fb8310"
}
