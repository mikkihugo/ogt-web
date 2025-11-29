# Get Tigris S3 Credentials

Your Tigris bucket `orgasmtoy-media` has been created! ✅

## Option 1: Open Tigris Dashboard (Easiest)

Run this command to open the dashboard in your browser:

```bash
direnv exec . flyctl storage dashboard orgasmtoy-media
```

Then:
1. Navigate to **"Access Keys"** in the left sidebar
2. Click **"Create Access Key"**
3. Give it a name like "ogt-web-production"
4. Copy the **Access Key ID** and **Secret Access Key**

⚠️ **Important**: Save the secret access key immediately - you won't see it again!

## Option 2: Create from Fly App Context

If you have a Fly.io app deployed:

```bash
# Navigate to your project
cd /home/mhugo/code/ogt-web

# Create storage and auto-set secrets
flyctl storage create --app ogt-web

# This will automatically set these secrets on your app:
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
# - AWS_ENDPOINT_URL_S3
# - AWS_REGION
# - BUCKET_NAME
```

## Credentials to Add to .env.encrypted

Once you have your credentials, add these lines to `.env.encrypted`:

```bash
# Tigris S3 Storage
AWS_ACCESS_KEY_ID=tid_XXXXXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=tsec_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
S3_BUCKET=orgasmtoy-media
S3_REGION=auto
S3_ENDPOINT=https://fly.storage.tigris.dev
```

## Endpoints

- **Within Fly.io**: `https://fly.storage.tigris.dev`
- **Outside Fly.io**: `https://fly.storage.tigris.dev` (same, globally accessible)

## Testing Access

After adding credentials to `.env.encrypted`:

```bash
# Unlock git-crypt first
git-crypt unlock

# Test with AWS CLI
export $(grep -v '^#' .env.encrypted | xargs)
aws s3 ls s3://orgasmtoy-media --endpoint-url $S3_ENDPOINT

# Or use the sync script
nix run .#sync-media  # Requires pub/media directory with files
```

## Next Steps

1. ✅ Get credentials from dashboard
2. ✅ Add to `.env.encrypted`
3. ✅ Initialize git-crypt: `git-crypt init`
4. ✅ Encrypt: `git-crypt lock`
5. ✅ Commit: `git add .env.encrypted && git commit -m "Add encrypted Tigris credentials"`

