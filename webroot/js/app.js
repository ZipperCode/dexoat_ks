// Dex2Oat Manager - Main Application JavaScript
// OPTIMIZED with better error handling and debugging

// Module paths
const MODULE_DIR = '/data/adb/modules/dexoat_ks';
const SCRIPTS_DIR = `${MODULE_DIR}/scripts`;
const CONFIGS_DIR = `${MODULE_DIR}/configs`;
const LOGS_DIR = `${MODULE_DIR}/logs`;

// Global state
let allApps = [];
let filteredApps = [];
let selectedApps = new Set();
let currentTab = 'dashboard';
let currentPage = 1;
let pageSize = 50;
let isLoading = false;
let execAvailable = false;

// Utility functions
function showToast(message, duration = 3000) {
    const toast = document.getElementById('toast');
    if (toast) {
        toast.textContent = message;
        toast.classList.add('show');
        setTimeout(() => {
            toast.classList.remove('show');
        }, duration);
    } else {
        console.log('TOAST:', message);
    }
}

function logDebug(message) {
    console.log(`[DEBUG] ${message}`);
}

function logError(message) {
    console.error(`[ERROR] ${message}`);
    showToast(message);
}

async function execCommand(command) {
    logDebug(`Executing: ${command}`);

    try {
        if (!window.exec || typeof window.exec !== 'function') {
            logError('exec function not available');
            return { errno: -1, stdout: '', stderr: 'exec not available' };
        }

        const result = await window.exec(command);

        if (result.errno !== 0) {
            logError(`Command failed: ${result.stderr || result.stdout || 'Unknown error'}`);
        }

        return result;
    } catch (error) {
        logError(`Command exception: ${error.message}`);
        return { errno: -1, stdout: '', stderr: error.message };
    }
}

// Debounce function for search
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Tab switching
document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
        const tabName = tab.dataset.tab;

        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        tab.classList.add('active');

        document.querySelectorAll('.tab-content').forEach(content => {
            content.classList.remove('active');
        });
        document.getElementById(tabName).classList.add('active');

        currentTab = tabName;

        // Lazy load tab data
        if (tabName === 'dashboard') loadDashboard();
        if (tabName === 'apps') loadApps();
        if (tabName === 'schedule') loadSchedule();
        if (tabName === 'config') loadConfig();
        if (tabName === 'logs') loadLogs();
    });
});

// Dashboard functions
async function loadDashboard() {
    try {
        document.getElementById('total-apps').textContent = '...';
        document.getElementById('compiled-apps').textContent = '...';
        document.getElementById('needs-recompile').textContent = '...';
        document.getElementById('pending-apps').textContent = '...';

        const result = await execCommand(`sh ${SCRIPTS_DIR}/get_apps.sh`);

        logDebug(`get_apps.sh result: errno=${result.errno}, stdout length=${result.stdout?.length || 0}`);

        if (result.errno !== 0) {
            logError('Failed to load dashboard data');
            return;
        }

        if (!result.stdout || result.stdout.trim() === '') {
            logError('Empty response from get_apps.sh');
            return;
        }

        let data;
        try {
            data = JSON.parse(result.stdout);
        } catch (e) {
            logError(`JSON parse error: ${e.message}`);
            logDebug(`Response: ${result.stdout.substring(0, 200)}...`);
            return;
        }

        allApps = data.apps || [];

        // Update stats
        const total = allApps.length;
        const compiled = allApps.filter(a => a.isCompiled === true || a.isCompiled === 'true').length;
        const needsRecompile = allApps.filter(a => a.needsRecompile === true || a.needsRecompile === 'true').length;
        const pending = total - compiled;

        document.getElementById('total-apps').textContent = total;
        document.getElementById('compiled-apps').textContent = compiled;
        document.getElementById('needs-recompile').textContent = needsRecompile;
        document.getElementById('pending-apps').textContent = pending;

        await loadScheduleInfo();

        logDebug(`Dashboard loaded: ${total} apps`);
    } catch (error) {
        logError(`Error loading dashboard: ${error.message}`);
    }
}

