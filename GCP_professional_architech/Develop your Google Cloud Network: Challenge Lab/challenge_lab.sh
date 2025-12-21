#!/bin/bash

# Task 1: Create development VPC manually

# Create the VPC griffin-dev-vpc
gcloud compute networks create griffin-dev-vpc \
    --subnet-mode=custom

# Create first subnet: griffin-dev-wp
gcloud compute networks subnets create griffin-dev-wp \
    --network=griffin-dev-vpc \
    --region=us-east4 \
    --range=192.168.16.0/20

# Create second subnet: griffin-dev-mgmt
gcloud compute networks subnets create griffin-dev-mgmt \
    --network=griffin-dev-vpc \
    --region=us-east4 \
    --range=192.168.32.0/20

# Task 2: Create production VPC manually

# Create the VPC griffin-prod-vpc
gcloud compute networks create griffin-prod-vpc \
    --subnet-mode=custom

# Create first subnet: griffin-prod-wp
gcloud compute networks subnets create griffin-prod-wp \
    --network=griffin-prod-vpc \
    --region=us-east4 \
    --range=192.168.48.0/20

# Create second subnet: griffin-prod-mgmt
gcloud compute networks subnets create griffin-prod-mgmt \
    --network=griffin-prod-vpc \
    --region=us-east4 \
    --range=192.168.64.0/20

# Task 3: Create bastion host

# Create firewall rules to allow SSH to bastion
gcloud compute firewall-rules create allow-ssh-dev \
    --network=griffin-dev-vpc \
    --allow=tcp:22 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=ssh

gcloud compute firewall-rules create allow-ssh-prod \
    --network=griffin-prod-vpc \
    --allow=tcp:22 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=ssh

# Create bastion host with two network interfaces
gcloud compute instances create bastion \
    --zone=us-east4-b \
    --machine-type=e2-medium \
    --network-interface=subnet=griffin-dev-mgmt,no-address \
    --network-interface=subnet=griffin-prod-mgmt,no-address \
    --tags=ssh \
    --metadata=enable-oslogin=true

# Task 4: Create and configure Cloud SQL Instance

# Create MySQL Cloud SQL instance
gcloud sql instances create griffin-dev-db \
    --database-version=MYSQL_8_0 \
    --tier=db-n1-standard-1 \
    --region=us-east4 \
    --root-password=password123 \
    --availability-type=zonal

# Connect to the instance and run SQL commands
gcloud sql connect griffin-dev-db --user=root << EOF
CREATE DATABASE wordpress;
CREATE USER "wp_user"@"%" IDENTIFIED BY "stormwind_rules";
GRANT ALL PRIVILEGES ON wordpress.* TO "wp_user"@"%";
FLUSH PRIVILEGES;
exit
EOF

# Task 5: Create Kubernetes cluster

# Create a 2-node Kubernetes cluster
gcloud container clusters create griffin-dev \
    --num-nodes=2 \
    --machine-type=e2-standard-4 \
    --network=griffin-dev-vpc \
    --subnetwork=griffin-dev-wp \
    --zone=us-east4-b

# Task 6: Prepare the Kubernetes cluster

# Get cluster credentials
gcloud container clusters get-credentials griffin-dev --zone=us-east4-b

# Copy WordPress Kubernetes files from Cloud Storage
gsutil -m cp -r gs://spls/gsp321/wp-k8s .

# Navigate to the wp-k8s directory
cd wp-k8s

# Edit wp-env.yaml to set username and password
# Update the username to wp_user and password to stormwind_rules
sed -i "s/username_goes_here/wp_user/g" wp-env.yaml
sed -i "s/password_goes_here/stormwind_rules/g" wp-env.yaml

# Create the WordPress environment configuration
kubectl create -f wp-env.yaml

# Create service account key for Cloud SQL Proxy
gcloud iam service-accounts keys create key.json \
    --iam-account=cloud-sql-proxy@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com

# Create Kubernetes secret with the service account key
kubectl create secret generic cloudsql-instance-credentials \
    --from-file key.json

# Task 7: Create a WordPress deployment

# Get the Cloud SQL instance connection name
export SQL_CONNECTION=$(gcloud sql instances describe griffin-dev-db --format="value(connectionName)")

# Replace YOUR_SQL_INSTANCE with the actual instance connection name in wp-deployment.yaml
sed -i "s/YOUR_SQL_INSTANCE/${SQL_CONNECTION}/g" wp-deployment.yaml

# Create the WordPress deployment
kubectl create -f wp-deployment.yaml

# Create the WordPress service (Load Balancer)
kubectl create -f wp-service.yaml

# Get the external IP of the WordPress service (may take a few minutes)
echo "Waiting for external IP to be assigned..."
kubectl get service wordpress

# Task 8: Enable monitoring

# Wait for the external IP to be assigned
echo "Getting WordPress external IP..."
export WORDPRESS_IP=$(kubectl get service wordpress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Create uptime check for WordPress site
gcloud alpha monitoring uptime create wordpress-uptime-check \
    --resource-type=uptime-url \
    --resource-labels=host="${WORDPRESS_IP}"

echo "Uptime check created for WordPress site at IP: ${WORDPRESS_IP}"

# Task 9: Provide access for an additional engineer

# Grant editor role to the second user (replace with actual user email)
# Get the second user from the lab instructions
gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT \
    --member=user:student-00-bd29d14a1cff@qwiklabs.net \
    --role=roles/editor
