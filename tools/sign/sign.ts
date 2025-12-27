/**
 * Automatic SketchUp Extension Signing
 *
 * This script automates the signing process via the Extension Warehouse portal
 * using Puppeteer browser automation.
 *
 * Based on: https://github.com/lindale-dev/automatic-sketchup-extension-signing
 *
 * Usage:
 *   npx tsx sign.ts <path-to-rbz> [options]
 *
 * Options:
 *   --validate    Only validate credentials without signing
 *   --headless    Run in headless mode (default: true)
 *   --no-headless Show browser window during signing
 *   --help        Show help message
 */

import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import puppeteer, { Browser, Page } from "puppeteer";
import { config } from "dotenv";

// Get __dirname equivalent for ES modules (compatible with Node.js 18+)
const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Load environment variables from .env file
config({ path: path.join(__dirname, ".env") });

// =============================================================================
// Configuration
// =============================================================================

/** URLs for the Extension Warehouse signing portal */
const URLS = {
    SIGNING_PORTAL: "https://extensions.sketchup.com/en/developer_center/extension_signature",
    LOGIN: "https://extensions.sketchup.com/user/login",
} as const;

/** Timeout values in milliseconds */
const TIMEOUTS = {
    NAVIGATION: 30000,      // Page navigation timeout
    DOWNLOAD: 120000,       // Wait for signed file download
    LOGIN: 120000,          // Wait for user to complete login
    ELEMENT_WAIT: 5000,     // Wait for elements to appear
    TYPING_DELAY: 50,       // Delay between keystrokes (ms)
} as const;

/** 
 * Trimble Identity login form selectors
 * Note: These may change if Trimble updates their login page
 */
const SELECTORS = {
    // Email entry stage
    EMAIL_INPUT: '#username-field',
    NEXT_BUTTON: '#enter_username_submit',
    // Password entry stage
    PASSWORD_INPUT: 'input[name="password"]',
    SIGN_IN_BUTTON: 'button[name="password-submit"]',
    // Extension Warehouse
    FILE_INPUT: 'input[type="file"]',
} as const;

interface SigningOptions {
    rbzPath: string;
    username: string;
    password: string;
    headless: boolean;
    validateOnly: boolean;
}

function printHelp(): void {
    console.log(`
Automatic SketchUp Extension Signing

Usage:
  npx tsx sign.ts <path-to-rbz> [options]

Options:
  --validate      Only validate credentials without signing
  --headless      Run in headless mode (default: true)
  --no-headless   Show browser window during signing
  --output <dir>  Output directory for signed file (default: same as input)
  --help          Show this help message

Environment Variables:
  EW_USERNAME     Extension Warehouse username/email
  EW_PASSWORD     Extension Warehouse password

  These can be set in a .env file in this directory.
  See .env.example for a template.

Examples:
  npx tsx sign.ts ../BUILDS/release/MyExtension_v1.0.0.rbz
  npx tsx sign.ts my_extension.rbz --no-headless
  npx tsx sign.ts --validate
`);
}

function parseArgs(): SigningOptions {
    const args = process.argv.slice(2);

    if (args.includes("--help") || args.includes("-h")) {
        printHelp();
        process.exit(0);
    }

    const validateOnly = args.includes("--validate");
    const headless = !args.includes("--no-headless");

    // Find RBZ path (first non-option argument)
    const rbzPath = args.find((arg) => !arg.startsWith("--")) || "";

    // Get credentials from environment
    const username = process.env.EW_USERNAME || "";
    const password = process.env.EW_PASSWORD || "";

    return {
        rbzPath,
        username,
        password,
        headless,
        validateOnly,
    };
}

/**
 * Check if credentials are configured in environment.
 * Does not abort - allows fallback to passkey/manual login.
 * @param username - Extension Warehouse username (email)
 * @param password - Extension Warehouse password
 * @returns true if credentials are configured, false otherwise
 */
function checkCredentials(username: string, password: string): boolean {
    if (!username || !password) {
        console.log("⚠️  No credentials configured - will use manual/passkey login");
        console.log("   (To enable auto-fill, set EW_USERNAME and EW_PASSWORD in .env)");
        return false;
    }
    return true;
}

