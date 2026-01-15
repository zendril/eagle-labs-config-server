const http = require('http');
const fs = require('fs');
const path = require('path');

const hostname = '0.0.0.0';
const port = 3000;

// Helper: Semantic version comparison
// Returns: -1 if a < b, 0 if a == b, 1 if a > b
function compareSemVer(a, b) {
    const aParts = a.split('.').map(Number);
    const bParts = b.split('.').map(Number);

    for (let i = 0; i < 3; i++) {
        const aPart = aParts[i] || 0;
        const bPart = bParts[i] || 0;
        if (aPart < bPart) return -1;
        if (aPart > bPart) return 1;
    }
    return 0;
}

// Helper: Find latest version bundle
function getLatestBundle(artifactsDir) {
    try {
        const files = fs.readdirSync(artifactsDir);
        const bundles = [];

        // Match pattern: chuck-bundle-X.Y.Z.tar.gz
        const versionRegex = /^chuck-bundle-(\d+\.\d+\.\d+)\.tar\.gz$/;

        files.forEach(file => {
            const match = file.match(versionRegex);
            if (match) {
                bundles.push({
                    version: match[1],
                    filename: file,
                    filepath: path.join(artifactsDir, file)
                });
            }
        });

        if (bundles.length === 0) {
            return null; // No versioned bundles found
        }

        // Sort by version (highest first)
        bundles.sort((a, b) => compareSemVer(b.version, a.version));
        return bundles[0];

    } catch (err) {
        console.error('Error scanning artifacts directory:', err);
        return null;
    }
}

const server = http.createServer((req, res) => {
    console.log(`Received request: ${req.method} ${req.url}`);

    // Helper to read body
    const readBody = (callback) => {
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
        });
        req.on('end', () => {
            callback(body);
        });
    };

    if (req.method === 'GET' && req.url === '/health') {
        res.statusCode = 200;
        res.setHeader('Content-Type', 'text/plain');
        res.end('OK');
    } else if (req.url === '/policy/reggie/latest') {
        readBody((data) => {
            if (req.method === 'POST' && data) {
                try {
                    const telemetry = JSON.parse(data);
                    console.log('Telemetry received (Reggie):', JSON.stringify(telemetry, null, 2));
                } catch (e) {
                    console.error('Failed to parse telemetry JSON:', e.message);
                }
            }

            res.statusCode = 200;
            res.setHeader('Content-Type', 'application/json');
            const policy = {
                latest_version: '2',
                release_date: '2025-12-02',
                grace_period_days: 30,
                message: 'Policy check successful'
            };
            res.end(JSON.stringify(policy));
        });
    } else if (req.url === '/policy/chuck/latest') {
        readBody((data) => {
            if (req.method === 'POST' && data) {
                try {
                    const telemetry = JSON.parse(data);

                    // Consolidated telemetry logging (includes fields from both old and new systems)
                    const logEntry = {
                        timestamp: new Date().toISOString(),
                        feature: telemetry.feature || 'chuck',
                        sessionId: telemetry.sessionId || telemetry.hostname || 'unknown',
                        projectName: telemetry.projectName || 'Unknown',
                        versions: {
                            feature: telemetry.client_version || 'unknown',
                            bundle: telemetry.bundle_version || 'unknown'
                        },
                        installedFeatures: telemetry.markers || {},
                        osInfo: {
                            pretty_name: telemetry.os_pretty_name || 'unknown',
                            wsl_distro: telemetry.wsl_distro || 'none',
                            full_os: telemetry.os || 'unknown'
                        },
                        governanceInfo: {
                            username: telemetry.username,
                            machine_id: telemetry.machine_id,
                            ci_env: telemetry.ci_env
                        },
                        complianceStatus: {
                            bundleVersion: telemetry.bundle_version || 'unknown',
                            latestVersion: '1.5.5',
                            requiresUpdate: (telemetry.bundle_version || 'unknown') !== '1.5.5'
                        }
                    };

                    console.log('Consolidated Telemetry (Chuck):', JSON.stringify(logEntry, null, 2));
                } catch (e) {
                    console.error('Failed to parse telemetry JSON:', e.message);
                }
            }

            res.statusCode = 200;
            res.setHeader('Content-Type', 'application/json');
            const policy = {
                latest_version: '1.5.5',
                release_date: '2026-01-01',
                grace_period_days: 15,
                message: 'Chuck Policy check successful'
            };
            res.end(JSON.stringify(policy));
        });
    } else if (req.method === 'GET' && req.url === '/artifacts/chuck-bundle.tar.gz') {
        const filePath = path.join(__dirname, '../public/artifacts/chuck-bundle.tar.gz');

        fs.stat(filePath, (err, stats) => {
            if (err || !stats.isFile()) {
                console.error('Artifact not found:', filePath);
                res.statusCode = 404;
                res.setHeader('Content-Type', 'text/plain');
                res.end('Not Found');
                return;
            }

            res.statusCode = 200;
            res.setHeader('Content-Type', 'application/gzip');
            res.setHeader('Content-Length', stats.size);

            const readStream = fs.createReadStream(filePath);
            readStream.pipe(res);
        });
    } else if ((req.method === 'GET' || req.method === 'HEAD') && req.url === '/artifacts/chuck-bundle/latest') {
        const artifactsDir = path.join(__dirname, '../public/artifacts');
        const latestBundle = getLatestBundle(artifactsDir);

        if (!latestBundle) {
            res.statusCode = 404;
            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({
                error: 'No versioned bundles found',
                message: 'No chuck-bundle-*.tar.gz files found in artifacts directory',
                suggestion: 'Build a bundle using: build-chuck-bundle.sh <version>'
            }));
            return;
        }

        fs.stat(latestBundle.filepath, (err, stats) => {
            if (err || !stats.isFile()) {
                console.error('Latest bundle file not accessible:', latestBundle.filepath);
                res.statusCode = 500;
                res.setHeader('Content-Type', 'application/json');
                res.end(JSON.stringify({
                    error: 'Bundle access error',
                    message: 'Latest bundle found but cannot be read'
                }));
                return;
            }

            console.log(`Serving latest bundle: ${latestBundle.filename} (v${latestBundle.version})`);

            res.statusCode = 200;
            res.setHeader('Content-Type', 'application/gzip');
            res.setHeader('Content-Disposition', `attachment; filename="${latestBundle.filename}"`);
            res.setHeader('Content-Length', stats.size);
            res.setHeader('X-Bundle-Version', latestBundle.version);
            res.setHeader('Cache-Control', 'no-cache, must-revalidate');

            // For HEAD requests, send headers only; for GET, send body
            if (req.method === 'HEAD') {
                res.end();
            } else {
                const readStream = fs.createReadStream(latestBundle.filepath);
                readStream.pipe(res);
            }
        });
    } else {
        res.statusCode = 404;
        res.setHeader('Content-Type', 'text/plain');
        res.end('Not Found\n');
    }
});

server.listen(port, hostname, () => {
    console.log(`Policy server running at http://${hostname}:${port}/`);
});