async function loadScheduleInfo() {
    try {
        const result = await execCommand(`cat ${CONFIGS_DIR}/dexoat.conf`);
        if (result.errno === 0) {
            const lines = result.stdout.split('\n');
            const scheduleLine = lines.find(l => l.startsWith('schedule='));
            const enabledLine = lines.find(l => l.startsWith('schedule_enabled='));

            const schedule = scheduleLine ? scheduleLine.split('=')[1] : 'Not set';
            const enabled = enabledLine ? enabledLine.split('=')[1] : 'false';

            const scheduleDisplay = document.getElementById('schedule-display');
            const schedulerStatus = document.getElementById('scheduler-status');

            if (scheduleDisplay) scheduleDisplay.textContent = `${schedule} (${enabled === 'true' ? 'Enabled' : 'Disabled'})`;
            if (schedulerStatus) schedulerStatus.textContent = enabled === 'true' ? 'Running' : 'Disabled';
        }
    } catch (error) {
        logError(`Error loading schedule info: ${error.message}`);
    }
}

// Apps functions with pagination
async function loadApps() {
    if (isLoading) return;
    isLoading = true;

    try {
        const container = document.getElementById('apps-list');
        if (container) {
            container.innerHTML = '<p class="loading">Loading apps (this may take a moment)...</p>';
        }

        const result = await execCommand(`sh ${SCRIPTS_DIR}/get_apps.sh`);

        logDebug(`loadApps result: errno=${result.errno}`);

        if (result.errno !== 0) {
            if (container) {
                container.innerHTML = `<p class="loading" style="color: var(--danger-color)">Failed to load apps<br><small>${result.stderr || 'Unknown error'}</small></p>`;
            }
            isLoading = false;
            return;
        }

        if (!result.stdout || result.stdout.trim() === '') {
            if (container) {
                container.innerHTML = '<p class="loading">No data received from server</p>';
            }
            isLoading = false;
            return;
        }

        let data;
        try {
            data = JSON.parse(result.stdout);
        } catch (e) {
            logError(`JSON parse error: ${e.message}`);
            logDebug(`Response: ${result.stdout.substring(0, 500)}...`);
            if (container) {
                container.innerHTML = `<p class="loading" style="color: var(--danger-color)">Failed to parse app data<br><small>${e.message}</small></p>`;
            }
            isLoading = false;
            return;
        }

        allApps = data.apps || [];

        showToast(`Loaded ${allApps.length} apps`);
        logDebug(`Loaded ${allApps.length} apps`);

        filterAndRenderApps();
    } catch (error) {
        logError(`Error loading apps: ${error.message}`);
        if (document.getElementById('apps-list')) {
            document.getElementById('apps-list').innerHTML = `<p class="loading" style="color: var(--danger-color)">Error: ${error.message}</p>`;
        }
    } finally {
        isLoading = false;
    }
}

function filterAndRenderApps() {
    const searchTerm = document.getElementById('search-apps')?.value.toLowerCase() || '';
    const filter = document.getElementById('filter-apps')?.value || 'all';

    // Filter apps
    filteredApps = allApps;

    if (searchTerm) {
        filteredApps = filteredApps.filter(app =>
            app.packageName.toLowerCase().includes(searchTerm)
        );
    }

    switch (filter) {
        case 'user':
            filteredApps = filteredApps.filter(app => app.isSystem === false || app.isSystem === 'false');
            break;
        case 'system':
            filteredApps = filteredApps.filter(app => app.isSystem === true || app.isSystem === 'true');
            break;
        case 'compiled':
            filteredApps = filteredApps.filter(app => app.isCompiled === true || app.isCompiled === 'true');
            break;
        case 'uncompiled':
            filteredApps = filteredApps.filter(app => app.isCompiled === false || app.isCompiled === 'false');
            break;
        case 'needs-recompile':
            filteredApps = filteredApps.filter(app => app.needsRecompile === true || app.needsRecompile === 'true');
            break;
    }

    // Reset to page 1
    currentPage = 1;
    renderPage();
    updatePagination();
}

function renderPage() {
    const start = (currentPage - 1) * pageSize;
    const end = start + pageSize;
    const pageApps = filteredApps.slice(start, end);

    renderAppsList(pageApps);
}

