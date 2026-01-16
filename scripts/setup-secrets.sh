#!/bin/bash
# Upload code signing secrets to GitHub for macOS app notarization
# Usage: ./scripts/setup-secrets.sh

set -e

echo "=== GitHub Secrets Setup ==="
echo "Uploads secrets for macOS code signing & notarization"
echo ""

# Check prerequisites
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) not installed. Run: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "Error: Not logged into GitHub CLI. Run: gh auth login"
    exit 1
fi

# Detect current repo
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ -z "$REPO" ]; then
    echo "Error: Not in a GitHub repository"
    exit 1
fi

echo "Target repo: $REPO"
read -p "Continue? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Aborted"
    exit 0
fi
echo ""

# Get user input
read -p "Apple ID email: " APPLE_ID
read -p "App-specific password: " APPLE_ID_PASSWORD
read -p "Certificate export password (choose any): " CERT_PASSWORD

echo ""
echo "=== Exporting Developer ID certificate ==="
echo "You may need to authorize Keychain access..."

# Find Developer ID certificates
CERTS=$(security find-identity -v -p codesigning | grep "Developer ID Application")
CERT_COUNT=$(echo "$CERTS" | grep -c "Developer ID Application" || true)

if [ "$CERT_COUNT" -eq 0 ]; then
    echo "Error: No Developer ID Application certificate found"
    echo "You need an Apple Developer Program membership (\$99/year)"
    exit 1
elif [ "$CERT_COUNT" -eq 1 ]; then
    CERT_HASH=$(echo "$CERTS" | awk '{print $2}')
    CERT_NAME=$(echo "$CERTS" | sed 's/.*"\(.*\)"/\1/')
    echo "Found certificate: $CERT_NAME"
else
    echo "Multiple certificates found:"
    echo "$CERTS" | nl
    echo ""
    read -p "Enter number to select (1-$CERT_COUNT): " CERT_NUM
    CERT_HASH=$(echo "$CERTS" | sed -n "${CERT_NUM}p" | awk '{print $2}')
    CERT_NAME=$(echo "$CERTS" | sed -n "${CERT_NUM}p" | sed 's/.*"\(.*\)"/\1/')
    echo "Selected: $CERT_NAME"
fi

# Export certificate
TEMP_CERT=$(mktemp).p12
security export -k ~/Library/Keychains/login.keychain-db \
    -t identities -f pkcs12 -o "$TEMP_CERT" \
    -P "$CERT_PASSWORD" 2>/dev/null || {
    # Try alternative export method
    security find-identity -p codesigning -v
    echo ""
    echo "Automatic export failed. Please export manually:"
    echo "1. Open Keychain Access"
    echo "2. Find 'Developer ID Application' certificate"
    echo "3. Right-click → Export → Save as cert.p12"
    echo ""
    read -p "Enter path to exported .p12 file: " TEMP_CERT
}

# Base64 encode
CERT_BASE64=$(base64 -i "$TEMP_CERT")

echo ""
echo "=== Uploading secrets to GitHub ==="

echo "$APPLE_ID" | gh secret set APPLE_ID
echo "✓ APPLE_ID"

echo "$APPLE_ID_PASSWORD" | gh secret set APPLE_ID_PASSWORD
echo "✓ APPLE_ID_PASSWORD"

echo "temp-keychain-$(date +%s)" | gh secret set KEYCHAIN_PASSWORD
echo "✓ KEYCHAIN_PASSWORD"

echo "$CERT_PASSWORD" | gh secret set CERTIFICATE_PASSWORD
echo "✓ CERTIFICATE_PASSWORD"

echo "$CERT_BASE64" | gh secret set CERTIFICATE_BASE64
echo "✓ CERTIFICATE_BASE64"

# Cleanup
rm -f "$TEMP_CERT"

echo ""
echo "=== Done! ==="
echo "All secrets uploaded to GitHub."
echo ""
echo "Your GitHub Actions workflow can now:"
echo "  - Sign the app with Developer ID certificate"
echo "  - Notarize with Apple"
echo "  - Create distributable DMG without security warnings"
echo ""
echo "To trigger a release (if using tag-based workflow):"
echo "  git tag v1.0.0"
echo "  git push --tags"
