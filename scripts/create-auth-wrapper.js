#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const outputDir = process.argv[2] || 'api-docs-build';
const username = process.env.DOCS_USERNAME || 'admin';
const password = process.env.DOCS_PASSWORD || 'SecurePass123!';

// Create password hash using SHA256
const passwordHash = crypto.createHash('sha256').update(password).digest('hex');

console.log('✓ Creating auth wrapper for user: ' + username);

const authHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>API Documentation - Login</title>
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
      box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
    }

    .login-button:active {
      transform: translateY(0);
    }

    .alert {
      margin-top: 1rem;
      padding: 0.75rem;
      border-radius: 6px;
      font-size: 0.9rem;
      display: none;
    }

    .alert-error {
      background: rgba(239, 68, 68, 0.1);
      color: var(--color-error);
      border: 1px solid rgba(239, 68, 68, 0.3);
    }

    .alert-error.show {
      display: block;
    }
  </style>
</head>
<body>
  <div class="login-container">
    <div class="login-card">
      <h1>🔐 API Documentation</h1>
      <p>Enter your credentials to access the documentation</p>

      <form id="loginForm">
        <div class="form-group">
          <label for="username">Username</label>
          <input type="text" id="username" placeholder="Enter username" required>
        </div>
        <div class="form-group">
          <label for="password">Password</label>
          <input type="password" id="password" placeholder="Enter password" required>
        </div>
        <button type="submit" class="login-button">🔓 Access Documentation</button>
        <div id="errorAlert" class="alert alert-error"></div>
      </form>
    </div>
  </div>

  <script>
    const PASSWORD_HASH = '${passwordHash}';
    const EXPECTED_USERNAME = '${username}';

    document.getElementById('loginForm').addEventListener('submit', async (e) => {
      e.preventDefault();

      const usernameInput = document.getElementById('username').value;
      const passwordInput = document.getElementById('password').value;
      const errorAlert = document.getElementById('errorAlert');

      if (usernameInput !== EXPECTED_USERNAME) {
        errorAlert.textContent = 'Invalid username or password';
        errorAlert.classList.add('show');
        return;
      }

      // Hash the input password with SHA256
      const encoder = new TextEncoder();
      const data = encoder.encode(passwordInput);
      const hashBuffer = await crypto.subtle.digest('SHA-256', data);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      const inputHash = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');

      if (inputHash !== PASSWORD_HASH) {
        errorAlert.textContent = 'Invalid username or password';
        errorAlert.classList.add('show');
        return;
      }

      // Store auth in sessionStorage
      sessionStorage.setItem('auth_token', 'authenticated');

      // Redirect to docs
      window.location.href = './docs.html';
    });
  </script>
</body>
</html>`;

const authIndexPath = path.join(outputDir, 'auth-index.html');
fs.writeFileSync(authIndexPath, authHtml);

console.log('✓ Auth wrapper created: ' + authIndexPath);
console.log('✓ Username: ' + username);
console.log('✓ Password hash: ' + passwordHash);
console.log('');
console.log('📝 Next steps:');
console.log('  1. Rename your current index.html to docs.html');
console.log('     mv ' + outputDir + '/index.html ' + outputDir + '/docs.html');
console.log('  2. Rename auth-index.html to index.html');
console.log('     mv ' + outputDir + '/auth-index.html ' + outputDir + '/index.html');
console.log('  3. Now users must login before accessing the docs');
