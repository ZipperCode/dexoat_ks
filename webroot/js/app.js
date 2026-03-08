(function () {
  const toastEl = document.getElementById('toast');

  function toast(msg) {
    toastEl.textContent = msg;
    toastEl.classList.add('show');
    setTimeout(() => toastEl.classList.remove('show'), 2200);
  }

  function bindTabs() {
    document.querySelectorAll('.tab').forEach((tab) => {
      tab.addEventListener('click', () => {
        const name = tab.dataset.tab;
        document.querySelectorAll('.tab').forEach((t) => t.classList.remove('active'));
        document.querySelectorAll('.panel').forEach((p) => p.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById(name).classList.add('active');
      });
    });
  }

  async function refreshOverview() {
    try {
      const queue = await window.DexoatApi.callApi('queue_status');
      const history = await window.DexoatApi.callApi('task_history', { page: 1, size: 1 });

      document.getElementById('queue-count').textContent = String(queue.data.count || 0);

      const first = (history.data.items || [])[0];
      document.getElementById('last-task').textContent = first
        ? `${first.package} (${first.source})`
        : '暂无';
    } catch (err) {
      toast(`总览加载失败: ${err.message}`);
    }
  }

  async function loadStrategy() {
    try {
      const resp = await window.DexoatApi.callApi('get_config');
      const cfg = resp.data || {};
      document.getElementById('global-enabled').checked = cfg.global_enabled === 'true';
      document.getElementById('default-mode').value = cfg.default_mode || 'speed';
    } catch (err) {
      toast(`策略加载失败: ${err.message}`);
    }
  }

  async function saveStrategy() {
    const enabled = document.getElementById('global-enabled').checked ? 'true' : 'false';
    const mode = document.getElementById('default-mode').value;

    try {
      await window.DexoatApi.callApi('set_config', { key: 'global_enabled', value: enabled });
      await window.DexoatApi.callApi('set_config', { key: 'default_mode', value: mode });
      toast('策略已保存');
    } catch (err) {
      toast(`策略保存失败: ${err.message}`);
    }
  }

  async function upsertRule() {
    const pkg = document.getElementById('rule-package').value.trim();
    const mode = document.getElementById('rule-mode').value;
    if (!pkg) {
      toast('请输入包名');
      return;
    }

    try {
      await window.DexoatApi.callApi('upsert_rule', { package: pkg, mode, enabled: 'true' });
      toast('规则已更新');
    } catch (err) {
      toast(`规则更新失败: ${err.message}`);
    }
  }

  async function deleteRule() {
    const pkg = document.getElementById('rule-package').value.trim();
    if (!pkg) {
      toast('请输入包名');
      return;
    }

    try {
      await window.DexoatApi.callApi('delete_rule', { package: pkg });
      toast('规则已删除');
    } catch (err) {
      toast(`删除失败: ${err.message}`);
    }
  }

  async function enqueueTask() {
    const pkg = document.getElementById('enqueue-package').value.trim();
    const source = document.getElementById('enqueue-source').value;
    if (!pkg) {
      toast('请输入包名');
      return;
    }

    try {
      await window.DexoatApi.callApi('enqueue', { package: pkg, source });
      toast('任务已入队');
      await refreshQueue();
      await refreshHistory();
      await refreshOverview();
    } catch (err) {
      toast(`入队失败: ${err.message}`);
    }
  }

  async function refreshQueue() {
    try {
      const resp = await window.DexoatApi.callApi('queue_status');
      document.getElementById('queue-status').textContent = JSON.stringify(resp.data, null, 2);
    } catch (err) {
      toast(`队列加载失败: ${err.message}`);
    }
  }

  async function refreshHistory() {
    try {
      const resp = await window.DexoatApi.callApi('task_history', { page: 1, size: 50 });
      document.getElementById('history-output').textContent = JSON.stringify(resp.data, null, 2);
    } catch (err) {
      toast(`历史加载失败: ${err.message}`);
    }
  }

  async function refreshLogs() {
    try {
      const text = await window.DexoatApi.readLogs(200);
      document.getElementById('logs-output').textContent = text;
    } catch (err) {
      toast(`日志加载失败: ${err.message}`);
    }
  }

  function bindActions() {
    document.getElementById('refresh-overview').addEventListener('click', refreshOverview);
    document.getElementById('save-strategy').addEventListener('click', saveStrategy);
    document.getElementById('add-rule').addEventListener('click', upsertRule);
    document.getElementById('remove-rule').addEventListener('click', deleteRule);
    document.getElementById('enqueue-task').addEventListener('click', enqueueTask);
    document.getElementById('refresh-queue').addEventListener('click', refreshQueue);
    document.getElementById('refresh-history').addEventListener('click', refreshHistory);
    document.getElementById('refresh-logs').addEventListener('click', refreshLogs);
  }

  async function init() {
    bindTabs();
    bindActions();
    await refreshOverview();
    await loadStrategy();
    await refreshQueue();
    await refreshHistory();
    await refreshLogs();
  }

  init();
})();