/**
 * Wait for user to complete login, with optional credential auto-fill.
 * Navigates to signing portal, attempts login, and waits for success indicators.
 * @param page - Puppeteer page instance
 * @param username - Extension Warehouse username (may be empty)
 * @param password - Extension Warehouse password (may be empty)
 * @param timeoutMs - Maximum time to wait for login completion
 * @returns true if login successful, false if timed out
 */
async function waitForLogin(page: Page, username: string, password: string, timeoutMs: number = 120000): Promise<boolean> {
    console.log("🔐 Navigating to signing portal...");

    const startTime = Date.now();
    let credentialsAttempted = false;

    // Navigate to the signing portal
    await page.goto(URLS.SIGNING_PORTAL, { waitUntil: "networkidle0", timeout: TIMEOUTS.NAVIGATION });

    // Check if we're already logged in and try to click sign in button
    // Wrapped in try/catch because page might navigate during these checks
    try {
        // Check if we're already logged in (signing form is visible)
        const alreadyLoggedIn = await page.$('input[type="file"]');
        if (alreadyLoggedIn) {
            console.log("✅ Already logged in!");
            return true;
        }

        // Look for "Sign In To Continue" button/link and click it
        const signInButton = await page.evaluateHandle(() => {
            const directLink = document.querySelector('a[href*="user/login"]');
            if (directLink) return directLink;

            const buttons = document.querySelectorAll('a, button');
            for (const btn of buttons) {
                if (btn.textContent?.toLowerCase().includes('sign in')) {
                    return btn;
                }
            }
            return null;
        });

        if (signInButton && await signInButton.asElement()) {
            console.log("🔘 Clicking 'Sign In To Continue' button...");
            await (signInButton as any).click();
            await new Promise(resolve => setTimeout(resolve, 3000));
        }
    } catch (e) {
        // Page might have navigated during these checks - this is fine, continue to login wait
        console.log("   Page navigating...");
    }

    console.log("🔐 Please complete login in the browser window (passkey/password supported)");
    console.log("   After login, the page should show the 'Sign Extension' button.");

    // Wait for login to complete
    // Check for either file input OR "Sign Extension" button (user is logged in if button visible)

    while (Date.now() - startTime < timeoutMs) {
        try {
            // Try to auto-fill credentials on Trimble Identity page (once)
            if (!credentialsAttempted && username && password) {
                await tryAutoFillCredentials(page, username, password);
                credentialsAttempted = true;
            }

            // Check for file input (indicates we're logged in and past the initial page)
            const fileInput = await page.$('input[type="file"]');
            if (fileInput) {
                console.log("\n✅ Login successful! File upload form detected.");
                return true;
            }

            // Check for "Sign Extension" button - this means user is logged in
            // Use evaluateHandle to find button by text
            const signButton = await page.evaluateHandle(() => {
                const buttons = document.querySelectorAll('a, button');
                for (const btn of buttons) {
                    if (btn.textContent?.toLowerCase().includes('sign extension')) {
                        return btn;
                    }
                }
                return null;
            });

            if (signButton && await signButton.asElement()) {
                console.log("\n✅ Login successful! 'Sign Extension' button found.");
                return true;
            }

            const elapsed = Math.round((Date.now() - startTime) / 1000);
            process.stdout.write(`\r⏳ Waiting for login: ${elapsed}s (timeout: ${timeoutMs / 1000}s)`);
        } catch (e) {
            // Page context changed during navigation - this is normal, just continue waiting
            const elapsed = Math.round((Date.now() - startTime) / 1000);
            process.stdout.write(`\r⏳ Navigating... ${elapsed}s`);
        }

        await new Promise(resolve => setTimeout(resolve, 2000));
    }

    console.log("\n❌ Login timed out");
    return false;
}

/**
 * Attempt to auto-fill Trimble Identity login form with stored credentials.
 * Handles both email/password stages of the Trimble Identity flow.
 * Silently fails if fields not found - user can complete login manually.
 * @param page - Puppeteer page instance
 * @param username - Extension Warehouse username (email)
 * @param password - Extension Warehouse password
 */
