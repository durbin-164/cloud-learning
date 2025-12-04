# GCP Load Balancing Challenge Lab - Quick Start Guide

## Overview
This script automates all tasks for the "Implementing Cloud Load Balancing for Compute Engine" challenge lab.

## Quick Start

### Step 1: Update Variables
Edit [challenge_lab.sh](challenge_lab.sh) and update these two variables with your lab's region and zone:

```bash
REGION="us-central1"        # Change to your lab region
ZONE="us-central1-a"        # Change to your lab zone
```

### Step 2: Make Script Executable
```bash
chmod +x challenge_lab.sh
```

### Step 3: Run the Script
```bash
./challenge_lab.sh
```

## What the Script Does

### Task 1: Create Multiple Web Server Instances
- Creates 3 VM instances: `web1`, `web2`, `web3`
- Installs Apache web server on each
- Creates firewall rule `www-firewall-network-lb`

### Task 2: Configure Network Load Balancer
- Creates static IP: `network-lb-ip-1`
- Creates target pool: `www-pool`
- Adds all 3 instances to the pool
- Creates forwarding rule for port 80

### Task 3: Create HTTP Load Balancer
- Creates instance template: `lb-backend-template`
- Creates managed instance group: `lb-backend-group` (2 instances)
- Creates health check: `http-basic-check`
- Creates backend service: `web-backend-service`
- Creates URL map: `web-map-http`
- Creates HTTP proxy: `http-lb-proxy`
- Creates global forwarding rule with IP: `lb-ipv4-1`

## Verification

After running the script, verify the resources in the GCP Console:
1. **Compute Engine > VM Instances**: Should see web1, web2, web3, and 2 lb-backend-group instances
2. **Network Services > Load Balancing**: Should see both load balancers
3. **VPC Network > Firewall**: Should see firewall rules

## Troubleshooting

If you encounter errors:
- Ensure you're using the correct region and zone from your lab instructions
- Check that you have proper permissions in the GCP project
- Some resources may take a few minutes to fully provision

## Testing the Load Balancers

### Test Network Load Balancer:
```bash
# Get the IP address
gcloud compute forwarding-rules describe www-rule --region=$REGION --format="get(IPAddress)"

# Test with curl
curl http://[IP_ADDRESS]
```

### Test HTTP Load Balancer:
```bash
# Get the IP address
gcloud compute addresses describe lb-ipv4-1 --global --format="get(address)"

# Open in browser (may take 3-5 minutes to be fully ready)
# http://[IP_ADDRESS]
```
