# Storage bucket resources will be added here as needed
resource "google_storage_bucket" "tf-bucket" {
  name                        = "tf-bucket-270816"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = true
}