async function tryAutoFillCredentials(page: Page, username: string, password: string): Promise<void> {
    try {
        // First, try to dismiss any cookie consent banners
        try {
            const cookieButtons = await page.$$('button, a');
            for (const btn of cookieButtons) {
                const text = await btn.evaluate(el => el.textContent?.toLowerCase() || '');
                if (text.includes('accept') || text.includes('alle cookies') || text.includes('akkoord')) {
                    console.log("   🍪 Dismissing cookie banner...");
                    await btn.click();
                    await new Promise(resolve => setTimeout(resolve, 1000));
                    break;
                }
            }
        } catch {
            // Cookie banner handling failed, continue anyway
        }


        // Wait a bit for the login form to fully render
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Trimble Identity login form - use page.type with selector for more reliable interaction
        // Stage 1: Email/Username entry
        try {
            await page.waitForSelector(SELECTORS.EMAIL_INPUT, { timeout: TIMEOUTS.ELEMENT_WAIT });
            console.log("   📝 Found email field, entering credentials...");

            // Type directly using page.type with selector
            await page.type(SELECTORS.EMAIL_INPUT, username, { delay: TIMEOUTS.TYPING_DELAY });

            // Click Next button
            await page.waitForSelector(SELECTORS.NEXT_BUTTON, { timeout: 3000 });
            console.log("   📝 Clicking Next button...");
            await page.click(SELECTORS.NEXT_BUTTON);
            await new Promise(resolve => setTimeout(resolve, 3000));

            // Stage 2: Password entry (wait for password field to appear)
            try {
                await page.waitForSelector(SELECTORS.PASSWORD_INPUT, { timeout: TIMEOUTS.ELEMENT_WAIT, visible: true });
                console.log("   📝 Found password field, entering password...");

                // Click to focus the password field first, then wait for it to be ready
                await page.click(SELECTORS.PASSWORD_INPUT);
                await new Promise(resolve => setTimeout(resolve, 500));

                // Clear and type password
                await page.type(SELECTORS.PASSWORD_INPUT, password, { delay: TIMEOUTS.TYPING_DELAY });
                await new Promise(resolve => setTimeout(resolve, 500));

                // Submit with Sign In button (Dutch: "Aanmelden")
                await page.waitForSelector(SELECTORS.SIGN_IN_BUTTON, { timeout: 3000 });
                console.log("   📝 Clicking Sign In button...");
                await page.click(SELECTORS.SIGN_IN_BUTTON);
                await new Promise(resolve => setTimeout(resolve, 3000));
            } catch {
                console.log("   ⚠️  Password field not found - may need passkey or other auth method");
            }
        } catch {
            console.log("   ⚠️  Email field not found - login form may differ from expected");
        }
    } catch (e: unknown) {
        // Auto-fill failed - user will need to login manually
        const errorMessage = e instanceof Error ? e.message : String(e);
        console.log(`   ⚠️  Auto-fill encountered an issue: ${errorMessage.slice(0, 100)}`);
    }
}

/**
 * Initiate login process for Extension Warehouse.
 * Delegates to waitForLogin with configured timeout.
 * @param page - Puppeteer page instance
 * @param username - Extension Warehouse username
 * @param password - Extension Warehouse password
 * @returns true if login successful
 */
async function login(page: Page, username: string, password: string): Promise<boolean> {
    console.log("🔐 Logging into Extension Warehouse...");

    // Note: waitForLogin handles navigation to signing portal and credential auto-fill
    // It will attempt to fill email/password if fields are found (Trimble Identity)
    // For passkey-only or MFA, user will need to complete login manually
    return waitForLogin(page, username, password, 120000);
}

/**
 * Upload RBZ file to Extension Warehouse and complete signing process.
 * Handles file upload, encryption selection, and signed file download.
 * @param page - Puppeteer page instance  
 * @param rbzPath - Absolute path to RBZ file to sign
 * @param downloadDir - Directory to save downloaded signed file
 * @returns Path to signed file, or null if failed
 */
