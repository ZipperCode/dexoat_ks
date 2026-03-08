(function () {
  const MODULE_DIR = '/data/adb/modules/dexoat_ks';
  const API_SCRIPT = `${MODULE_DIR}/scripts/api.sh`;

  function shellEscape(value) {
    return `'${String(value).replace(/'/g, `'"'"'`)}'`;
  }

  async function rawExec(cmd) {
    const execFn = (window.ksu && window.ksu.exec) || window.exec;
    if (!execFn) {
      throw new Error('KernelSU exec API not available');
    }

    const result = await execFn(cmd);
    if (result.errno !== 0) {
      throw new Error(result.stderr || result.stdout || 'command failed');
    }
    return result.stdout || '';
  }

  async function callApi(action, args) {
    const parts = [`sh ${API_SCRIPT}`, action];
    Object.entries(args || {}).forEach(([key, val]) => {
      if (val === undefined || val === null || val === '') return;
      parts.push(`--${key}`);
      parts.push(shellEscape(val));
    });

    const stdout = await rawExec(parts.join(' '));
    return JSON.parse(stdout.trim());
  }

  async function readLogs(lines) {
    const cmd = `tail -n ${Number(lines || 200)} ${MODULE_DIR}/logs/dexoat.log 2>/dev/null || echo \"no logs\"`;
    return rawExec(cmd);
  }

  window.DexoatApi = {
    callApi,
    readLogs
  };
})();
