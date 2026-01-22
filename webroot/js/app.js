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
let 已选择Apps = new Set();
let currentTab = 'dashboard';
let currentPage = 1;
let pageSize = 50;
let isLoading = false;
let execAvailable = false;

// Track loaded state for each tab
let tabLoaded = {
    dashboard: false,
    apps: false,
    schedule: false,
    config: false,
    logs: false
};

// Track loading state to prevent concurrent loads
let tabLoading = {
    dashboard: false,
    apps: false,
    schedule: false,
    config: false,
    logs: false
};

// Track last load time for each tab (to avoid too frequent refresh)
let tabLoadTime = {
    dashboard: 0,
    apps: 0,
    schedule: 0,
    config: 0,
    logs: 0
};

// Minimum time between background refreshes (30 seconds)
const BACKGROUND_REFRESH_INTERVAL = 30000;

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
    console.error(`[错误] ${message}`);
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

        const now = Date.now();

        // Lazy load tab data - only load if not loaded yet
        // First time: load immediately, subsequent times: load in background if enough time passed
        if (tabName === 'dashboard') {
            if (!tabLoaded.dashboard) {
                loadDashboard();
            } else if (!tabLoading.dashboard && (now - tabLoadTime.dashboard > BACKGROUND_REFRESH_INTERVAL)) {
                // Background refresh only if 30 seconds have passed
                loadDashboard(true);
            }
        }
        if (tabName === 'apps') {
            if (!tabLoaded.apps) {
                loadApps();
            } else if (!tabLoading.apps && (now - tabLoadTime.apps > BACKGROUND_REFRESH_INTERVAL)) {
                // Background refresh only if 30 seconds have passed
                loadApps(true);
            }
        }
        if (tabName === 'schedule') {
            if (!tabLoaded.schedule) {
                loadSchedule();
            } else if (!tabLoading.schedule && (now - tabLoadTime.schedule > BACKGROUND_REFRESH_INTERVAL)) {
                // Background refresh only if 30 seconds have passed
                loadSchedule(true);
            }
        }
        if (tabName === 'config') {
            if (!tabLoaded.config) {
                loadConfig();
            } else if (!tabLoading.config && (now - tabLoadTime.config > BACKGROUND_REFRESH_INTERVAL)) {
                // Background refresh only if 30 seconds have passed
                loadConfig(true);
            }
        }
        if (tabName === 'logs') {
            if (!tabLoaded.logs) {
                loadLogs();
            } else if (!tabLoading.logs && (now - tabLoadTime.logs > BACKGROUND_REFRESH_INTERVAL)) {
                // Background refresh only if 30 seconds have passed
                loadLogs(true);
            }
        }
    });
});

// Dashboard functions
async function loadDashboard(background = false) {
    // Prevent concurrent loads
    if (tabLoading.dashboard) return;
    tabLoading.dashboard = true;

    try {
        if (!background) {
            document.getElementById('total-apps').textContent = '...';
            document.getElementById('compiled-apps').textContent = '...';
            document.getElementById('needs-recompile').textContent = '...';
            document.getElementById('pending-apps').textContent = '...';
        }

        const result = await execCommand(`sh ${SCRIPTS_DIR}/get_apps.sh`);

        logDebug(`get_apps.sh 结果: 错误码=${result.errno}, 输出长度=${result.stdout?.length || 0}`);

        if (result.errno !== 0) {
            if (!background) logError('加载仪表盘数据失败');
            return;
        }

        if (!result.stdout || result.stdout.trim() === '') {
            if (!background) logError('get_apps.sh 返回空响应');
            return;
        }

        let data;
        try {
            data = JSON.parse(result.stdout);
        } catch (e) {
            if (!background) logError(`JSON 解析错误: ${e.message}`);
            logDebug(`响应内容: ${result.stdout.substring(0, 200)}...`);
            return;
        }

        allApps = data.apps || [];

        // Update stats
        const total = allApps.length;
        const compiled = allApps.filter(a => a.is编译d === true || a.is编译d === 'true').length;
        const needsRecompile = allApps.filter(a => a.needsRecompile === true || a.needsRecompile === 'true').length;
        const pending = total - compiled;

        document.getElementById('total-apps').textContent = total;
        document.getElementById('compiled-apps').textContent = compiled;
        document.getElementById('needs-recompile').textContent = needsRecompile;
        document.getElementById('pending-apps').textContent = pending;

        await loadScheduleInfo(background);

        tabLoaded.dashboard = true;
        tabLoadTime.dashboard = Date.now();
        logDebug(`仪表盘已加载: ${total} 个应用`);

        if (background) {
            logDebug('仪表盘数据已在后台刷新');
        }
    } catch (error) {
        if (!background) logError(`加载仪表盘时出错: ${error.message}`);
    } finally {
        tabLoading.dashboard = false;
    }
}

