# SketchUp Extension Signing Tool

Automated browser-based extension signing using Puppeteer.

## Overview

This tool automates the SketchUp Extension Warehouse signing process by:
1. Opening a browser to the signing portal
2. Auto-filling login credentials (optional)
3. Uploading the RBZ file
4. Downloading the signed extension

## Prerequisites

- Node.js 18+
- npm

## Installation

```bash
npm install
```

This installs Puppeteer and downloads Chrome for Testing automatically.

## Configuration

### Credentials (Optional)

Copy `.env.example` to `.env` and fill in your Extension Warehouse credentials:

```bash
cp .env.example .env
```

Edit `.env`:
```
EW_USERNAME=your-trimble-email@example.com
EW_PASSWORD=your-password
```

> ⚠️ **Security:** Never commit the `.env` file. It's gitignored by default.

If credentials are not configured, the script will wait for manual/passkey login.

## Usage

### Via Rake (Recommended)

```bash
# From project root:
rake build:sign:auto     # Build and sign automatically
rake build:sign          # Build and sign manually
```

### Direct CLI

```bash
npx tsx sign.ts <path-to-rbz> [options]
```

**Options:**
| Option | Description |
|--------|-------------|
| `--no-headless` | Show browser window (default for manual login) |
| `--headless` | Run in headless mode |
| `--validate` | Test credentials without signing |
| `--help` | Show help message |

**Examples:**

```bash
# Sign with visible browser
npx tsx sign.ts ../../BUILDS/release/MyExtension_v1.0.0.rbz --no-headless

# Validate credentials
npx tsx sign.ts --validate
```

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    Signing Process Flow                      │
├─────────────────────────────────────────────────────────────┤
│  1. Launch Browser (Puppeteer-managed Chrome)               │
│  2. Navigate to Extension Signing Portal                     │
│  3. Click "Sign In To Continue"                              │
│  4. Auto-fill credentials (if configured)                    │
│  5. Wait for login completion (passkey/MFA supported)        │
│  6. Click "Sign Extension"                                   │
│  7. Upload RBZ file                                          │
│  8. Select encryption options                                │
│  9. Wait for signing to complete                             │
│  10. Download signed RBZ                                     │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Socket Hang Up Errors

If you see "socket hang up" errors on macOS, try:

```bash
PUPPETEER_USE_SYSTEM_CHROME=1 npx tsx sign.ts <path-to-rbz> --no-headless
```

This forces the script to use your installed Google Chrome instead of Puppeteer's Chrome.

### Login Timeout

The script waits 120 seconds for login. If you need more time for MFA, increase the timeout in `sign.ts`:

```typescript
return waitForLogin(page, username, password, 180000); // 3 minutes
```

### Password Not Entering

If auto-fill doesn't work with your Trimble account, you can:
1. Use passkey login instead
2. Enter credentials manually when prompted
3. Check if the Trimble login form has changed (selectors may need updating)

## File Structure

```
tools/sign/
├── sign.ts           # Main signing script
├── package.json      # Dependencies (puppeteer, tsx, dotenv)
├── tsconfig.json     # TypeScript configuration
├── .env.example      # Credential template
├── .env              # Your credentials (gitignored)
└── README.md         # This file
```

## Development

### Selectors

The Trimble Identity login form uses these selectors (may change):

| Element | Selector |
|---------|----------|
| Email input | `#username-field` |
| Next button | `#enter_username_submit` |
| Password input | `input[name="password"]` |
| Sign in button | `button[name="password-submit"]` |

### Adding Features

The main functions are:

- `waitForLogin()` - Handles navigation and login wait loop
- `tryAutoFillCredentials()` - Auto-fills Trimble Identity form
- `uploadAndSign()` - Handles the signing workflow
- `waitForDownload()` - Monitors download directory for signed file
