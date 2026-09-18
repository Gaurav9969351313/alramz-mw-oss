#!/usr/bin/env node

/**
 * Create Auth Wrapper for API Docs
 * Generates an HTML wrapper with login gate that requires GitHub Secret credentials
 *
 * Usage:
 *   DOCS_USERNAME=admin DOCS_PASSWORD=pass node create-auth-wrapper.js
 *   node create-auth-wrapper.js admin SecurePass123
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const outputDir = process.argv[2] || 'api-docs-build';
const username = process.env.DOCS_USERNAME || process.argv[3];
const password = process.env.DOCS_PASSWORD || process.argv[4];

if (!username || !password) {
    console.error('❌ Error: Username and password required');
    console.error('Usage: DOCS_USERNAME=user DOCS_PASSWORD=pass node create-auth-wrapper.js [output-dir]');
    process.exit(1);
}

// Create password hash
const passwordHash = crypto
    .createHash('sha256')
    .update(password)
    .digest('hex');

console.log(`✓ Creating auth wrapper for user: ${username}`);

// Create auth wrapper HTML
const authWrapperHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>API Documentation</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    :root {
      --color-primary: #1e293b;
      --color-secondary: #0f172a;
      --color-accent: #3b82f6;
      --color-accent-light: #60a5fa;
      --color-success: #10b981;
      --color-error: #ef4444;
      --color-text: #1f2937;
      --color-text-light: #6b7280;
      --color-border: #e5e7eb;
      --color-bg: #ffffff;
      --color-bg-light: #f9fafb;
    }

    html, body {
      height: 100%;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
      background: var(--color-bg);
      color: var(--color-text);
    }

    .login-container {
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100%;
      background: linear-gradient(135deg, var(--color-primary) 0%, var(--color-secondary) 100%);
    }

    .login-card {
      background: white;
      border-radius: 12px;
      padding: 3rem;
      max-width: 400px;
      width: 90%;
      box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
    }

    .login-card h1 {
      font-size: 1.8rem;
      margin-bottom: 0.5rem;
      color: var(--color-primary);
    }

    .login-card p {
      color: var(--color-text-light);
      margin-bottom: 2rem;
      font-size: 0.95rem;
    }

    .form-group {
      margin-bottom: 1.5rem;
    }

    .form-group label {
      display: block;
      margin-bottom: 0.5rem;
      font-weight: 600;
      color: var(--color-primary);
    }

    .form-group input {
      width: 100%;
      padding: 0.75rem;
      border: 2px solid var(--color-border);
      border-radius: 6px;
      font-size: 1rem;
      transition: border-color 0.3s ease;
    }

    .form-group input:focus {
      outline: none;
      border-color: var(--color-accent);
      box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
    }

    .login-button {
      width: 100%;
      padding: 0.75rem;
      background: linear-gradient(135deg, var(--color-accent) 0%, var(--color-accent-light) 100%);
      color: white;
      border: none;
      border-radius: 6px;
      font-size: 1rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.3s ease;
    }

    .login-button:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 20px rgba(59, 130, 246, 0.3);
    }

    .login-button:active {
      transform: translateY(0);
    }

    .error-message {
      color: var(--color-error);
      font-size: 0.875rem;
      margin-top: 0.5rem;
      display: none;
    }

    .error-message.show {
      display: block;
    }

    .success-message {
      color: var(--color-success);
      font-size: 0.875rem;
      margin-top: 0.5rem;
      display: none;
    }

    .success-message.show {
      display: block;
    }

    .docs-container {
      display: none;
      height: 100%;
    }

    .docs-container.authenticated {
      display: block;
    }

    .logout-button {
      position: absolute;
      top: 1rem;
      right: 1rem;
      padding: 0.5rem 1rem;
      background: rgba(255, 255, 255, 0.2);
      color: white;
      border: 1px solid rgba(255, 255, 255, 0.3);
      border-radius: 4px;
      cursor: pointer;
      font-size: 0.85rem;
      transition: all 0.2s ease;
    }

    .logout-button:hover {
      background: rgba(255, 255, 255, 0.3);
    }

    iframe {
      width: 100%;
      height: 100%;
      border: none;
    }
  </style>
</head>
<body>
  <div id="loginSection" class="login-container">
    <div class="login-card">
      <h1>🔐 Secure Access</h1>
      <p>Enter your credentials to access API documentation</p>

      <form onsubmit="handleLogin(event)">
        <div class="form-group">
          <label for="username">Username</label>
          <input
            type="text"
            id="username"
            placeholder="Enter username"
            autocomplete="username"
            required
          />
        </div>

        <div class="form-group">
          <label for="password">Password</label>
          <input
            type="password"
            id="password"
            placeholder="Enter password"
            autocomplete="current-password"
            required
          />
          <div id="errorMsg" class="error-message"></div>
          <div id="successMsg" class="success-message"></div>
        </div>

        <button type="submit" class="login-button">
          🔓 Access Documentation
        </button>
      </form>
    </div>
  </div>

  <div id="docsSection" class="docs-container">
    <button class="logout-button" onclick="logout()">Logout</button>
    <iframe id="docsFrame" src="docs.html"></iframe>
  </div>

  <script>
    // Configuration (injected by build script)
    const VALID_USERNAME = '${username}';
    const PASSWORD_HASH = '${passwordHash}';

    // SHA256 implementation for password verification
    async function sha256(text) {
      const encoder = new TextEncoder();
      const data = encoder.encode(text);
      const hashBuffer = await crypto.subtle.digest('SHA-256', data);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    }

    function showError(message) {
      const errorDiv = document.getElementById('errorMsg');
      errorDiv.textContent = message;
      errorDiv.classList.add('show');
      document.getElementById('successMsg').classList.remove('show');
    }

    function showSuccess(message) {
      const successDiv = document.getElementById('successMsg');
      successDiv.textContent = message;
      successDiv.classList.add('show');
      document.getElementById('errorMsg').classList.remove('show');
    }

    async function handleLogin(event) {
      event.preventDefault();

      const username = document.getElementById('username').value.trim();
      const password = document.getElementById('password').value;

      // Validate username
      if (username !== VALID_USERNAME) {
        showError('Invalid username or password');
        return;
      }

      // Hash password and compare
      try {
        const enteredHash = await sha256(password);
        if (enteredHash !== PASSWORD_HASH) {
          showError('Invalid username or password');
          return;
        }

        // Authentication successful
        showSuccess('✓ Authenticated! Redirecting...');

        // Store auth token in session storage
        sessionStorage.setItem('docs_authenticated', 'true');
        sessionStorage.setItem('auth_timestamp', Date.now().toString());

        // Show docs
        setTimeout(() => {
          document.getElementById('loginSection').style.display = 'none';
          document.getElementById('docsSection').classList.add('authenticated');
        }, 500);
      } catch (error) {
        showError('Authentication error. Please try again.');
        console.error('Auth error:', error);
      }
    }

    function logout() {
      if (confirm('Are you sure you want to logout?')) {
        sessionStorage.removeItem('docs_authenticated');
        sessionStorage.removeItem('auth_timestamp');
        document.getElementById('docsSection').classList.remove('authenticated');
        document.getElementById('loginSection').style.display = 'flex';
        document.getElementById('username').value = '';
        document.getElementById('password').value = '';
        document.getElementById('errorMsg').classList.remove('show');
        document.getElementById('successMsg').classList.remove('show');
      }
    }

    // Check if already authenticated
    function checkAuth() {
      if (sessionStorage.getItem('docs_authenticated') === 'true') {
        document.getElementById('loginSection').style.display = 'none';
        document.getElementById('docsSection').classList.add('authenticated');
      }
    }

    // On page load
    window.addEventListener('DOMContentLoaded', () => {
      checkAuth();
      // Focus on username field
      document.getElementById('username').focus();
    });

    // Handle back button
    window.addEventListener('pageshow', (event) => {
      if (event.persisted) {
        checkAuth();
      }
    });
  </script>
</body>
</html>`;

// Write auth wrapper
const authWrapperPath = path.join(outputDir, 'auth-index.html');
fs.writeFileSync(authWrapperPath, authWrapperHtml);

console.log(`✓ Auth wrapper created: ${authWrapperPath}`);
console.log(`✓ Username: ${username}`);
console.log(`✓ Password hash: ${passwordHash}`);
console.log('');
console.log('📝 Next steps:');
console.log('  1. Rename your current index.html to docs.html');
console.log('     mv ' + outputDir + '/index.html ' + outputDir + '/docs.html');
console.log('  2. Rename auth-index.html to index.html');
console.log('     mv ' + outputDir + '/auth-index.html ' + outputDir + '/index.html');
console.log('  3. Now users must login before accessing the docs');