function renderAppsList(appsToRender) {
    const container = document.getElementById('apps-list');

    if (!container) return;

    if (appsToRender.length === 0) {
        container.innerHTML = '<p class="loading">No apps found</p>';
        return;
    }

    container.innerHTML = appsToRender.map(app => `
        <div class="app-card ${selectedApps.has(app.packageName) ? 'selected' : ''}">
            <input type="checkbox"
                   class="app-checkbox"
                   data-package="${app.packageName}"
                   ${selectedApps.has(app.packageName) ? 'checked' : ''}>
            <div class="app-icon">📱</div>
            <div class="app-info">
                <div class="app-name">${escapeHtml(app.packageName)}</div>
            </div>
            <div class="app-status">
                ${getStatusBadge(app)}
            </div>
            <div class="app-actions">
                <button class="btn btn-sm btn-secondary"
                        onclick="window.compileApp('${app.packageName}', '${app.desiredMode}')">
                    Compile
                </button>
            </div>
        </div>
    `).join('');

    // Add event listeners to checkboxes
    container.querySelectorAll('.app-checkbox').forEach(checkbox => {
        checkbox.addEventListener('change', (e) => {
            const package = e.target.dataset.package;
            if (e.target.checked) {
                selectedApps.add(package);
            } else {
                selectedApps.delete(package);
            }
            updateSelectionCount();
        });
    });
}

