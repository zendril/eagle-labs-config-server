const http = require('http');
const fs = require('fs');
const path = require('path');

const hostname = '0.0.0.0';
const port = 3000;

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

function getLatestBundle(artifactsDir) {
    try {
        const files = fs.readdirSync(artifactsDir);
        const bundles = [];
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
        if (bundles.length === 0) return null;
        bundles.sort((a, b) => compareSemVer(b.version, a.version));
        return bundles[0];
    } catch (err) {
        return null;
    }
}


const server = http.createServer((req, res) => {
    console.log(`Received request: ${req.method} ${req.url}`);

    const readBody = (callback) => {
        let body = '';
        req.on('data', chunk => { body += chunk.toString(); });
        req.on('end', () => { callback(body); });
    };

    if (req.method === 'GET' && req.url === '/health') {
        res.statusCode = 200;
        res.setHeader('Content-Type', 'text/plain');
        res.end('OK');
    } else if (req.method === 'POST' && req.url === '/policy/batch-check') {
        readBody((data) => {
            try {
                const telemetry = JSON.parse(data);
                console.log('--- WARDEN BATCH TELEMETRY ---');
                console.log(JSON.stringify(telemetry, null, 2));

                const features = telemetry.features || [];
                let status = 'PASS';
                let message = 'All features compliant.';
                let statusCode = 200;

                const chuck = features.find(f => f.name === 'chuck');
                if (chuck && chuck.version === '1.5.2') {
                    status = 'BLOCK';
                    message = 'CRITICAL: Chuck v1.5.2 has a known security vulnerability. Rebuild required.';
                    statusCode = 403;
                }

                res.statusCode = statusCode;
                res.setHeader('Content-Type', 'application/json');
                res.end(JSON.stringify({
                    status: status,
                    message: message,
                    server_time: new Date().toISOString()
                }));
            } catch (e) {
                res.statusCode = 400;
                res.end('Invalid JSON');
            }
        });
    }


    else if (req.url === '/policy/reggie/latest') {
        readBody((data) => {
            res.statusCode = 200;
            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ latest_version: '2', message: 'Legacy Reggie Policy' }));
        });
    } else if (req.url === '/policy/chuck/latest') {
        readBody((data) => {
            res.statusCode = 200;
            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ latest_version: '1.5.5', message: 'Legacy Chuck Policy' }));
        });
    } else if (req.method === 'GET' && req.url === '/artifacts/chuck-bundle.tar.gz') {
        const filePath = path.join(__dirname, '../public/artifacts/chuck-bundle.tar.gz');
        fs.stat(filePath, (err, stats) => {
            if (err || !stats.isFile()) {
                res.statusCode = 404;
                res.end('Not Found');
                return;
            }
            res.statusCode = 200;
            res.setHeader('Content-Type', 'application/gzip');
            fs.createReadStream(filePath).pipe(res);
        });
    } else if ((req.method === 'GET' || req.method === 'HEAD') && req.url === '/artifacts/chuck-bundle/latest') {
        const artifactsDir = path.join(__dirname, '../public/artifacts');
        const latestBundle = getLatestBundle(artifactsDir);
        if (!latestBundle) {
            res.statusCode = 404;
            res.end('Not Found');
            return;
        }
        res.statusCode = 200;
        res.setHeader('Content-Type', 'application/gzip');
        res.setHeader('X-Bundle-Version', latestBundle.version);
        if (req.method === 'GET') {
            fs.createReadStream(latestBundle.filepath).pipe(res);
        } else {
            res.end();
        }
    } else {
        res.statusCode = 404;
        res.end('Not Found');
    }
});

server.listen(port, hostname, () => {
    console.log(`Policy Server running at http://${hostname}:${port}/`);
});

