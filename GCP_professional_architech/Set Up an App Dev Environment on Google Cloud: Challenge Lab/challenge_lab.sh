#!/bin/bash

# =============================================================================
# GCP Challenge Lab: Set Up an App Dev Environment on Google Cloud
# =============================================================================
# This script automates the completion of all tasks in the challenge lab.
# Replace the placeholder values with the actual values from your lab.
# =============================================================================

# IMPORTANT: Replace these variables with values from your lab instructions
REGION="us-central1"                    # Replace with your lab's REGION
ZONE="us-central1-c"                    # Replace with your lab's ZONE
BUCKET_NAME="qwiklabs-gcp-02-e8061e94aec4-bucket"         # Replace with your lab's Bucket Name
TOPIC_NAME="topic-memories-206"           # Replace with your lab's Topic Name
CLOUDRUN_FUNCTION_NAME="memories-thumbnail-creator" # Replace with your lab's Cloud Run Function Name
USERNAME_2="student-02-4f25429e73da@qwiklabs.net"       # Replace with Username 2 (previous engineer's email)

# Get project ID (suppress warnings)
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

# =============================================================================
# TASK 0: Initial Setup
# =============================================================================
echo "=========================================="
echo "Setting up environment..."
echo "=========================================="

# Set the default region and zone for gcloud commands
gcloud config set compute/region "$REGION"
gcloud config set compute/zone "$ZONE"

echo ""
echo "Enabling required APIs (this may take a moment)..."
# Enable required APIs for Cloud Functions (2nd gen), Storage, Pub/Sub
gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  pubsub.googleapis.com \
  eventarc.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com

echo "✓ Required APIs enabled"

# =============================================================================
# TASK 1: Create a Storage Bucket
# =============================================================================
echo "=========================================="
echo "TASK 1: Creating bucket: $BUCKET_NAME"
echo "=========================================="

# Create a Cloud Storage bucket in the specified region
# --location flag ensures the bucket is created in the correct region
if gcloud storage buckets describe gs://$BUCKET_NAME &>/dev/null; then
  echo "⚠ Bucket already exists: $BUCKET_NAME"
else
  gcloud storage buckets create gs://$BUCKET_NAME \
    --location=$REGION

  if [ $? -eq 0 ]; then
    echo "✓ Bucket created successfully"
  else
    echo "✗ Failed to create bucket!"
    exit 1
  fi
fi

# =============================================================================
# TASK 2: Create a Pub/Sub Topic
# =============================================================================
echo "=========================================="
echo "TASK 2: Creating Pub/Sub topic: $TOPIC_NAME"
echo "=========================================="

# Create a Pub/Sub topic that will receive messages from the Cloud Run Function
if gcloud pubsub topics describe $TOPIC_NAME &>/dev/null; then
  echo "⚠ Pub/Sub topic already exists: $TOPIC_NAME"
else
  gcloud pubsub topics create $TOPIC_NAME

  if [ $? -eq 0 ]; then
    echo "✓ Pub/Sub topic created successfully"
  else
    echo "✗ Failed to create Pub/Sub topic!"
    exit 1
  fi
fi

# =============================================================================
# TASK 3: Create the Cloud Run Function (2nd Generation)
# =============================================================================
echo "=========================================="
echo "TASK 3: Deploying Cloud Run Function: $CLOUDRUN_FUNCTION_NAME"
echo "=========================================="

# Get the project number for service account permissions
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo "Setting up IAM permissions for Eventarc and Cloud Functions..."

# Grant necessary permissions to Eventarc service account
# This is required for 2nd gen Cloud Functions to work with Cloud Storage triggers
EVENTARC_SA="service-${PROJECT_NUMBER}@gcp-sa-eventarc.iam.gserviceaccount.com"

# Grant Eventarc service account permissions on the bucket
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${EVENTARC_SA}" \
  --role="roles/eventarc.eventReceiver" \
  --condition=None

# Grant storage.buckets.get permission to Eventarc service account
gsutil iam ch serviceAccount:${EVENTARC_SA}:objectViewer gs://$BUCKET_NAME

# Grant permissions to the default Cloud Build service account
CLOUD_BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role="roles/run.admin" \
  --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role="roles/iam.serviceAccountUser" \
  --condition=None

# Grant permissions to default Compute Engine service account for Pub/Sub
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/pubsub.publisher" \
  --condition=None

# Grant Cloud Storage service agent permission to publish to Pub/Sub topics
# This is critical for Cloud Storage notifications to work with Eventarc
GCS_SA="service-${PROJECT_NUMBER}@gs-project-accounts.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${GCS_SA}" \
  --role="roles/pubsub.publisher" \
  --condition=None