function getStatusBadge(app) {
    const isCompiled = app.isCompiled === true || app.isCompiled === 'true';
    const needsRecompile = app.needsRecompile === true || app.needsRecompile === 'true';

    if (needsRecompile) {
        return '<span class="status-badge status-needs-recompile">Needs Recompile</span>';
    }
    if (isCompiled) {
        return '<span class="status-badge status-compiled">Compiled</span>';
    }
    return '<span class="status-badge status-uncompiled">Uncompiled</span>';
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function updatePagination() {
    const totalPages = Math.ceil(filteredApps.length / pageSize);
    const pageInfo = document.getElementById('page-info');
    const prevBtn = document.getElementById('prev-page');
    const nextBtn = document.getElementById('next-page');

    if (pageInfo) pageInfo.textContent = `Page ${currentPage} of ${totalPages || 1}`;
    if (prevBtn) prevBtn.disabled = currentPage <= 1;
    if (nextBtn) nextBtn.disabled = currentPage >= (totalPages || 1);
}

function updateSelectionCount() {
    const countEl = document.getElementById('selection-count');
    if (countEl) {
        countEl.textContent = `${selectedApps.size} selected`;
    }
}

// Pagination controls
document.getElementById('prev-page')?.addEventListener('click', () => {
    if (currentPage > 1) {
        currentPage--;
        renderPage();
        updatePagination();
    }
});

document.getElementById('next-page')?.addEventListener('click', () => {
    const totalPages = Math.ceil(filteredApps.length / pageSize);
    if (currentPage < totalPages) {
        currentPage++;
        renderPage();
        updatePagination();
    }
});

document.getElementById('page-size')?.addEventListener('change', (e) => {
    pageSize = parseInt(e.target.value);
    currentPage = 1;
    renderPage();
    updatePagination();
});

// Filter and search with debounce
document.getElementById('search-apps')?.addEventListener('input',
    debounce(() => filterAndRenderApps(), 300)
);

document.getElementById('filter-apps')?.addEventListener('change', () => filterAndRenderApps());

// Select all on current page
document.getElementById('select-all-apps')?.addEventListener('change', (e) => {
    const start = (currentPage - 1) * pageSize;
    const end = start + pageSize;
    const pageApps = filteredApps.slice(start, end);

    pageApps.forEach(app => {
        if (e.target.checked) {
            selectedApps.add(app.packageName);
        } else {
            selectedApps.delete(app.packageName);
        }
    });

    renderPage();
    updateSelectionCount();
});

// Compile app
window.compileApp = async function(packageName, mode) {
    showToast(`Compiling ${packageName}...`);
    logDebug(`Compiling ${packageName} with mode ${mode}`);

    const result = await execCommand(`sh ${SCRIPTS_DIR}/compile_app.sh '${packageName}' '${mode}'`);

    if (result.errno === 0) {
        showToast(`Successfully compiled ${packageName}`);
        logDebug(`Compiled ${packageName} successfully`);
    } else {
        showToast(`Failed to compile ${packageName}`);
        logError(`Failed to compile ${packageName}: ${result.stderr || result.stdout}`);
    }
};

// Compile selected
document.getElementById('compile-selected')?.addEventListener('click', async () => {
    if (selectedApps.size === 0) {
        showToast('No apps selected');
        return;
    }

    if (!confirm(`Compile ${selectedApps.size} selected apps?`)) {
        return;
    }

    showToast('Compiling selected apps...');
    const defaultMode = document.getElementById('default-mode')?.value || 'speed';

    let compiled = 0;
    let failed = 0;

    for (const package of selectedApps) {
        const result = await execCommand(`sh ${SCRIPTS_DIR}/compile_app.sh '${package}' '${defaultMode}'`);
        if (result.errno === 0) {
            compiled++;
        } else {
            failed++;
        }
    }

    showToast(`Compiled: ${compiled}, Failed: ${failed}`);
    selectedApps.clear();
    updateSelectionCount();
});

// Compile all
document.getElementById('compile-all')?.addEventListener('click', async () => {
    if (!confirm('Compile all uncompiled apps? This may take a while.')) {
        return;
    }

    showToast('Starting batch compilation...');
    logDebug('Starting batch compilation');

    const result = await execCommand(`sh ${SCRIPTS_DIR}/compile_all.sh manual`);

    if (result.errno === 0) {
        showToast('Compilation started');
        logDebug('Compilation started successfully');
    } else {
        showToast('Failed to start compilation');
        logError(`Failed to start compilation: ${result.stderr || result.stdout}`);
    }
});

// Schedule functions
async function loadSchedule() {
    try {
        const result = await execCommand(`cat ${CONFIGS_DIR}/dexoat.conf`);
        if (result.errno === 0) {
            const lines = result.stdout.split('\n');

            const schedule = lines.find(l => l.startsWith('schedule='))?.split('=')[1] || '0 2 * * *';
            const enabled = lines.find(l => l.startsWith('schedule_enabled='))?.split('=')[1] || 'false';
            const compileOnBoot = lines.find(l => l.startsWith('compile_on_boot='))?.split('=')[1] || 'true';

            document.getElementById('schedule-cron').value = schedule;
            document.getElementById('schedule-enabled').checked = enabled === 'true';
        }
    } catch (error) {
        logError(`Error loading schedule: ${error.message}`);
    }
}

document.getElementById('save-schedule')?.addEventListener('click', async () => {
    const cron = document.getElementById('schedule-cron')?.value || '0 2 * * *';
    const enabled = document.getElementById('schedule-enabled')?.checked;

    await execCommand(`sed -i 's/^schedule=.*/schedule=${cron}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^schedule_enabled=.*/schedule_enabled=${enabled}/' ${CONFIGS_DIR}/dexoat.conf`);

    showToast('Schedule saved');
    logDebug('Schedule saved');

    await execCommand('pkill -f dexoat_ks');
    await execCommand(`sh ${MODULE_DIR}/service.sh &`);

    loadScheduleInfo();
});

document.getElementById('trigger-now')?.addEventListener('click', async () => {
    if (!confirm('Trigger scheduled compilation now?')) {
        return;
    }

    showToast('Starting scheduled compilation...');
    await execCommand(`sh ${SCRIPTS_DIR}/compile_all.sh scheduled`);
    showToast('Compilation started');
});

// Config functions
async function loadConfig() {
    try {
        const result = await execCommand(`cat ${CONFIGS_DIR}/dexoat.conf`);
        if (result.errno === 0) {
            const lines = result.stdout.split('\n');

            const defaultMode = lines.find(l => l.startsWith('default_mode='))?.split('=')[1] || 'speed';
            const skipCompiled = lines.find(l => l.startsWith('skip_compiled='))?.split('=')[1] || 'true';
            const detectModeReset = lines.find(l => l.startsWith('detect_mode_reset='))?.split('=')[1] || 'true';
            const compileOnBoot = lines.find(l => l.startsWith('compile_on_boot='))?.split('=')[1] || 'true';
            const logLevel = lines.find(l => l.startsWith('log_level='))?.split('=')[1] || 'INFO';
            const parallelJobs = lines.find(l => l.startsWith('parallel_jobs='))?.split('=')[1] || '2';

            document.getElementById('default-mode').value = defaultMode;
            document.getElementById('skip-compiled').checked = skipCompiled === 'true';
            document.getElementById('detect-mode-reset').checked = detectModeReset === 'true';
            document.getElementById('compile-on-boot').checked = compileOnBoot === 'true';
            document.getElementById('log-level').value = logLevel;
            document.getElementById('parallel-jobs').value = parallelJobs;
        }
    } catch (error) {
        logError(`Error loading config: ${error.message}`);
    }
}

document.getElementById('save-config')?.addEventListener('click', async () => {
    const defaultMode = document.getElementById('default-mode')?.value || 'speed';
    const skipCompiled = document.getElementById('skip-compiled')?.checked;
    const detectModeReset = document.getElementById('detect-mode-reset')?.checked;
    const compileOnBoot = document.getElementById('compile-on-boot')?.checked;
    const logLevel = document.getElementById('log-level')?.value || 'INFO';
    const parallelJobs = document.getElementById('parallel-jobs')?.value || '2';

    await execCommand(`sed -i 's/^default_mode=.*/default_mode=${defaultMode}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^skip_compiled=.*/skip_compiled=${skipCompiled}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^detect_mode_reset=.*/detect_mode_reset=${detectModeReset}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^compile_on_boot=.*/compile_on_boot=${compileOnBoot}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^log_level=.*/log_level=${logLevel}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^parallel_jobs=.*/parallel_jobs=${parallelJobs}/' ${CONFIGS_DIR}/dexoat.conf`);

    showToast('Configuration saved');
    logDebug('Configuration saved');

    await execCommand('pkill -f dexoat_ks');
    await execCommand(`sh ${MODULE_DIR}/service.sh &`);
});

document.getElementById('un-compile-all')?.addEventListener('click', async () => {
    if (!confirm('This will remove ALL compilations. Apps will run slower. Continue?')) {
        return;
    }

    const result = await execCommand(`echo yes | sh ${SCRIPTS_DIR}/un_compile_all.sh`);

    if (result.errno === 0) {
        showToast('All compilations removed. Reboot recommended.');
    } else {
        showToast('Failed to remove compilations');
    }
});

// Logs functions
async function loadLogs() {
    try {
        const filter = document.getElementById('log-level-filter')?.value || 'all';
        let lines = 50;

        const result = await execCommand(`tail -n ${lines} ${LOGS_DIR}/dexoat.log 2>/dev/null || echo "No logs available"`);

        let logs = result.stdout;

        if (filter !== 'all') {
            const logLines = logs.split('\n');
            const levels = {
                'ERROR': ['ERROR'],
                'WARN': ['ERROR', 'WARN'],
                'INFO': ['ERROR', 'WARN', 'INFO']
            };

            const allowedLevels = levels[filter] || [];
            logs = logLines.filter(line =>
                allowedLevels.some(level => line.includes(`[${level}]`))
            ).join('\n');
        }

        logs = logs.replace(/\[(ERROR)\]/g, '<span class="log-ERROR">[$1]</span>');
        logs = logs.replace(/\[(WARN)\]/g, '<span class="log-WARN">[$1]</span>');
        logs = logs.replace(/\[(INFO)\]/g, '<span class="log-INFO">[$1]</span>');
        logs = logs.replace(/\[(DEBUG)\]/g, '<span class="log-DEBUG">[$1]</span>');

        document.getElementById('logs-content').innerHTML = logs;
    } catch (error) {
        logError(`Error loading logs: ${error.message}`);
        document.getElementById('logs-content').textContent = `Error loading logs: ${error.message}`;
    }
}

document.getElementById('refresh-logs')?.addEventListener('click', loadLogs);
document.getElementById('log-level-filter')?.addEventListener('change', loadLogs);

document.getElementById('clear-logs')?.addEventListener('click', async () => {
    if (!confirm('Clear all logs?')) {
        return;
    }

    await execCommand(`> ${LOGS_DIR}/dexoat.log`);
    showToast('Logs cleared');
    loadLogs();
});

document.getElementById('download-logs')?.addEventListener('click', async () => {
    const result = await execCommand(`cat ${LOGS_DIR}/dexoat.log`);

    if (result.errno === 0) {
        const blob = new Blob([result.stdout], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `dexoat-${new Date().toISOString()}.log`;
        a.click();
        URL.revokeObjectURL(url);
        showToast('Log downloaded');
    } else {
        showToast('Failed to download logs');
    }
});

// Refresh buttons
document.getElementById('refresh-dashboard')?.addEventListener('click', loadDashboard);
document.getElementById('refresh-apps')?.addEventListener('click', loadApps);

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    logDebug('DOM Content Loaded');

    // Check if exec is available
    if (window.exec && typeof window.exec === 'function') {
        execAvailable = true;
        logDebug('exec function is available');
        loadDashboard();
    } else {
        logError('exec function not available - KernelSU API may not be loaded');
        showToast('KernelSU API not available');
    }

    // Make compileApp global
    window.compileApp = compileApp;
});