async function uploadAndSign(
    page: Page,
    rbzPath: string,
    downloadDir: string
): Promise<string | null> {
    console.log("📤 Preparing to sign extension...");

    // Only navigate if not already on a signing-related page
    const currentUrl = page.url();
    if (!currentUrl.includes("extension") || !currentUrl.includes("sign")) {
        console.log("   Navigating to signing portal...");
        await page.goto(URLS.SIGNING_PORTAL, {
            waitUntil: "networkidle0",
            timeout: TIMEOUTS.NAVIGATION,
        });
    }

    // Check for "Sign Extension" button and click it if present
    console.log("   Looking for 'Sign Extension' button...");
    const signExtButton = await page.evaluateHandle(() => {
        const buttons = document.querySelectorAll('a, button');
        for (const btn of buttons) {
            if (btn.textContent?.toLowerCase().includes('sign extension')) {
                return btn;
            }
        }
        return null;
    });

    if (signExtButton && await signExtButton.asElement()) {
        console.log("🔘 Clicking 'Sign Extension' button...");
        await (signExtButton as any).click();
        await new Promise(resolve => setTimeout(resolve, 3000)); // Wait for page to update
    }

    // Now look for the file input
    let fileInput = await page.$('input[type="file"]');
    if (!fileInput) {
        // Try waiting a bit more for the page to fully load
        await new Promise(resolve => setTimeout(resolve, 2000));
        fileInput = await page.$('input[type="file"]');
    }

    if (!fileInput) {
        console.error("❌ Could not find file upload input on signing page");
        console.error("   Current URL: " + page.url());
        return null;
    }

    console.log(`📁 Uploading: ${path.basename(rbzPath)}`);
    await fileInput.uploadFile(rbzPath);

    // Wait for the file to be registered
    await new Promise((resolve) => setTimeout(resolve, 2000));

    // Step 1: Click "Next" button after file upload
    console.log("   Looking for 'Next' button...");
    const nextButton = await page.evaluateHandle(() => {
        const buttons = document.querySelectorAll('a, button');
        for (const btn of buttons) {
            if (btn.textContent?.toLowerCase().trim() === 'next') {
                return btn;
            }
        }
        return null;
    });

    if (nextButton && await nextButton.asElement()) {
        console.log("🔘 Clicking 'Next' button...");
        await (nextButton as any).click();
        await new Promise(resolve => setTimeout(resolve, 3000)); // Wait for options page
    } else {
        console.error("❌ Could not find 'Next' button after file upload");
        return null;
    }

    // Step 2: Encryption selection page - "BEST" is selected by default, just click Next
    console.log("   Encryption selection page - clicking 'Next'...");
    await new Promise(resolve => setTimeout(resolve, 2000));

    const nextButton2 = await page.evaluateHandle(() => {
        const buttons = document.querySelectorAll('a, button');
        for (const btn of buttons) {
            if (btn.textContent?.toLowerCase().trim() === 'next') {
                return btn;
            }
        }
        return null;
    });

    if (nextButton2 && await nextButton2.asElement()) {
        console.log("🔘 Clicking 'Next' button (encryption)...");
        await (nextButton2 as any).click();
        await new Promise(resolve => setTimeout(resolve, 3000));
    }

    // Step 3: Wait for encryption to complete and download button to appear
    // The server processes the file, which takes time
    console.log("   Waiting for encryption to complete...");

    const encryptionTimeout = 120000; // 2 minutes for encryption
    const startEncryption = Date.now();
    let signButton: any = null;

    while (Date.now() - startEncryption < encryptionTimeout) {
        try {
            // Check for error messages on the page
            // Look for the "Error!" heading and any list items below it
            const errorMessage = await page.evaluate(() => {
                // Check for any element containing "Error!" text
                const allText = document.body.innerText || '';
                if (allText.includes('Error!')) {
                    // Found an error - try to extract the specific message
                    const listItems = document.querySelectorAll('li');
                    for (const li of listItems) {
                        const text = li.textContent?.trim();
                        if (text && (text.includes('Invalid') || text.includes('error') || text.includes('failed'))) {
                            return text;
                        }
                    }
                    // Also check for "Dismiss" button which indicates error dialog
                    const dismissBtn = document.querySelector('a, button');
                    if (dismissBtn?.textContent?.toLowerCase().includes('dismiss')) {
                        return 'Extension validation error - check the browser for details';
                    }
                    return 'An error occurred during signing';
                }
                return null;
            });

            if (errorMessage) {
                console.error(`\n❌ Extension Warehouse error: ${errorMessage}`);
                return null;
            }

            // Look for Sign and Download button
            signButton = await page.evaluateHandle(() => {
                const buttons = document.querySelectorAll('a, button');
                for (const btn of buttons) {
                    const text = btn.textContent?.toLowerCase() || '';
                    if (text.includes('sign') && text.includes('download')) {
                        return btn;
                    }
                    if (text.includes('download') && !text.includes('learn')) {
                        return btn;
                    }
                }
                return null;
            });

            if (signButton && await signButton.asElement()) {
                console.log("\n✅ Encryption complete! Download button found.");
                break;
            }

            // Also check if there are any more Next buttons to click
            const nextBtn = await page.evaluateHandle(() => {
                const buttons = document.querySelectorAll('a, button');
                for (const btn of buttons) {
                    if (btn.textContent?.toLowerCase().trim() === 'next') {
                        return btn;
                    }
                }
                return null;
            });

            if (nextBtn && await nextBtn.asElement()) {
                console.log("🔘 Clicking 'Next' button...");
                await (nextBtn as any).click();
                await new Promise(resolve => setTimeout(resolve, 3000));
            }

            const elapsed = Math.round((Date.now() - startEncryption) / 1000);
            process.stdout.write(`\r⏳ Waiting for encryption: ${elapsed}s`);

        } catch (e) {
            // Page might be updating
        }

        await new Promise(resolve => setTimeout(resolve, 2000));
    }

    if (!signButton || !await signButton.asElement()) {
        console.error("\n❌ Could not find sign/download button after encryption");
        console.log("   Available buttons for debugging:");
        await page.evaluate(() => {
            const btns = document.querySelectorAll('button, a');
            btns.forEach(b => console.log("Button:", b.textContent?.trim()));
        });
        return null;
    }

    console.log("✍️  Signing extension (this may take a moment)...");

    // Set up download handling
    const client = await page.createCDPSession();
    await client.send("Page.setDownloadBehavior", {
        behavior: "allow",
        downloadPath: downloadDir,
    });

    // Click sign and wait for download
    await signButton.click();

    // Wait for the download to complete
    const signedFile = await waitForDownload(downloadDir, path.basename(rbzPath), TIMEOUTS.DOWNLOAD);

    if (signedFile) {
        console.log(`✅ Signed file downloaded: ${signedFile}`);
        return signedFile;
    } else {
        console.error("❌ Timed out waiting for signed file download");
        return null;
    }
}

