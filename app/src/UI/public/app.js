const API_BASE = '/api';

// State
let installedCache = [];

document.addEventListener('DOMContentLoaded', () => {
    loadInstalled();
});

// Navigation
function showTab(id) {
    document.querySelectorAll('.view-section').forEach(el => el.classList.remove('active', 'fade-in'));
    document.querySelectorAll('.view-section').forEach(el => el.classList.add('hidden'));

    document.querySelectorAll('.nav-btn').forEach(el => el.classList.remove('active'));

    const target = document.getElementById(`tab-${id}`);
    target.classList.remove('hidden');
    target.classList.add('active');

    // Highlight nav
    // (Simple approximate logic)
    event.currentTarget.classList.add('active');

    if (id === 'available') {
        // Warning: This could be slow.
        if (document.getElementById('available-list').children.length === 0) {
            loadAvailable();
        }
    }
}

// --- API Calls ---

async function loadInstalled() {
    const list = document.getElementById('installed-list');
    list.innerHTML = '<div class="loading-spinner">Loading...</div>';

    try {
        const res = await fetch(`${API_BASE}/versions`);
        const data = await res.json();

        installedCache = data.installed || [];
        renderInstalled(installedCache);

        // Update header status (Check for 2 or "Active")
        const active = installedCache.find(v => v.Status === 2 || v.Status === 'Active');
        const statusEl = document.getElementById('current-active');
        statusEl.innerText = active ? active.VersionString : 'None';

    } catch (err) {
        showToast('Error loading versions', 'error');
        console.error(err);
    }
}

// function loadAvailable() moved to bottom with filtering support

// --- Actions ---

async function activateVersion(versionString, path) {
    showToast(`Activando PHP ${versionString}...`, 'info');

    try {
        const res = await fetch(`${API_BASE}/activate`, {
            method: 'POST',
            body: JSON.stringify({ VersionString: versionString, Path: path })
        });

        if (res.ok) {
            showToast('Versión activada correctamente', 'success');
            loadInstalled(); // Refresh
        } else {
            throw new Error('Failed');
        }
    } catch (err) {
        showToast('Error al activar versión', 'error');
    }
}

