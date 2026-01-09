const http = require('http');

const hostname = '0.0.0.0';
const port = 3000;

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
                    console.log('Telemetry received (Chuck):', JSON.stringify(telemetry, null, 2));
                } catch (e) {
                    console.error('Failed to parse telemetry JSON:', e.message);
                }
            }
            
            res.statusCode = 200;
            res.setHeader('Content-Type', 'application/json');
            // Assuming Chuck follows similar versioning for this mock
            const policy = {
                latest_version: '1.5.0',
                release_date: '2026-01-01',
                grace_period_days: 15,
                message: 'Chuck Policy check successful'
            };
            res.end(JSON.stringify(policy));
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
