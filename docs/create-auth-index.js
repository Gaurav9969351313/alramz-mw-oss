#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const username = process.env.DOCS_USERNAME || 'admin';
const password = process.env.DOCS_PASSWORD || 'changeme';

const outputPath = path.join(__dirname, 'dist', 'index.html');

const htmlContent = `<!DOCTYPE html>
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

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: #f5f5f5;
        }

        #docs-container {
            width: 100%;
            height: 100vh;
            border: none;
        }

        .auth-overlay {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 9999;
            padding: 20px;
        }

        .auth-container {
            background: white;
            border-radius: 8px;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
            padding: 40px;
            width: 100%;
            max-width: 400px;
        }

        .auth-header {
            text-align: center;
            margin-bottom: 30px;
        }

        .auth-header h1 {
            font-size: 24px;
            color: #333;
            margin-bottom: 10px;
        }

        .auth-header p {
            color: #666;
            font-size: 14px;
        }

        .auth-form {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }

        .form-group {
            display: flex;
            flex-direction: column;
            gap: 5px;
        }

        label {
            color: #333;
            font-weight: 500;
            font-size: 14px;
        }

        input[type="text"],
        input[type="password"] {
            padding: 10px 12px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
            transition: border-color 0.3s;
        }

        input[type="text"]:focus,
        input[type="password"]:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }

        button {
            padding: 10px 16px;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 4px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.3s;
            margin-top: 10px;
        }

        button:hover {
            background: #5568d3;
        }

        button:active {
            transform: scale(0.98);
        }

        .error {
            color: #d32f2f;
            font-size: 12px;
            padding: 10px;
            background: #ffebee;
            border-radius: 4px;
            border-left: 3px solid #d32f2f;
            display: none;
        }

        .error.show {
            display: block;
        }

        .hidden {
            display: none !important;
        }
    </style>
</head>
<body>
    <div id="docs-container"></div>
    <div class="auth-overlay" id="auth-overlay">
        <div class="auth-container">
            <div class="auth-header">
                <h1>API Documentation</h1>
                <p>Please sign in to access</p>
            </div>
            <form class="auth-form" id="auth-form" onsubmit="handleLogin(event)">
                <div class="form-group">
                    <label for="username">Username</label>
                    <input type="text" id="username" placeholder="Enter username" autocomplete="username" required autofocus>
                </div>
                <div class="form-group">
                    <label for="password">Password</label>
                    <input type="password" id="password" placeholder="Enter password" autocomplete="current-password" required>
                </div>
                <div class="error" id="error"></div>
                <button type="submit">Sign In</button>
            </form>
        </div>
    </div>

    <script>
        // Configuration - credentials set at build time
        const CREDENTIALS = {
            username: '${username}',
            password: '${password}'
        };

        function checkAuth() {
            return sessionStorage.getItem('apiDocsAuth') === 'true';
        }

        function handleLogin(e) {
            e.preventDefault();
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            const errorEl = document.getElementById('error');

            if (username === CREDENTIALS.username && password === CREDENTIALS.password) {
                sessionStorage.setItem('apiDocsAuth', 'true');
                showDocs();
            } else {
                errorEl.textContent = 'Invalid username or password';
                errorEl.classList.add('show');
                document.getElementById('password').value = '';
                document.getElementById('username').focus();
            }
        }

        function showDocs() {
            // Hide auth overlay
            document.getElementById('auth-overlay').classList.add('hidden');

            // Create service documentation UI
            const container = document.getElementById('docs-container');
            container.innerHTML = \`
                <div style="display: flex; height: 100vh; background: #f5f5f5;">
                    <div style="width: 200px; background: #fff; border-right: 1px solid #ddd; padding: 20px; overflow-y: auto;">
                        <h3 style="margin-top: 0; color: #333;">Services</h3>
                        <ul style="list-style: none; padding: 0; margin: 0;">
                            <li><button onclick="loadService('notification-service', 'Notification Service')" style="width: 100%; text-align: left; padding: 10px; border: none; background: #667eea; color: white; border-radius: 4px; cursor: pointer; font-weight: 500;">Notification Service</button></li>
                            <li style="margin-top: 10px;"><button onclick="loadService('data-validation-service', 'Data Validation Service')" style="width: 100%; text-align: left; padding: 10px; border: 1px solid #ddd; background: #fff; border-radius: 4px; cursor: pointer;">Data Validation Service</button></li>
                        </ul>
                        <hr style="margin: 20px 0; border: none; border-top: 1px solid #ddd;">
                        <button onclick="logout()" style="width: 100%; padding: 10px; background: #f5f5f5; border: 1px solid #ddd; border-radius: 4px; cursor: pointer; color: #d32f2f;">Logout</button>
                    </div>
                    <div style="flex: 1;">
                        <iframe id="docs-iframe" src="./notification-service.html" style="width: 100%; height: 100%; border: none;"></iframe>
                    </div>
                </div>
            \`;

            // Make functions globally available
            window.loadService = function(service, title) {
                document.getElementById('docs-iframe').src = './' + service + '.html';
                // Update button styles
                document.querySelectorAll('button').forEach(btn => {
                    btn.style.background = btn.textContent.includes(title) ? '#667eea' : '#fff';
                    btn.style.color = btn.textContent.includes(title) ? 'white' : '#333';
                    btn.style.border = btn.textContent.includes(title) ? 'none' : '1px solid #ddd';
                });
            };

            window.logout = function() {
                sessionStorage.removeItem('apiDocsAuth');
                window.location.reload();
            };
        }

        // Check authentication on page load
        if (checkAuth()) {
            showDocs();
        } else {
            // Focus on username field for better UX
            document.getElementById('username').focus();
        }

        // Handle logout (optional)
        window.addEventListener('beforeunload', function(e) {
            // Clear auth on page close/tab close
            // Uncomment if you want to require re-authentication on each visit
            // sessionStorage.removeItem('apiDocsAuth');
        });
    </script>
</body>
</html>
`;

try {
  fs.writeFileSync(outputPath, htmlContent, 'utf8');
  console.log('✓ Authentication index created successfully');
  console.log('✓ Credentials: ' + username + ' / ****');
  process.exit(0);
} catch (error) {
  console.error('✗ Error creating authentication index:', error.message);
  process.exit(1);
}