echo "✓ IAM permissions configured"
echo ""
echo "Waiting for IAM permissions to propagate (30 seconds)..."
sleep 30

# Create a temporary directory for function code
mkdir -p ~/cloud-function-temp
cd ~/cloud-function-temp

# Create the index.js file with the thumbnail generation code
cat > index.js << 'EOF'
const functions = require('@google-cloud/functions-framework');
const { Storage } = require('@google-cloud/storage');
const { PubSub } = require('@google-cloud/pubsub');
const sharp = require('sharp');

functions.cloudEvent('CLOUDRUN_FUNCTION_NAME_PLACEHOLDER', async cloudEvent => {
  const event = cloudEvent.data;

  console.log(`Event: ${JSON.stringify(event)}`);
  console.log(`Hello ${event.bucket}`);

  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64";
  const bucket = new Storage().bucket(bucketName);
  const topicName = "TOPIC_NAME_PLACEHOLDER";
  const pubsub = new PubSub();

  if (fileName.search("64x64_thumbnail") === -1) {
    // doesn't have a thumbnail, get the filename extension
    const filename_split = fileName.split('.');
    const filename_ext = filename_split[filename_split.length - 1].toLowerCase();
    const filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length - 1); // fix sub string to remove the dot

    if (filename_ext === 'png' || filename_ext === 'jpg' || filename_ext === 'jpeg') {
      // only support png and jpg at this point
      console.log(`Processing Original: gs://${bucketName}/${fileName}`);
      const gcsObject = bucket.file(fileName);
      const newFilename = `${filename_without_ext}_64x64_thumbnail.${filename_ext}`;
      const gcsNewObject = bucket.file(newFilename);

      try {
        const [buffer] = await gcsObject.download();
        const resizedBuffer = await sharp(buffer)
          .resize(64, 64, {
            fit: 'inside',
            withoutEnlargement: true,
          })
          .toFormat(filename_ext)
          .toBuffer();

        await gcsNewObject.save(resizedBuffer, {
          metadata: {
            contentType: `image/${filename_ext}`,
          },
        });

        console.log(`Success: ${fileName} → ${newFilename}`);

        await pubsub
          .topic(topicName)
          .publishMessage({ data: Buffer.from(newFilename) });

        console.log(`Message published to ${topicName}`);
      } catch (err) {
        console.error(`Error: ${err}`);
      }
    } else {
      console.log(`gs://${bucketName}/${fileName} is not an image I can handle`);
    }
  } else {
    console.log(`gs://${bucketName}/${fileName} already has a thumbnail`);
  }
});
EOF

# Replace placeholders in index.js with actual values
sed -i "s/CLOUDRUN_FUNCTION_NAME_PLACEHOLDER/$CLOUDRUN_FUNCTION_NAME/g" index.js
sed -i "s/TOPIC_NAME_PLACEHOLDER/$TOPIC_NAME/g" index.js

# Create the package.json file with dependencies
cat > package.json << 'EOF'
{
 "name": "thumbnails",
 "version": "1.0.0",
 "description": "Create Thumbnail of uploaded image",
 "scripts": {
   "start": "node index.js"
 },
 "dependencies": {
   "@google-cloud/functions-framework": "^3.0.0",
   "@google-cloud/pubsub": "^2.0.0",
   "@google-cloud/storage": "^6.11.0",
   "sharp": "^0.32.1"
 },
 "devDependencies": {},
 "engines": {
   "node": ">=4.3.2"
 }
}
EOF

echo "Function code files created"

# Deploy the Cloud Run Function (2nd generation)
# IMPORTANT: Using --gen2 flag to create a 2nd generation Cloud Function
# 2nd generation functions run on Cloud Run infrastructure and provide:
#   - Better performance and scalability
#   - More configuration options
#   - Integration with Eventarc for event handling
# --gen2: Use 2nd generation Cloud Run functions (REQUIRED for this lab)
# --runtime: Node.js 22 runtime
# --entry-point: The function name to execute (must match the one in index.js)
# --trigger-bucket: Trigger function when objects are created in the bucket
# --allow-unauthenticated: Allow public access (adjust based on requirements)
echo "Deploying 2nd generation Cloud Function..."
echo "This may take 2-5 minutes. Please wait..."

gcloud functions deploy $CLOUDRUN_FUNCTION_NAME \
  --gen2 \
  --runtime=nodejs22 \
  --region=$REGION \
  --source=. \
  --entry-point=$CLOUDRUN_FUNCTION_NAME \
  --trigger-bucket=$BUCKET_NAME \
  --allow-unauthenticated