async function installVersion(urlOrObj, label, ver) {
    let payload = {};

    // Handle overload (object vs params)
    if (typeof urlOrObj === 'object') {
        payload = urlOrObj;
    } else {
        payload = {
            DownloadUrl: urlOrObj,
            FullLabel: label,
            VersionString: ver
        };
    }

    if (!confirm(`¿Descargar e instalar PHP ${payload.VersionString}?`)) return;

    showToast(`Iniciando descarga PHP ${payload.VersionString}...`, 'info');

    try {
        const res = await fetch(`${API_BASE}/install`, {
            method: 'POST',
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            const data = await res.json();
            if (data.jobId) {
                showToast('Descarga en segundo plano...', 'info');
                pollJob(data.jobId);
            } else {
                showToast('Instalación completada', 'success');
                loadInstalled();
            }
        } else {
            const err = await res.json();
            if (res.status === 400 && err.error === "Version already exists") {
                showToast("Carpeta existente. Búsquela en 'Instaladas' y elimínela (Papelera) antes de reinstalar.", 'warning');
            } else {
                showToast(`Error: ${err.error || 'Unknown'}`, 'error');
            }
        }
    } catch (err) {
        showToast('Error de conexión', 'error');
        console.error(err);
    }
}

async function uninstallVersion(versionString, path) {
    if (!confirm(`¿Está seguro de que desea eliminar PHP ${versionString}?`)) return;

    showToast(`Eliminando PHP ${versionString}...`, 'info');

    try {
        const res = await fetch(`${API_BASE}/uninstall`, {
            method: 'POST',
            body: JSON.stringify({ VersionString: versionString, Path: path })
        });

        if (res.ok) {
            showToast('Versión eliminada correctamente', 'success');
            loadInstalled();
            // Also refresh available list if on that tab
            if (allAvailable.length > 0) {
                filterArch(currentFilter);
            }
        } else {
            const err = await res.json();
            showToast(`Error: ${err.error || 'No se pudo eliminar'}`, 'error');
        }
    } catch (err) {
        showToast('Error de conexión', 'error');
        console.error(err);
    }
}

// --- Progress Toast Helper ---
function updateProgressToast(id, msg, pct, type = 'info') {
    let toast = document.getElementById(id);
    const container = document.getElementById('toast-container');

    if (!toast) {
        toast = document.createElement('div');
        toast.id = id;
        toast.className = `toast toast-${type}`;
        toast.style.background = '#3b82f6'; // Default blue
        toast.style.color = 'white';
        toast.style.padding = '1rem 2rem';
        toast.style.margin = '1rem';
        toast.style.borderRadius = '10px';
        toast.style.boxShadow = '0 5px 15px rgba(0,0,0,0.3)';
        toast.style.position = 'fixed';
        toast.style.bottom = '20px';
        toast.style.right = '20px';
        toast.style.zIndex = '9999';
        toast.style.transition = 'all 0.3s ease';
        toast.innerHTML = `
            <div style="margin-bottom:8px; font-weight:bold;">${msg}</div>
            <div style="background:rgba(255,255,255,0.3); height:6px; border-radius:3px; width:200px; overflow:hidden;">
                <div id="${id}-bar" style="background:white; height:100%; width:0%; transition:width 0.3s;"></div>
            </div>
            <small id="${id}-pct" style="display:block; margin-top:4px; text-align:right;">0%</small>
        `;
        container.appendChild(toast);
    }

    // Update Style based on type
    if (type === 'success') toast.style.background = '#10b981';
    if (type === 'error') toast.style.background = '#ef4444';

    // Update Content
    const bar = document.getElementById(`${id}-bar`);
    const pctLabel = document.getElementById(`${id}-pct`);

    if (bar) bar.style.width = `${pct}%`;
    if (pctLabel) pctLabel.innerText = `${pct}%`;
    toast.querySelector('div').innerText = msg;

    return toast;
}

function pollJob(jobId) {
    const toastId = `job-${jobId}`;

    // Initial Toast
    updateProgressToast(toastId, "Iniciando...", 0);

    const pollInterval = setInterval(async () => {
        try {
            const res = await fetch(`${API_BASE}/jobs/${jobId}`);
            const data = await res.json();

            // Clean up message
            let cleanMsg = data.Message.replace(/^\[PROGRESS\] \| \d+ \| /, '');

            if (data.Status === 'Completed') {
                clearInterval(pollInterval);
                updateProgressToast(toastId, "Instalación Finalizada", 100, 'success');
                setTimeout(() => document.getElementById(toastId)?.remove(), 3000);
                loadInstalled();
            } else if (data.Status === 'Failed') {
                clearInterval(pollInterval);
                updateProgressToast(toastId, `Error: ${cleanMsg}`, 100, 'error');
                // Keep error visible longer
                setTimeout(() => document.getElementById(toastId)?.remove(), 6000);
            } else {
                // Running
                const pct = data.Progress || 0;
                updateProgressToast(toastId, cleanMsg, pct, 'info');
            }
        } catch (e) {
            clearInterval(pollInterval);
            console.error(e);
        }
    }, 1000);
}

// --- Rendering ---

function renderInstalled(versions) {
    const list = document.getElementById('installed-list');
    list.innerHTML = '';

    if (versions.length === 0) {
        list.innerHTML = '<p>No hay versiones instaladas.</p>';
        return;
    }

    versions.forEach(v => {
        const isActive = (v.Status === 2 || v.Status === 'Active');
        const card = document.createElement('div');
        card.className = `card ${isActive ? 'active-version' : ''}`;

        card.innerHTML = `
            <h3>${v.VersionString}</h3>
            <p>${v.ThreadSafety === 0 ? 'NTS' : 'ZTS'} | ${v.Architecture === 1 ? 'x64' : 'x86'}</p>
            <div style="display: flex; gap: 0.5rem;">
                <button class="btn-activate" onclick="activateVersion('${v.VersionString}', '${v.Path.replace(/\\/g, '\\\\')}')">
                    ${isActive ? 'Activo' : 'Activar'}
                </button>
                <button class="btn-secondary" onclick="uninstallVersion('${v.VersionString}', '${v.Path.replace(/\\/g, '\\\\')}')" style="color: #ef4444; border-color: #ef4444;">
                    <i class="ri-delete-bin-line"></i>
                </button>
            </div>
        `;
        list.appendChild(card);
    });
}

// function renderAvailable() replaced by renderAvailableList()

function showToast(msg, type = 'info') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerText = msg;

    // Styles for toast - relative positioning for stacking
    toast.style.background = type === 'error' ? '#ef4444' : (type === 'success' ? '#10b981' : (type === 'warning' ? '#eab308' : '#3b82f6'));
    toast.style.color = 'white';
    toast.style.padding = '0.75rem 1.5rem';
    toast.style.marginBottom = '0.5rem';
    toast.style.borderRadius = '8px';
    toast.style.boxShadow = '0 4px 12px rgba(0,0,0,0.3)';
    toast.style.animation = 'fadeIn 0.3s forwards';
    toast.style.maxWidth = '320px';
    toast.style.wordBreak = 'break-word';

    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateX(20px)';
        toast.style.transition = 'all 0.3s ease';
        setTimeout(() => toast.remove(), 300);
    }, 4000);
}

