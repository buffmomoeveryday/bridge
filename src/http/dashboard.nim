const DASHBOARD_HTML* = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bridge Dashboard</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg: #0a0a0c;
            --panel: #16161a;
            --primary: #6366f1;
            --accent: #818cf8;
            --text: #f0f0f5;
            --text-dim: #94a3b8;
            --border: rgba(255, 255, 255, 0.08);
            --success: #10b981;
            --error: #ef4444;
            --warning: #f59e0b;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Inter', sans-serif;
        }

        body {
            background-color: var(--bg);
            color: var(--text);
            display: flex;
            height: 100vh;
            overflow: hidden;
        }

        /* Sidebar */
        aside {
            width: 260px;
            background: var(--panel);
            border-right: 1px solid var(--border);
            display: flex;
            flex-direction: column;
            padding: 24px;
        }

        .logo {
            font-size: 24px;
            font-weight: 700;
            letter-spacing: -1px;
            margin-bottom: 40px;
            background: linear-gradient(135deg, var(--primary), var(--accent));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        nav button {
            width: 100%;
            background: transparent;
            border: none;
            color: var(--text-dim);
            padding: 12px 16px;
            text-align: left;
            border-radius: 8px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            margin-bottom: 8px;
            transition: all 0.2s;
        }

        nav button.active {
            background: rgba(99, 102, 241, 0.1);
            color: var(--primary);
        }

        nav button:hover:not(.active) {
            background: rgba(255, 255, 255, 0.03);
            color: var(--text);
        }

        /* Main Content */
        main {
            flex: 1;
            display: flex;
            flex-direction: column;
            padding: 32px;
            overflow-y: auto;
        }

        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 32px;
        }

        h1 { font-size: 24px; font-weight: 700; }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 32px;
        }

        .stat-card {
            background: var(--panel);
            padding: 24px;
            border-radius: 16px;
            border: 1px solid var(--border);
        }

        .stat-label { color: var(--text-dim); font-size: 13px; margin-bottom: 8px; }
        .stat-value { font-size: 28px; font-weight: 700; }

        /* Tables & Lists */
        .content-card {
            background: var(--panel);
            border-radius: 16px;
            border: 1px solid var(--border);
            overflow: hidden;
            flex: 1;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            text-align: left;
            font-size: 14px;
        }

        th {
            background: rgba(255, 255, 255, 0.02);
            padding: 16px;
            color: var(--text-dim);
            font-weight: 600;
            border-bottom: 1px solid var(--border);
        }

        td {
            padding: 16px;
            border-bottom: 1px solid var(--border);
        }

        tr:hover { background: rgba(255, 255, 255, 0.01); }

        .tag {
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
        }

        .tag-get { background: rgba(16, 185, 129, 0.1); color: var(--success); }
        .tag-post { background: rgba(99, 102, 241, 0.1); color: var(--primary); }
        .tag-put { background: rgba(245, 158, 11, 0.1); color: var(--warning); }
        .tag-delete { background: rgba(239, 68, 68, 0.1); color: var(--error); }

        .json-viewer {
            background: #000;
            padding: 20px;
            border-radius: 12px;
            font-family: monospace;
            white-space: pre-wrap;
            font-size: 13px;
            color: #d1d1d1;
            line-height: 1.6;
            max-height: 600px;
            overflow-y: auto;
        }

        /* Animations */
        @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
        .animate-fade { animation: fadeIn 0.4s ease-out forwards; }
    </style>