async function loadScheduleInfo(background = false) {
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
        if (!background) logError(`加载错误 schedule info: ${error.message}`);
    }
}

// Apps functions with pagination
async function loadApps(background = false) {
    // Prevent concurrent loads
    if (tabLoading.apps) return;
    tabLoading.apps = true;

    // If background and current tab is not apps, skip
    if (background && currentTab !== 'apps') {
        tabLoading.apps = false;
        return;
    }

    try {
        const container = document.getElementById('apps-list');
        if (container && !background) {
            container.innerHTML = '<p class="loading">加载应用中 (this may take a moment)...</p>';
        }

        const result = await execCommand(`sh ${SCRIPTS_DIR}/get_apps.sh`);

        logDebug(`loadApps result: errno=${result.errno}`);

        if (result.errno !== 0) {
            if (container && !background) {
                container.innerHTML = `<p class="loading" style="color: var(--danger-color)">加载应用失败<br><small>${result.stderr || 'Unknown error'}</small></p>`;
            }
            tabLoading.apps = false;
            return;
        }

        if (!result.stdout || result.stdout.trim() === '') {
            if (container && !background) {
                container.innerHTML = '<p class="loading">未收到服务器数据</p>';
            }
            tabLoading.apps = false;
            return;
        }

        let data;
        try {
            data = JSON.parse(result.stdout);
        } catch (e) {
            if (!background) {
                logError(`JSON parse error: ${e.message}`);
                logDebug(`响应: ${result.stdout.substring(0, 500)}...`);
                if (container) {
                    container.innerHTML = `<p class="loading" style="color: var(--danger-color)">解析应用数据失败<br><small>${e.message}</small></p>`;
                }
            }
            tabLoading.apps = false;
            return;
        }

        allApps = data.apps || [];

        if (!background) {
            showToast(`已加载 ${allApps.length} 个应用`);
        }
        logDebug(`已加载 ${allApps.length} 个应用`);

        filterAndRenderApps();
        tabLoaded.apps = true;
        tabLoadTime.apps = Date.now();

        if (background) {
            logDebug('应用数据已在后台刷新');
        }
    } catch (error) {
        if (!background) {
            logError(`加载应用时出错: ${error.message}`);
            if (document.getElementById('apps-list')) {
                document.getElementById('apps-list').innerHTML = `<p class="loading" style="color: var(--danger-color)">错误: ${error.message}</p>`;
            }
        }
    } finally {
        tabLoading.apps = false;
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
            filteredApps = filteredApps.filter(app => app.is编译d === true || app.is编译d === 'true');
            break;
        case 'uncompiled':
            filteredApps = filteredApps.filter(app => app.is编译d === false || app.is编译d === 'false');
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
        container.innerHTML = '<p class="loading">未找到应用</p>';
        return;
    }

    container.innerHTML = appsToRender.map(app => `
        <div class="app-card ${已选择Apps.has(app.packageName) ? '已选择' : ''}">
            <input type="checkbox"
                   class="app-checkbox"
                   data-package="${app.packageName}"
                   ${已选择Apps.has(app.packageName) ? 'checked' : ''}>
            <div class="app-icon">📱</div>
            <div class="app-info">
                <div class="app-name">${escapeHtml(app.packageName)}</div>
            </div>
            <div class="app-status">
                ${状态徽章(app)}
            </div>
            <div class="app-actions">
                <button class="btn btn-sm btn-secondary"
                        onclick="window.compileApp('${app.packageName}', '${app.desiredMode}')">
                    编译
                </button>
            </div>
        </div>
    `).join('');

    // Add event listeners to checkboxes
    container.querySelectorAll('.app-checkbox').forEach(checkbox => {
        checkbox.addEventListener('change', (e) => {
            const package = e.target.dataset.package;
            if (e.target.checked) {
                已选择Apps.add(package);
            } else {
                已选择Apps.delete(package);
            }
            updateSelectionCount();
        });
    });
}

function 状态徽章(app) {
    const is编译d = app.is编译d === true || app.is编译d === 'true';
    const needsRecompile = app.needsRecompile === true || app.needsRecompile === 'true';
    const compileMode = app.compileMode || 'none';

    if (needsRecompile) {
        return '<span class="status-badge status-needs-recompile">Needs Recompile</span>';
    }
    if (is编译d) {
        // Show compilation mode with badge
        return `<span class="status-badge status-compiled">${get编译ModeLabel(compileMode)}</span>`;
    }
    return '<span class="status-badge status-uncompiled">Uncompiled</span>';
}