// --- Settings Modal ---
let appConfig = null;

async function loadConfig() {
    try {
        const res = await fetch(`${API_BASE}/config`);
        if (res.ok) {
            appConfig = await res.json();
            // Update UI checkboxes
            document.getElementById('config-launcher-debug').checked = appConfig.debug?.launcher_debug_enabled || false;
            document.getElementById('config-server-debug').checked = appConfig.debug?.server_debug_enabled || false;
        }
    } catch (e) {
        console.error('Error loading config:', e);
    }
}

async function saveConfig() {
    if (!appConfig) {
        appConfig = { debug: {}, server: { port: 8085 }, browser: { use_app_mode: true } };
    }

    appConfig.debug.launcher_debug_enabled = document.getElementById('config-launcher-debug').checked;
    appConfig.debug.server_debug_enabled = document.getElementById('config-server-debug').checked;

    try {
        const res = await fetch(`${API_BASE}/config`, {
            method: 'POST',
            body: JSON.stringify(appConfig)
        });
        if (res.ok) {
            showToast('Configuracion guardada', 'success');
        }
    } catch (e) {
        showToast('Error guardando configuracion', 'error');
    }
}

function openSettings() {
    document.getElementById('settings-modal').classList.remove('hidden');
    loadConfig();
}

function closeSettings() {
    document.getElementById('settings-modal').classList.add('hidden');
}

// --- Debug ---
async function loadDebugInfo() {
    try {
        const res = await fetch('/api/debug/path');
        const data = await res.json();

        const currentContext = document.getElementById('debug-current-path');
        if (data.Current && data.Current.User) {
            currentContext.innerHTML = data.Current.User.map(p => `
                <div class="path-chip">
                    <i class="ri-folder-line"></i>
                    ${p}
                </div>
             `).join('');
        }

        const historyContext = document.getElementById('debug-history-path');
        const emptyState = document.getElementById('debug-history-empty');

        // Handle empty array or null
        const history = data.History && data.History.User ? data.History.User : [];
        if (Array.isArray(history) && history.length > 0) {
            emptyState.classList.add('hidden');
            historyContext.innerHTML = history.map(h => `
                <div class="path-chip">
                    <i class="ri-time-line"></i>
                    ${h}
                </div>
            `).join('');
        } else {
            historyContext.innerHTML = '';
            emptyState.classList.remove('hidden');
        }
    } catch (e) {
        showToast("Error loading debug info", "error");
    }
}

// --- Filtering ---
let allAvailable = [];
let currentFilter = 'all';

