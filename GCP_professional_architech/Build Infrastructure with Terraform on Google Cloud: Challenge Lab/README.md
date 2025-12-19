# Build Infrastructure with Terraform on Google Cloud: Challenge Lab

## Project ID
`qwiklabs-gcp-04-76f782fb8310`

## Task 1: Create the Configuration Files ✅

All configuration files have been created with the proper structure:

```
.
├── main.tf
├── variables.tf
└── modules/
    ├── instances/
    │   ├── instances.tf
    │   ├── outputs.tf
    │   └── variables.tf
    └── storage/
        ├── storage.tf
        ├── outputs.tf
        └── variables.tf
```

### Step 1: Initialize Terraform

Run the following commands in Cloud Shell:

```bash
cd ~/
terraform init
```

## Task 2: Import Infrastructure

### Step 1: Get Instance Details

Before importing, you need to get the actual details of the existing instances. Run:

```bash
gcloud compute instances describe tf-instance-1 --zone=us-east4-b
gcloud compute instances describe tf-instance-2 --zone=us-east4-b
```

Note down:
- Machine type (e.g., `n1-standard-1`, `e2-medium`, etc.)
- Boot disk image (e.g., `debian-cloud/debian-11`, `ubuntu-os-cloud/ubuntu-2004-lts`, etc.)
- Instance ID (you'll need this for import)

### Step 2: Update instances.tf

Update the `modules/instances/instances.tf` file with the correct machine type and boot disk image based on what you found. The file is already structured, you just need to verify/update:

- `machine_type`: Replace with actual machine type
- `boot_disk.initialize_params.image`: Replace with actual image

### Step 3: Re-initialize Terraform

After adding the module reference to main.tf:

```bash
terraform init
```

### Step 4: Import the Instances

Get the instance IDs and import them:

```bash
# Get instance IDs
gcloud compute instances describe tf-instance-1 --zone=us-east4-b --format="get(id)"
gcloud compute instances describe tf-instance-2 --zone=us-east4-b --format="get(id)"

# Import instances (replace <INSTANCE_ID> with actual IDs)
terraform import module.instances.google_compute_instance.tf-instance-1 projects/qwiklabs-gcp-04-76f782fb8310/zones/us-east4-b/instances/tf-instance-1

terraform import module.instances.google_compute_instance.tf-instance-2 projects/qwiklabs-gcp-04-76f782fb8310/zones/us-east4-b/instances/tf-instance-2
```

### Step 5: Apply Changes

```bash
terraform plan
terraform apply
```

Type `yes` when prompted.

## Important Notes

1. The instances.tf file has minimal configuration as required by the lab
2. The `metadata_startup_script` and `allow_stopping_for_update` are already configured
3. After import, Terraform will update the instances in-place (this is expected for the lab)

## Quick Command Reference

```bash
# Navigate to the directory
cd "GCP_professional_architech/Build Infrastructure with Terraform on Google Cloud: Challenge Lab"

# Initialize Terraform
terraform init

# Check what instances exist
gcloud compute instances list

# Describe an instance to get details
gcloud compute instances describe tf-instance-1 --zone=us-east4-b

# Import instances
terraform import module.instances.google_compute_instance.tf-instance-1 projects/qwiklabs-gcp-04-76f782fb8310/zones/us-east4-b/instances/tf-instance-1
terraform import module.instances.google_compute_instance.tf-instance-2 projects/qwiklabs-gcp-04-76f782fb8310/zones/us-east4-b/instances/tf-instance-2

# Plan and apply
terraform plan
terraform apply
```

## Verification

After completing the tasks, verify:
- `terraform init` completes successfully
- Both instances are imported without errors
- `terraform plan` shows minimal changes (in-place updates)
- `terraform apply` completes successfully