function get编译ModeLabel(mode) {
    const modeLabels = {
        'speed': 'Speed ⚡',
        'verify': 'Verify ✓',
        'speed-profile': 'Speed Profile 🚀',
        'quicken': 'Quicken',
        'everything': 'Everything'
    };
    return modeLabels[mode] || mode;
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

    if (pageInfo) pageInfo.textContent = `第 .* 页，共 .* 页
    if (prevBtn) prevBtn.disabled = currentPage <= 1;
    if (nextBtn) nextBtn.disabled = currentPage >= (totalPages || 1);
}

function updateSelectionCount() {
    const countEl = document.getElementById('selection-count');
    if (countEl) {
        countEl.textContent = `${已选择Apps.size} 已选择`;
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
            已选择Apps.add(app.packageName);
        } else {
            已选择Apps.delete(app.packageName);
        }
    });

    renderPage();
    updateSelectionCount();
});

// 编译 app
window.compileApp = async function(packageName, mode) {
    showToast(`Compiling ${packageName}...`);
    logDebug(`Compiling ${packageName} with mode ${mode}`);

    const result = await execCommand(`sh ${SCRIPTS_DIR}/compile_app.sh '${packageName}' '${mode}'`);

    if (result.errno === 0) {
        showToast(`成功编译 ${packageName}`);
        logDebug(`编译d ${packageName} successfully`);
    } else {
        showToast(`编译失败 ${packageName}`);
        logError(`编译失败 ${packageName}: ${result.stderr || result.stdout}`);
    }
};

// 编译 已选择
document.getElementById('compile-已选择')?.addEventListener('click', async () => {
    if (已选择Apps.size === 0) {
        showToast('未选择应用');
        return;
    }

    if (!confirm(`编译 ${已选择Apps.size} 已选择 apps?`)) {
        return;
    }

    showToast('正在编译选中应用...');
    const defaultMode = document.getElementById('default-mode')?.value || 'speed';

    let compiled = 0;
    let failed = 0;

    for (const package of 已选择Apps) {
        const result = await execCommand(`sh ${SCRIPTS_DIR}/compile_app.sh '${package}' '${defaultMode}'`);
        if (result.errno === 0) {
            compiled++;
        } else {
            failed++;
        }
    }

    showToast(`已编译: ${compiled}, 失败: ${failed}`);
    已选择Apps.clear();
    updateSelectionCount();
});

// 编译 all
document.getElementById('compile-all')?.addEventListener('click', async () => {
    if (!confirm('编译 all uncompiled apps? 这可能需要一段时间.')) {
        return;
    }

    showToast('开始批量编译...');
    logDebug('开始批量编译');

    const result = await execCommand(`sh ${SCRIPTS_DIR}/compile_all.sh manual`);

    if (result.errno === 0) {
        showToast('编译已开始');
        logDebug('编译已开始 successfully');
    } else {
        showToast('启动编译失败');
        logError(`启动编译失败: ${result.stderr || result.stdout}`);
    }
});

// Schedule functions
async function loadSchedule(background = false) {
    // Prevent concurrent loads
    if (tabLoading.schedule) return;
    tabLoading.schedule = true;

    // If background and current tab is not schedule, skip
    if (background && currentTab !== 'schedule') {
        tabLoading.schedule = false;
        return;
    }

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
        tabLoaded.schedule = true;
        tabLoadTime.schedule = Date.now();
        if (background) {
            logDebug('计划数据已在后台刷新 in background');
        }
    } catch (error) {
        if (!background) logError(`加载错误 schedule: ${error.message}`);
    } finally {
        tabLoading.schedule = false;
    }
}

document.getElementById('save-schedule')?.addEventListener('click', async () => {
    const cron = document.getElementById('schedule-cron')?.value || '0 2 * * *';
    const enabled = document.getElementById('schedule-enabled')?.checked;

    await execCommand(`sed -i 's/^schedule=.*/schedule=${cron}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^schedule_enabled=.*/schedule_enabled=${enabled}/' ${CONFIGS_DIR}/dexoat.conf`);

    showToast('计划已保存');
    logDebug('计划已保存');

    await execCommand('pkill -f dexoat_ks');
    await execCommand(`sh ${MODULE_DIR}/service.sh &`);

    loadScheduleInfo();
});

document.getElementById('trigger-now')?.addEventListener('click', async () => {
    if (!confirm('立即执行计划编译？?')) {
        return;
    }

    showToast('开始计划编译...');
    await execCommand(`sh ${SCRIPTS_DIR}/compile_all.sh scheduled`);
    showToast('编译已开始');
});

// Config functions
async function loadConfig(background = false) {
    // Prevent concurrent loads
    if (tabLoading.config) return;
    tabLoading.config = true;

    // If background and current tab is not config, skip
    if (background && currentTab !== 'config') {
        tabLoading.config = false;
        return;
    }

    try {
        const result = await execCommand(`cat ${CONFIGS_DIR}/dexoat.conf`);
        if (result.errno === 0) {
            const lines = result.stdout.split('\n');

            const defaultMode = lines.find(l => l.startsWith('default_mode='))?.split('=')[1] || 'speed';
            const skip编译d = lines.find(l => l.startsWith('skip_compiled='))?.split('=')[1] || 'true';
            const detectModeReset = lines.find(l => l.startsWith('detect_mode_reset='))?.split('=')[1] || 'true';
            const compileOnBoot = lines.find(l => l.startsWith('compile_on_boot='))?.split('=')[1] || 'true';
            const logLevel = lines.find(l => l.startsWith('log_level='))?.split('=')[1] || 'INFO';
            const parallelJobs = lines.find(l => l.startsWith('parallel_jobs='))?.split('=')[1] || '2';

            document.getElementById('default-mode').value = defaultMode;
            document.getElementById('skip-compiled').checked = skip编译d === 'true';
            document.getElementById('detect-mode-reset').checked = detectModeReset === 'true';
            document.getElementById('compile-on-boot').checked = compileOnBoot === 'true';
            document.getElementById('log-level').value = logLevel;
            document.getElementById('parallel-jobs').value = parallelJobs;
        }
        tabLoaded.config = true;
        tabLoadTime.config = Date.now();
        if (background) {
            logDebug('配置数据已在后台刷新 in background');
        }
    } catch (error) {
        if (!background) logError(`加载错误 config: ${error.message}`);
    } finally {
        tabLoading.config = false;
    }
}

document.getElementById('save-config')?.addEventListener('click', async () => {
    const defaultMode = document.getElementById('default-mode')?.value || 'speed';
    const skip编译d = document.getElementById('skip-compiled')?.checked;
    const detectModeReset = document.getElementById('detect-mode-reset')?.checked;
    const compileOnBoot = document.getElementById('compile-on-boot')?.checked;
    const logLevel = document.getElementById('log-level')?.value || 'INFO';
    const parallelJobs = document.getElementById('parallel-jobs')?.value || '2';

    await execCommand(`sed -i 's/^default_mode=.*/default_mode=${defaultMode}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^skip_compiled=.*/skip_compiled=${skip编译d}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^detect_mode_reset=.*/detect_mode_reset=${detectModeReset}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^compile_on_boot=.*/compile_on_boot=${compileOnBoot}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^log_level=.*/log_level=${logLevel}/' ${CONFIGS_DIR}/dexoat.conf`);
    await execCommand(`sed -i 's/^parallel_jobs=.*/parallel_jobs=${parallelJobs}/' ${CONFIGS_DIR}/dexoat.conf`);

    showToast('配置已保存');
    logDebug('配置已保存');

    await execCommand('pkill -f dexoat_ks');
    await execCommand(`sh ${MODULE_DIR}/service.sh &`);
});

document.getElementById('un-compile-all')?.addEventListener('click', async () => {
    if (!confirm('这将清除所有编译. 应用运行速度会变慢. 继续?')) {
        return;
    }

    const result = await execCommand(`echo yes | sh ${SCRIPTS_DIR}/un_compile_all.sh`);

    if (result.errno === 0) {
        showToast('所有编译已清除. 建议重启.');
    } else {
        showToast('清除编译失败');
    }
});

// Logs functions
async function loadLogs(background = false) {
    // Prevent concurrent loads
    if (tabLoading.logs) return;
    tabLoading.logs = true;

    // If background and current tab is not logs, skip
    if (background && currentTab !== 'logs') {
        tabLoading.logs = false;
        return;
    }

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
        tabLoaded.logs = true;
        tabLoadTime.logs = Date.now();
        if (background) {
            logDebug('Logs data refreshed in background');
        }
    } catch (error) {
        if (!background) logError(`加载错误 logs: ${error.message}`);
        document.getElementById('logs-content').textContent = `加载错误 logs: ${error.message}`;
    } finally {
        tabLoading.logs = false;
    }
}

document.getElementById('refresh-logs')?.addEventListener('click', loadLogs);
document.getElementById('log-level-filter')?.addEventListener('change', loadLogs);

document.getElementById('clear-logs')?.addEventListener('click', async () => {
    if (!confirm('Clear all logs?')) {
        return;
    }

    await execCommand(`> ${LOGS_DIR}/dexoat.log`);
    showToast('日志已清空');
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
        showToast('日志已下载');
    } else {
        showToast('下载日志失败');
    }
});

// Refresh buttons
document.getElementById('refresh-dashboard')?.addEventListener('click', () => loadDashboard(false));
document.getElementById('refresh-apps')?.addEventListener('click', () => loadApps(false));

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