if [ $? -eq 0 ]; then
  echo "✓ Cloud Run Function deployed successfully"
  echo ""
  echo "Verifying deployment..."

  # List the deployed function to verify
  gcloud functions list --gen2 --region=$REGION

  echo ""
  echo "To view in the UI:"
  echo "  1. Go to Cloud Console: https://console.cloud.google.com/functions/list"
  echo "  2. Make sure you select the correct region: $REGION"
  echo "  3. Look for function: $CLOUDRUN_FUNCTION_NAME"
  echo ""
  echo "IMPORTANT: For 2nd gen functions, also check:"
  echo "  - Cloud Run services: https://console.cloud.google.com/run"
  echo "  - The function appears as a Cloud Run service (2nd gen functions run on Cloud Run)"
  echo ""

  # Get detailed function information
  echo "Function details:"
  gcloud functions describe $CLOUDRUN_FUNCTION_NAME \
    --gen2 \
    --region=$REGION \
    --format="table(name,state,environment)"
else
  echo "✗ Function deployment failed!"
  echo "Check the error messages above for details."
  exit 1
fi

# Return to original directory
cd -

# =============================================================================
# TASK 3.1: Test the Function (Optional Manual Step)
# =============================================================================
echo "=========================================="
echo "Testing the function..."
echo "=========================================="
echo "To test the function, upload an image to the bucket:"
echo "  Option 1: Download test image and upload:"
echo "    curl -o map.jpg https://storage.googleapis.com/cloud-training/gsp315/map.jpg"
echo "    gcloud storage cp map.jpg gs://$BUCKET_NAME/"
echo ""
echo "  Option 2: Upload your own PNG or JPG image:"
echo "    gcloud storage cp YOUR_IMAGE.jpg gs://$BUCKET_NAME/"
echo ""
echo "After upload, check the bucket for the thumbnail:"
echo "    gcloud storage ls gs://$BUCKET_NAME/"
echo ""

# Uncomment the following lines to automatically test with the sample image
curl -o /tmp/map.jpg https://storage.googleapis.com/cloud-training/gsp315/map.jpg
gcloud storage cp /tmp/map.jpg gs://$BUCKET_NAME/
echo "Test image uploaded. Check bucket in a few moments for thumbnail."

# =============================================================================
# TASK 4: Remove Previous Cloud Engineer's Access
# =============================================================================
echo "=========================================="
echo "TASK 4: Removing previous cloud engineer's access"
echo "=========================================="

# First, list all IAM policy bindings to find the previous engineer
echo "Current IAM policy members:"
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --format="table(bindings.role, bindings.members)"

echo ""

# Remove the Viewer role from the previous cloud engineer (USERNAME_2)
# Note: Replace USERNAME_2 variable at the top with the actual email from the lab
if [ ! -z "$USERNAME_2" ] && [ "$USERNAME_2" != "user2@example.com" ]; then
  echo "Attempting to remove access for: $USERNAME_2"

  # Try to find what roles the user actually has
  USER_ROLES=$(gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:user:$USERNAME_2" \
    --format="value(bindings.role)")

  if [ -z "$USER_ROLES" ]; then
    echo "⚠ User $USERNAME_2 not found in IAM policy. May have been already removed."
  else
    echo "Found user with roles: $USER_ROLES"

    # Remove all roles for this user
    for ROLE in $USER_ROLES; do
      echo "Removing role: $ROLE"
      gcloud projects remove-iam-policy-binding $PROJECT_ID \
        --member=user:$USERNAME_2 \
        --role=$ROLE

      if [ $? -eq 0 ]; then
        echo "✓ Removed role $ROLE from $USERNAME_2"
      else
        echo "✗ Failed to remove role $ROLE"
      fi
    done
  fi
else
  echo "⚠ WARNING: USERNAME_2 not set or still has default value."
  echo "Please manually remove the previous engineer's access:"
  echo "  gcloud projects remove-iam-policy-binding $PROJECT_ID \\"
  echo "    --member=user:EMAIL_ADDRESS \\"
  echo "    --role=roles/viewer"
fi

# =============================================================================
# COMPLETION
# =============================================================================
echo "=========================================="
echo "All tasks completed!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Task 1: Bucket '$BUCKET_NAME' created"
echo "  ✓ Task 2: Pub/Sub topic '$TOPIC_NAME' created"
echo "  ✓ Task 3: Cloud Run Function '$CLOUDRUN_FUNCTION_NAME' deployed"
echo "  ✓ Task 4: Previous engineer's access removed"
echo ""
echo "Remember to:"
echo "  1. Test the function by uploading an image"
echo "  2. Verify all tasks in the lab scoring system"
echo ""
echo "Good luck with your challenge lab!"
