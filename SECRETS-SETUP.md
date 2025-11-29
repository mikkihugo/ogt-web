# Secrets Setup Guide for OGT-Web

This guide walks you through setting up git-crypt encrypted secrets for orgasmtoy.com.

## Prerequisites

All tools are available in the Nix devshell:

```bash
# Enter the devshell
direnv allow  # or: nix develop --accept-flake-config
```

You should now have: `git-crypt`, `gh` (GitHub CLI), `flyctl`

## Step 1: Initialize git-crypt

```bash
cd /home/mhugo/code/ogt-web

# Initialize git-crypt (generates encryption key)
git-crypt init

# Verify .gitattributes is configured
cat .gitattributes
# Should show:
# secrets/** filter=git-crypt
# .env.encrypted filter=git-crypt
# ../.keys/* filter=git-crypt
```

## Step 2: Fill in Your Secrets

Edit `.env.encrypted` and replace all `REPLACE_WITH_*` placeholders:

```bash
# File is currently unencrypted
nano .env.encrypted  # or vim, code, etc.
```

### Required Secrets:

1. **Magento Composer Credentials**
   - Get from: https://marketplace.magento.com/customer/accessKeys/
   - `COMPOSER_MAGENTO_USERNAME` = Your public key
   - `COMPOSER_MAGENTO_PASSWORD` = Your private key

2. **Stripe API Keys**
   - Get from: https://dashboard.stripe.com/apikeys
   - Use **live keys** for production: `pk_live_...` and `sk_live_...`
   - Use **test keys** for development: `pk_test_...` and `sk_test_...`

3. **Klarna Credentials**
   - Get from: https://portal.klarna.com/
   - `KLARNA_MERCHANT_ID`
   - `KLARNA_SHARED_SECRET`

4. **S3 Media Storage**
   - For Fly.io Tigris:
     ```bash
     flyctl storage create  # Create Tigris bucket
     ```
   - Or use AWS S3 credentials

5. **SMTP/Email**
   - SendGrid: https://sendgrid.com/
   - AWS SES: https://aws.amazon.com/ses/
   - Or any SMTP provider

6. **Strong Passwords**
   - Generate with: `openssl rand -base64 32`
   - Set for: DB_PASSWORD, MYSQL_ROOT_PASSWORD, ADMIN_PASSWORD

## Step 3: Export git-crypt Key

```bash
# Create key directory (one level up, outside repo)
mkdir -p ../.keys

# Export the git-crypt key
git-crypt export-key ../.keys/ogt-web.git-crypt.key

# Secure the key
chmod 600 ../.keys/ogt-web.git-crypt.key

# Verify it exists
ls -la ../.keys/ogt-web.git-crypt.key
```

## Step 4: Lock (Encrypt) the Repository

```bash
# This encrypts .env.encrypted in place
git-crypt lock

# Verify encryption (should show binary data)
file .env.encrypted
# Should output: .env.encrypted: data

# Check git-crypt status
git-crypt status
# Should show: encrypted: .env.encrypted

# Commit the encrypted file
git add .env.encrypted
git commit -m "Add encrypted production secrets"
```

## Step 5: Backup git-crypt Key to Private Gist

```bash
# Authenticate with GitHub CLI (if not already)
gh auth login

# Backup key to private Gist
./gitcrypt-gist.sh backup

# Save the Gist URL/ID that's printed
# Example output: https://gist.github.com/username/abc123def456

# Optional: Save Gist ID to encrypted env
git-crypt unlock
echo "GITCRYPT_GIST_ID=abc123def456" >> .env.encrypted
git-crypt lock
git add .env.encrypted
git commit -m "Save git-crypt Gist ID"
```

## Step 6: Sync Secrets to Fly.io

```bash
# Authenticate with Fly.io
flyctl auth login

# Unlock to read secrets
git-crypt unlock

# Sync all secrets to Fly.io
./secrets-sync.sh fly .env.encrypted

# Lock again
git-crypt lock

# Verify secrets are set
flyctl secrets list
```

## Step 7: (Optional) Sync to GitHub Actions

If you need secrets in CI/CD:

```bash
# Unlock
git-crypt unlock

# Sync to GitHub Actions secrets
./secrets-sync.sh gh .env.encrypted

# Lock
git-crypt lock

# Verify in GitHub: Settings → Secrets and variables → Actions
```

## Daily Usage

### Editing Secrets

```bash
# Unlock
git-crypt unlock

# Edit
nano .env.encrypted

# Lock and commit
git-crypt lock
git add .env.encrypted
git commit -m "Update secrets"
git push
```

### On a New Machine

```bash
# Clone repo
git clone https://github.com/yourusername/ogt-web
cd ogt-web

# Enter devshell
nix develop --accept-flake-config

# Retrieve git-crypt key from Gist
./gitcrypt-gist.sh retrieve YOUR_GIST_ID

# Unlock repository
git-crypt unlock

# Verify secrets are readable
head .env.encrypted
```

### Revoking Access

If you need to rotate the encryption key:

```bash
# 1. Unlock current repo
git-crypt unlock

# 2. Save decrypted secrets temporarily
cp .env.encrypted .env.decrypted

# 3. Remove git-crypt
rm -rf .git-crypt
git-crypt init  # Creates new key

# 4. Re-encrypt with new key
git-crypt lock

# 5. Export new key
git-crypt export-key ../.keys/ogt-web.git-crypt.key

# 6. Backup new key
./gitcrypt-gist.sh backup

# 7. Delete old Gist, update GITCRYPT_GIST_ID
```

## Security Best Practices

1. ✅ **Never** commit `.env.encrypted` unencrypted
2. ✅ **Always** verify `git-crypt status` before pushing
3. ✅ **Backup** the git-crypt key to a private Gist
4. ✅ **Store** a copy of the Gist ID in your password manager
5. ✅ **Use** strong, unique passwords (32+ characters)
6. ✅ **Rotate** secrets regularly (every 90 days)
7. ✅ **Audit** Fly.io secrets: `flyctl secrets list`
8. ❌ **Never** share the git-crypt key via Slack/email
9. ❌ **Never** commit `.env`, `.env.keys`, or unencrypted secrets

## Troubleshooting

### "Error: file is already encrypted"

```bash
git-crypt unlock
# Edit files
git-crypt lock
```

### "Error: Unable to read key"

```bash
# Re-import key
git-crypt unlock -k ../.keys/ogt-web.git-crypt.key
```

### "Error: file has been modified"

```bash
# Check status
git-crypt status -e

# If stuck, force unlock
git-crypt unlock -f
```

### Verify Encryption

```bash
# Lock the repo
git-crypt lock

# Check a file is encrypted
head -c 20 .env.encrypted
# Should show binary data like: \x00GITCRYPT\x00...

# Unlock
git-crypt unlock

# Now it's readable
head .env.encrypted
```

## Support

- git-crypt docs: https://github.com/AGWA/git-crypt
- GitHub CLI: https://cli.github.com/manual/
- Fly.io secrets: https://fly.io/docs/reference/secrets/