/**
 * Wait for a file to appear in the download directory.
 * Polls directory until file with expected name appears.
 * @param downloadDir - Directory to monitor for downloads
 * @param expectedFilename - Filename to look for
 * @param timeoutMs - Maximum time to wait
 * @returns Path to downloaded file, or null if timeout
 */
async function waitForDownload(
    downloadDir: string,
    expectedFilename: string,
    timeoutMs: number
): Promise<string | null> {
    const startTime = Date.now();
    const checkInterval = 1000;

    while (Date.now() - startTime < timeoutMs) {
        const files = fs.readdirSync(downloadDir);

        // Look for the RBZ file that was just downloaded
        // It should match the original filename
        for (const file of files) {
            if (file.endsWith(".rbz") && !file.endsWith(".crdownload")) {
                const filePath = path.join(downloadDir, file);
                const stat = fs.statSync(filePath);

                // Check if file was modified recently (within our waiting period)
                if (stat.mtime.getTime() > startTime) {
                    return filePath;
                }
            }
        }

        // Print progress
        const elapsed = Math.round((Date.now() - startTime) / 1000);
        process.stdout.write(`\r⏳ Waiting for download: ${elapsed}s`);

        await new Promise((resolve) => setTimeout(resolve, checkInterval));
    }

    process.stdout.write("\n");
    return null;
}

