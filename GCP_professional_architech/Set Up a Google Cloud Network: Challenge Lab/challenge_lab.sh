#!/bin/bash

# Challenge Lab: Set Up a Google Cloud Network
# This script creates a VPC network with subnets, firewall rules, and VMs

# Task 1: Create VPC network with two subnets
echo "Creating VPC network vpc-network-3e63..."
gcloud compute networks create vpc-network-3e63 \
    --subnet-mode=custom \
    --bgp-routing-mode=regional

echo "Creating subnet-a-3l9q in us-east4..."
gcloud compute networks subnets create subnet-a-3l9q \
    --network=vpc-network-3e63 \
    --region=us-east4 \
    --range=10.10.10.0/24 \
    --stack-type=IPV4_ONLY

echo "Creating subnet-b-q03o in europe-west4..."
gcloud compute networks subnets create subnet-b-q03o \
    --network=vpc-network-3e63 \
    --region=europe-west4 \
    --range=10.10.20.0/24 \
    --stack-type=IPV4_ONLY

# Task 2: Add firewall rules
echo "Creating firewall rule saky-firewall-ssh..."
gcloud compute firewall-rules create saky-firewall-ssh \
    --network=vpc-network-3e63 \
    --priority=1000 \
    --direction=INGRESS \
    --action=ALLOW \
    --target-tags=all \
    --source-ranges=0.0.0.0/0 \
    --rules=tcp:22

echo "Creating firewall rule dvsx-firewall-rdp..."
gcloud compute firewall-rules create dvsx-firewall-rdp \
    --network=vpc-network-3e63 \
    --priority=65535 \
    --direction=INGRESS \
    --action=ALLOW \
    --target-tags=all \
    --source-ranges=0.0.0.0/0 \
    --rules=tcp:3389

echo "Creating firewall rule xdki-firewall-icmp..."
gcloud compute firewall-rules create xdki-firewall-icmp \
    --network=vpc-network-3e63 \
    --priority=1000 \
    --direction=INGRESS \
    --action=ALLOW \
    --target-tags=all \
    --source-ranges=10.10.10.0/24,10.10.20.0/24 \
    --rules=icmp

# Task 3: Add VMs to the network
echo "Creating VM us-test-01 in subnet-a-3l9q..."
gcloud compute instances create us-test-01 \
    --zone=us-east4-b \
    --machine-type=e2-medium \
    --subnet=subnet-a-3l9q \
    --network-tier=PREMIUM \
    --maintenance-policy=MIGRATE \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-balanced \
    --boot-disk-device-name=us-test-01

echo "Creating VM us-test-02 in subnet-b-q03o..."
gcloud compute instances create us-test-02 \
    --zone=europe-west4-b \
    --machine-type=e2-medium \
    --subnet=subnet-b-q03o \
    --network-tier=PREMIUM \
    --maintenance-policy=MIGRATE \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-balanced \
    --boot-disk-device-name=us-test-02

echo "Setup complete!"
echo ""
echo "To test connectivity:"
echo "1. SSH into us-test-01:"
echo "   gcloud compute ssh us-test-01 --zone=us-east4-b"
echo ""
echo "2. Get us-test-02 internal IP:"
echo "   gcloud compute instances describe us-test-02 --zone=europe-west4-b --format='get(networkInterfaces[0].networkIP)'"
echo ""
echo "3. From us-test-01 SSH session, ping us-test-02 using its internal IP:"
echo "   ping -c 3 <us-test-02-internal-ip>"
echo ""
echo "4. Test latency using hostname:"
echo "   ping -c 3 us-test-02.europe-west4-b"
