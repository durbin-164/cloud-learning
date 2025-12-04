#!/bin/bash

# ============================================
# GCP Load Balancing Challenge Lab Script
# ============================================
# This script automates all 3 tasks for the GCP Load Balancing Challenge Lab
#
# USAGE:
#   1. Update REGION and ZONE variables below with your lab values
#   2. Make the script executable: chmod +x challenge_lab.sh
#   3. Run the script: ./challenge_lab.sh
#
# The script will:
#   - Create 3 web server VM instances (web1, web2, web3)
#   - Configure a network load balancer
#   - Create an HTTP load balancer with managed instance group
# ============================================

# ============================================
# CONFIGURE THESE VARIABLES BEFORE RUNNING
# ============================================
# Replace with your actual GCP region (e.g., us-central1, us-east1, europe-west1)
REGION="us-west1"

# Replace with your actual GCP zone (e.g., us-central1-a, us-east1-b, europe-west1-b)
ZONE="us-west1-c"

# ============================================
# DO NOT EDIT BELOW THIS LINE
# ============================================

# Set the default compute region for all subsequent gcloud commands
gcloud config set compute/region $REGION

# Set the default compute zone for all subsequent gcloud commands
gcloud config set compute/zone $ZONE


# ============================================
# TASK 1: Create multiple web server instances
# ============================================

# Create first VM instance (web1) with Apache webserver startup script
gcloud compute instances create web1 \
  --zone=$ZONE \
  --tags=network-lb-tag \
  --machine-type=e2-small \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install apache2 -y
    service apache2 restart
    echo "<h3>Web Server: web1</h3>" | tee /var/www/html/index.html'

# Create second VM instance (web2) with Apache webserver startup script
gcloud compute instances create web2 \
  --zone=$ZONE \
  --tags=network-lb-tag \
  --machine-type=e2-small \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install apache2 -y
    service apache2 restart
    echo "<h3>Web Server: web2</h3>" | tee /var/www/html/index.html'

# Create third VM instance (web3) with Apache webserver startup script
gcloud compute instances create web3 \
  --zone=$ZONE \
  --tags=network-lb-tag \
  --machine-type=e2-small \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install apache2 -y
    service apache2 restart
    echo "<h3>Web Server: web3</h3>" | tee /var/www/html/index.html'

# Create firewall rule to allow HTTP traffic (port 80) to instances with network-lb-tag
gcloud compute firewall-rules create www-firewall-network-lb \
  --target-tags network-lb-tag --allow tcp:80


# ============================================
# TASK 2: Configure the load balancing service
# ============================================

# Reserve a static external IP address for the network load balancer
gcloud compute addresses create network-lb-ip-1 \
  --region $REGION

# Create a health check for the target pool (legacy HTTP health check)
gcloud compute http-health-checks create basic-check

# Create a target pool with the health check for network load balancing
gcloud compute target-pools create www-pool \
  --region $REGION \
  --http-health-check basic-check

# Add all three VM instances to the target pool
gcloud compute target-pools add-instances www-pool \
  --instances web1,web2,web3 \
  --zone $ZONE

# Create a forwarding rule to distribute traffic to the target pool on port 80
gcloud compute forwarding-rules create www-rule \
  --region $REGION \
  --ports 80 \
  --address network-lb-ip-1 \
  --target-pool www-pool


# ============================================
# TASK 3: Create an HTTP load balancer
# ============================================

# Create an instance template for managed instance group with health check tag
gcloud compute instance-templates create lb-backend-template \
  --region=$REGION \
  --network=default \
  --subnet=default \
  --tags=allow-health-check \
  --machine-type=e2-medium \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install apache2 -y
    a2ensite default-ssl
    a2enmod ssl
    vm_hostname="$(curl -H "Metadata-Flavor:Google" \
    http://169.254.169.254/computeMetadata/v1/instance/name)"
    echo "Page served from: $vm_hostname" | \
    tee /var/www/html/index.html
    systemctl restart apache2'

# Create a managed instance group with 2 instances using the template
gcloud compute instance-groups managed create lb-backend-group \
  --template=lb-backend-template --size=2 --zone=$ZONE

# Create firewall rule to allow health check traffic from Google Cloud health checkers
gcloud compute firewall-rules create fw-allow-health-check \
  --network=default \
  --action=allow \
  --direction=ingress \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --target-tags=allow-health-check \
  --rules=tcp:80

# Reserve a global static external IP address for the HTTP load balancer
gcloud compute addresses create lb-ipv4-1 \
  --ip-version=IPV4 \
  --global

# Display the reserved IP address for reference
gcloud compute addresses describe lb-ipv4-1 \
  --format="get(address)" \
  --global

# Create an HTTP health check for the backend service
gcloud compute health-checks create http http-basic-check \
  --port 80

# Create a global backend service for the HTTP load balancer
gcloud compute backend-services create web-backend-service \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=http-basic-check \
  --global

# Add the managed instance group as a backend to the backend service
gcloud compute backend-services add-backend web-backend-service \
  --instance-group=lb-backend-group \
  --instance-group-zone=$ZONE \
  --global

# Create a URL map to route incoming requests to the backend service
gcloud compute url-maps create web-map-http \
  --default-service web-backend-service

# Create a target HTTP proxy to route requests to the URL map
gcloud compute target-http-proxies create http-lb-proxy \
  --url-map web-map-http

# Create a global forwarding rule to route traffic to the HTTP proxy on port 80
gcloud compute forwarding-rules create http-content-rule \
  --address=lb-ipv4-1\
  --global \
  --target-http-proxy=http-lb-proxy \
  --ports=80