async function main(): Promise<void> {
    const options = parseArgs();

    // Check credentials (optional - can use passkey login if not configured)
    const hasCredentials = checkCredentials(options.username, options.password);

    if (options.validateOnly) {
        if (hasCredentials) {
            console.log("✅ Credentials are configured");
            console.log(`   Username: ${options.username}`);
        } else {
            console.log("⚠️  No credentials configured");
            console.log("   Manual or passkey login will be required");
        }
        process.exit(0);
    }

    // Validate RBZ path
    if (!options.rbzPath) {
        console.error("❌ No RBZ file specified");
        printHelp();
        process.exit(1);
    }

    const absoluteRbzPath = path.resolve(options.rbzPath);
    if (!fs.existsSync(absoluteRbzPath)) {
        console.error(`❌ RBZ file not found: ${absoluteRbzPath}`);
        process.exit(1);
    }

    if (!absoluteRbzPath.endsWith(".rbz")) {
        console.error("❌ File must have .rbz extension");
        process.exit(1);
    }

    console.log("🚀 Starting SketchUp Extension Signing");
    console.log(`   File: ${path.basename(absoluteRbzPath)}`);
    console.log(`   Headless: ${options.headless}`);
    console.log("");

    // Create a temporary download directory
    const downloadDir = fs.mkdtempSync(path.join(__dirname, "download-"));

    let browser: Browser | null = null;

    try {
        // Chrome executable selection:
        // 1. First try: Let Puppeteer use its bundled Chrome (no executablePath)
        // 2. Fallback: Use system Chrome if environment variable set or Puppeteer Chrome fails
        //
        // Note: Puppeteer v24+ has improved macOS Sequoia support. If issues persist,
        // set PUPPETEER_USE_SYSTEM_CHROME=1 to force system Chrome usage.

        let executablePath: string | undefined;
        const forceSystemChrome = process.env.PUPPETEER_USE_SYSTEM_CHROME === "1";
        const systemChromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

        if (forceSystemChrome && fs.existsSync(systemChromePath)) {
            executablePath = systemChromePath;
            console.log("🔧 Using system Chrome (forced via PUPPETEER_USE_SYSTEM_CHROME)");
        } else {
            // Let Puppeteer manage Chrome automatically (preferred for portability)
            console.log("🔧 Using Puppeteer-managed Chrome");
        }

        // Launch browser
        browser = await puppeteer.launch({
            headless: options.headless,
            executablePath,
            args: [
                "--no-sandbox",
                "--disable-setuid-sandbox",
                "--disable-dev-shm-usage",
                "--disable-gpu",
                "--no-first-run",
                "--no-zygote",
            ],
            defaultViewport: { width: 1280, height: 800 },
        });

        const page = await browser.newPage();

        // Set viewport
        await page.setViewport({ width: 1280, height: 800 });

        // Login
        const loginSuccess = await login(page, options.username, options.password);
        if (!loginSuccess) {
            process.exit(1);
        }

        // Upload and sign
        const signedFilePath = await uploadAndSign(page, absoluteRbzPath, downloadDir);

        if (signedFilePath) {
            // Output the path for the Rake task to capture and move
            // We keep the signed file in the download directory - the Rake task will move it
            // to the final SIGNED_DIR location with proper naming
            console.log(`\n📦 Signed file ready: ${signedFilePath}`);
            console.log(`\n__SIGNED_FILE__:${signedFilePath}`);

            // Note: We intentionally do NOT clean up downloadDir here
            // The file is still in downloadDir for the Rake task to move
        } else {
            process.exit(1);
        }
    } catch (error) {
        console.error("❌ Error during signing:", error);
        process.exit(1);
    } finally {
        // Cleanup browser only - keep download directory for Rake task
        if (browser) {
            await browser.close();
        }

        // Note: downloadDir cleanup is skipped - the Rake task will move the file
        // and potentially clean up, or the temp dir will be cleaned by OS
    }
}

main();