</head>
<body>
    <aside>
        <div class="logo">BRIDGE</div>
        <nav id="sidebar-nav">
            <button class="active" onclick="switchTab('logs')">Live Logs</button>
            <button onclick="switchTab('store')">State Store</button>
            <button onclick="switchTab('config')">Active Config</button>
        </nav>
    </aside>

    <main>
        <header>
            <h1 id="tab-title">Live Request Logs</h1>
            <div id="status-dot">
                <span style="color: var(--success)">● Live</span>
            </div>
        </header>

        <section id="logs-view">
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-label">Total Requests</div>
                    <div class="stat-value" id="stat-total-req">0</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Uptime</div>
                    <div class="stat-value" id="stat-uptime">0s</div>
                </div>
            </div>
            <div class="content-card">
                <table>
                    <thead>
                        <tr>
                            <th>Method</th>
                            <th>Path</th>
                            <th>Status</th>
                            <th>Time</th>
                        </tr>
                    </thead>
                    <tbody id="log-body">
                        <!-- Logs here -->
                    </tbody>
                </table>
            </div>
        </section>

        <section id="store-view" style="display: none;">
            <div class="content-card">
                <table>
                    <thead>
                        <tr>
                            <th>Key</th>
                            <th>Value</th>
                        </tr>
                    </thead>
                    <tbody id="store-body">
                        <!-- Store here -->
                    </tbody>
                </table>
            </div>
        </section>

        <section id="config-view" style="display: none;">
            <div class="json-viewer" id="config-viewer">
                <!-- Config here -->
            </div>
        </section>
    </main>

    <script>
        let currentTab = 'logs';
        let logs = [];
        let startTime = Date.now();

        function switchTab(tab) {
            currentTab = tab;
            document.querySelectorAll('nav button').forEach(b => b.classList.remove('active'));
            event.target.classList.add('active');
            
            document.getElementById('logs-view').style.display = tab === 'logs' ? 'block' : 'none';
            document.getElementById('store-view').style.display = tab === 'store' ? 'block' : 'none';
            document.getElementById('config-view').style.display = tab === 'config' ? 'block' : 'none';
            
            document.getElementById('tab-title').innerText = 
                tab === 'logs' ? 'Live Request Logs' : 
                tab === 'store' ? 'In-Memory Store' : 'Active Contract';

            fetchData();
        }

        function setupSSE() {
            const evtSource = new EventSource('/_bridge/events');
            
            evtSource.onmessage = function(event) {
                const data = JSON.parse(event.data);
                if (data.type === 'logs') {
                    updateLogs(data.payload);
                } else if (data.type === 'store') {
                    updateStore(data.payload);
                }
            };

            evtSource.onerror = function(err) {
                console.error("EventSource failed:", err);
                document.getElementById('status-dot').innerHTML = '<span style="color: var(--error)">● Disconnected</span>';
            };

            evtSource.onopen = function() {
                document.getElementById('status-dot').innerHTML = '<span style="color: var(--success)">● Live (SSE)</span>';
            };
        }

        async function fetchConfig() {
            const resConfig = await fetch('/_bridge/data/config');
            const configTxt = await resConfig.text();
            document.getElementById('config-viewer').innerText = configTxt;
        }

        function updateLogs(data) {
            const body = document.getElementById('log-body');
            body.innerHTML = '';
            document.getElementById('stat-total-req').innerText = data.length;
            
            // Clone and reverse for display
            const sorted = [...data].reverse();
            sorted.forEach(log => {
                const tr = document.createElement('tr');
                tr.className = 'animate-fade';
                const methClass = 'tag tag-' + log.method.toLowerCase();
                tr.innerHTML = `
                    <td><span class="${methClass}">${log.method}</span></td>
                    <td><code>${log.path}</code></td>
                    <td style="color: ${log.status >= 400 ? 'var(--error)' : 'var(--success)'}">${log.status}</td>
                    <td style="color: var(--text-dim); font-size: 12px">${log.time}</td>
                `;
                body.appendChild(tr);
            });
        }

        function updateStore(data) {
            const body = document.getElementById('store-body');
            body.innerHTML = '';
            Object.keys(data).forEach(key => {
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td style="font-weight: 600; color: var(--primary)">${key}</td>
                    <td><code style="color: var(--text-dim)">${data[key]}</code></td>
                `;
                body.appendChild(tr);
            });
        }

        // Initial fetch for everything
        async function initialLoad() {
            const resL = await fetch('/_bridge/data/logs');
            updateLogs(await resL.json());
            const resS = await fetch('/_bridge/data/store');
            updateStore(await resS.json());
            fetchConfig();
            setupSSE();
        }

        setInterval(() => {
            document.getElementById('stat-uptime').innerText = Math.floor((Date.now() - startTime) / 1000) + 's';
        }, 1000);

        initialLoad();
    </script>
</body>
</html>
"""