function filterArch(type) {
    currentFilter = type;

    // Update buttons - highlight the active one
    document.querySelectorAll('.filter-btn').forEach(b => {
        b.classList.remove('active');
        // Match by data attribute or text content
        const btnType = b.getAttribute('data-filter') || b.textContent.toLowerCase();
        if (btnType.includes(type) ||
            (type === 'all' && btnType.includes('todos')) ||
            (type === 'recommended' && btnType.includes('wamp'))) {
            b.classList.add('active');
        }
    });

    // Filter logic
    let filtered = allAvailable;
    if (type === 'x64') {
        filtered = allAvailable.filter(v => v.Architecture === 1); // 1 = x64 in backend Enum? Wait, check Enum.
        // Backend: 0=x86, 1=x64? Let's verify Enum or check JSON.
        // User JSON showed: Architecture: 0 for 8.4.16 src, 1 for x64 nts. So 1 is x64.
        // Wait, "Architecture": 0 in user json for "php-8.4.16-src". Src has no arch usually or x86 default?
        // "php-8.5.1-nts-Win32-vs17-x64" -> Architecture: 1.
        // "php-8.5.1-nts-Win32-vs17-x86" -> Architecture: 0.
        // So 1 = x64, 0 = x86.
    } else if (type === 'recommended') {
        // Wamp64 Recommended: x64 + Thread Safe
        const candidates = allAvailable.filter(v => v.Architecture === 1 && v.ThreadSafety === 1);

        // Deduplicate: Keep only 1 per version string
        const seen = new Set();
        filtered = [];
        candidates.forEach(v => {
            if (!seen.has(v.VersionString)) {
                seen.add(v.VersionString);
                filtered.push(v);
            }
        });

    } else if (type === 'x86') {
        filtered = allAvailable.filter(v => v.Architecture === 0);
    }

    renderAvailableList(filtered);
}

// Modify loadAvailable to use global cache
async function loadAvailable() {
    // Show spinner if needed
    const tbody = document.getElementById('available-list');
    tbody.innerHTML = '<tr><td colspan="5">Cargando...</td></tr>';

    try {
        const res = await fetch('/api/available');
        allAvailable = await res.json(); // Store globally
        filterArch(currentFilter); // Render with current filter
    } catch (e) {
        console.error(e);
        showToast("Error cargando disponibles", "error");
    }
}

function renderAvailableList(list) {
    const tbody = document.getElementById('available-list');
    tbody.innerHTML = '';

    list.forEach(v => {
        // Check if installed (Loose match on VersionString + Exact on Stats)
        const installedMatch = installedCache.find(i =>
            i.VersionString === (v.VersionString || v.FullLabel.split('-')[1]) &&
            i.Architecture === v.Architecture &&
            i.ThreadSafety === v.ThreadSafety
        );
        const isInstalled = !!installedMatch;

        const tr = document.createElement('tr');

        let actionBtn = '';
        if (isInstalled && installedMatch) {
            const escapedPath = installedMatch.Path.replace(/\\/g, '\\\\');
            actionBtn = `
                <button class="download-btn" onclick="uninstallVersion('${v.VersionString}', '${escapedPath}')" style="border-color:#ef4444; color:#ef4444; background:rgba(239, 68, 68, 0.05);">
                    <i class="ri-delete-bin-line"></i> Desinstalar
                </button>
             `;
        } else {
            // Pass params as strings
            actionBtn = `
                <button class="download-btn" onclick="installVersion('${v.DownloadUrl}', '${v.FullLabel}', '${v.VersionString}')">
                    <i class="ri-download-line"></i> Instalar
                </button>
             `;
        }

        tr.innerHTML = `
            <td>${v.VersionString || v.FullLabel}</td>
            <td>${v.ThreadSafety === 1 ? 'Thread Safe' : 'NTS'}</td>
            <td>${v.Architecture === 1 ? 'x64' : 'x86'}</td>
            <td>
                ${isInstalled
                ? '<span class="status-pill" style="border-color:#10b981; color:#10b981; background:rgba(16, 185, 129, 0.1);">Instalado</span>'
                : '<span class="status-pill">Disponible</span>'}
            </td>
            <td>${actionBtn}</td>
        `;
        tbody.appendChild(tr);
    });
}

