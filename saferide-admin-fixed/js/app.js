// ── APP STATE ─────────────────────────────────────────────────────────────────
const STATE = {
  drivers: {}, students: {}, parents: {}, trips: {},
  attendance: {}, messages: {}, aiLogs: {},
  vanLocations: {},   // { vanId: { lat, lng, speed, ... } }
  vanAlerts: {},      // { vanId: { isDrowsy, lastAlert } }
  vanMessages: {},    // { vanId: { msgId: msgObj } }
  alerts: null, sos: null, safety: null,
  drowsyCount: 0,
  selectedVan: null,     // currently selected van on live page
  selectedMsgVan: null,  // currently selected van on messages page
  registeredVans: [],    // all known vanIds from drivers collection
};

// ── 1KM PROXIMITY ALERTS ──────────────────────────────────────────────────────
const VAN_STOPS = {}; 
const proximityAlertFired = {};
const PROXIMITY_RADIUS_KM = 1.0;

function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 + Math.cos(lat1*Math.PI/180)*Math.cos(lat2*Math.PI/180)*Math.sin(dLng/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

function checkProximityAlerts(vanId, lat, lng) {
  const stop = VAN_STOPS[vanId];
  if (!stop) return;
  const dist = haversineKm(lat, lng, stop.lat, stop.lng);
  const key = `${vanId}_${stop.label}`;
  if (dist <= PROXIMITY_RADIUS_KM && !proximityAlertFired[key]) {
    proximityAlertFired[key] = true;
    const msg = `🚌 ${vanId.toUpperCase()} is within 1km of ${stop.label}!`;
    toast(msg, 'warn');
    showProximityBanner(vanId, stop.label, dist);
    dbPush(`notifications/${vanId}`, {
      type: 'proximity', vanId, stop: stop.label,
      distanceKm: dist.toFixed(2), message: msg, timestamp: Date.now()
    }).catch(() => {});
  } else if (dist > PROXIMITY_RADIUS_KM + 0.2) {
    delete proximityAlertFired[key];
  }
}

function showProximityBanner(vanId, stopLabel, dist) {
  let banner = document.getElementById('proximity-banner');
  if (!banner) {
    banner = document.createElement('div');
    banner.id = 'proximity-banner';
    banner.style.cssText = 'position:fixed;top:70px;right:20px;z-index:9999;background:var(--warn);color:#000;padding:12px 18px;border-radius:10px;font-family:\'Syne\',sans-serif;font-weight:700;font-size:13px;box-shadow:0 4px 20px rgba(255,160,0,.4);display:flex;align-items:center;gap:10px;max-width:340px;';
    document.body.appendChild(banner);
  }
  banner.innerHTML = `<span style="font-size:20px">📍</span><div><div>${vanId.toUpperCase()} approaching ${stopLabel}</div><div style="font-size:11px;opacity:.8">${(dist*1000).toFixed(0)}m away · ${new Date().toLocaleTimeString()}</div></div><span style="cursor:pointer;margin-left:auto;opacity:.7" onclick="this.parentElement.remove()">✕</span>`;
  setTimeout(() => { if (banner.parentElement) banner.remove(); }, 8000);
}

function setVanStop(vanId, lat, lng, label) {
  VAN_STOPS[vanId] = { lat: parseFloat(lat), lng: parseFloat(lng), label };
  delete proximityAlertFired[`${vanId}_${label}`];
  toast(`Stop set for ${vanId.toUpperCase()}: ${label}`, 'success');
  renderVanStopsTable();
  // Redraw stop pin on live map
  if (vanMarkers[vanId]) {
    if (vanMarkers[vanId].stop && liveMap) liveMap.removeLayer(vanMarkers[vanId].stop);
    if (vanMarkers[vanId].circle && liveMap) liveMap.removeLayer(vanMarkers[vanId].circle);
    delete vanMarkers[vanId].stop;
    delete vanMarkers[vanId].circle;
  }
  if (STATE.selectedVan === vanId) updateLiveMap(vanId);
}

function removeVanStop(vanId) {
  if (vanMarkers[vanId]) {
    if (vanMarkers[vanId].stop && liveMap) liveMap.removeLayer(vanMarkers[vanId].stop);
    if (vanMarkers[vanId].circle && liveMap) liveMap.removeLayer(vanMarkers[vanId].circle);
    delete vanMarkers[vanId].stop;
    delete vanMarkers[vanId].circle;
  }
  delete VAN_STOPS[vanId];
  renderVanStopsTable();
  toast(`Stop removed for ${vanId.toUpperCase()}`, 'warn');
}

function renderVanStopsTable() {
  const el2 = document.getElementById('van-stops-list');
  if (!el2) return;
  const entries = Object.entries(VAN_STOPS);
  if (!entries.length) {
    el2.innerHTML = '<div style="color:var(--text3);font-size:12px;padding:10px 0">No stops configured</div>';
    return;
  }
  el2.innerHTML = entries.map(([vid, s]) => `
    <div style="display:flex;align-items:center;gap:10px;padding:8px 0;border-bottom:1px solid var(--border)">
      <div style="flex:1">
        <div style="font-size:13px;font-weight:600">${vid.toUpperCase()} → ${s.label}</div>
        <div style="font-size:11px;color:var(--text3);font-family:'DM Mono',monospace">${s.lat.toFixed(5)}, ${s.lng.toFixed(5)}</div>
      </div>
      <button class="btn btn-ghost btn-sm" style="color:var(--danger)" onclick="removeVanStop('${vid}')">Remove</button>
    </div>`).join('');
}

// ── MULTI-VAN HELPERS ─────────────────────────────────────────────────────────
function getRegisteredVans() {
  const vanSet = new Set();
  Object.values(STATE.drivers).forEach(d => {
    if (d.vanId) vanSet.add(d.vanId.toLowerCase());
    if (d.profile && d.profile.vehicle) vanSet.add(d.profile.vehicle.toLowerCase());
  });
  if (!vanSet.size) vanSet.add('van01');
  STATE.registeredVans = [...vanSet].sort();
  return STATE.registeredVans;
}

// ── BOOTSTRAP ─────────────────────────────────────────────────────────────────
async function bootstrap() {
  setTxt('conn-label', 'CONNECTING');

  const basePaths = ['drivers','students','parents','trips','attendance','ai_logs','sos','safety_status'];
  const results = await Promise.all(basePaths.map(p => dbGet(p)));
  const [drivers, students, parents, trips, attendance, aiLogs, sos, safety] = results;

  STATE.drivers    = drivers    || {};
  STATE.students   = students   || {};
  STATE.parents    = parents    || {};
  STATE.trips      = trips      || {};
  STATE.attendance = attendance || {};
  STATE.messages   = {};
  STATE.vanMessages = {}; // { vanId: { msgId: msgObj } }
  STATE.selectedMsgVan = null;
  STATE.aiLogs     = aiLogs     || {};
  STATE.sos        = sos;
  STATE.safety     = safety;
  STATE.drowsyCount = Object.keys(STATE.aiLogs).length;

  getRegisteredVans();
  await loadAllVanData();

  setTxt('conn-label', 'LIVE');

  renderDashboard();
  renderLive();
  renderDrivers();
  renderStudents();
  renderParents();
  renderAlerts();
  renderAttendance();
  renderMsgVanList();
  renderTrips();

  startVanPolling();
  dbListen('sos',            data => { STATE.sos = data;    onSOSUpdate(); },     5000);
  dbListen('safety_status',  data => { STATE.safety = data; onSafetyUpdate(); },  6000);
  startMessagesPolling();
}

async function loadAllVanData() {
  const vans = STATE.registeredVans;
  const locs = await Promise.all(vans.map(v => dbGet(`v1/locations/${v}`)));
  const alts = await Promise.all(vans.map(v => dbGet(`v1/alerts/${v}`)));
  vans.forEach((v, i) => {
    if (locs[i]) STATE.vanLocations[v] = locs[i];
    if (alts[i]) STATE.vanAlerts[v]    = alts[i];
  });
  // Ensure selectedVan is set before first render
  if (!STATE.selectedVan && vans.length) STATE.selectedVan = vans[0];
  const sel = STATE.selectedVan;
  STATE.location = STATE.vanLocations[sel] || null;
  STATE.alerts   = STATE.vanAlerts[sel]    || null;
}

function startVanPolling() {
  STATE.registeredVans.forEach(vanId => {
    dbListen(`v1/locations/${vanId}`, data => {
      if (!data) return;
      STATE.vanLocations[vanId] = data;
      const lat = parseFloat(data.lat ?? data.latitude);
      const lng = parseFloat(data.lng ?? data.longitude);
      if (!isNaN(lat) && !isNaN(lng)) checkProximityAlerts(vanId, lat, lng);
      if (vanId === (STATE.selectedVan || STATE.registeredVans[0])) {
        STATE.location = data;
        STATE.alerts   = STATE.vanAlerts[vanId] || null;
        onLocationUpdate();
      }
      updateFleetMap();
    }, 4000);

    dbListen(`v1/alerts/${vanId}`, data => {
      if (!data) return;
      STATE.vanAlerts[vanId] = data;
      if (vanId === (STATE.selectedVan || STATE.registeredVans[0])) {
        STATE.alerts = data;
        onAlertsUpdate();
      }
    }, 4000);
  });
}

// ── MAP STATE ─────────────────────────────────────────────────────────────────
let dashMap, liveMap;
let vanMarkers = {};
let busIcon;

function getBusIcon() {
  return busIcon || L.icon({ iconUrl: 'https://cdn-icons-png.flaticon.com/512/3448/3448339.png', iconSize: [35, 35], iconAnchor: [17, 17] });
}

function updateFleetMap() {
  if (!dashMap) return;
  Object.entries(STATE.vanLocations).forEach(([vanId, loc]) => {
    const lat = parseFloat(loc.lat ?? loc.latitude);
    const lng = parseFloat(loc.lng ?? loc.longitude);
    if (isNaN(lat) || isNaN(lng)) return;
    const latlng = [lat, lng];
    const spd = parseFloat(loc.speed || 0).toFixed(1);
    if (!vanMarkers[vanId]) vanMarkers[vanId] = {};
    if (vanMarkers[vanId].dash) {
      vanMarkers[vanId].dash.setLatLng(latlng);
      vanMarkers[vanId].dash.getPopup()?.setContent(`${vanId.toUpperCase()} · ${spd} km/h`);
    } else {
      vanMarkers[vanId].dash = L.marker(latlng, { icon: getBusIcon() }).addTo(dashMap).bindPopup(`${vanId.toUpperCase()} · ${spd} km/h`);
    }
  });
}

function updateLiveMap(vanId) {
  if (!liveMap || !vanId) return;
  const loc = STATE.vanLocations[vanId];
  if (!loc) return;
  const lat = parseFloat(loc.lat ?? loc.latitude);
  const lng = parseFloat(loc.lng ?? loc.longitude);
  if (isNaN(lat) || isNaN(lng)) return;
  const latlng = [lat, lng];

  if (!vanMarkers[vanId]) vanMarkers[vanId] = {};

  if (vanMarkers[vanId].live) {
    vanMarkers[vanId].live.setLatLng(latlng);
  } else {
    vanMarkers[vanId].live = L.marker(latlng, { icon: getBusIcon() }).addTo(liveMap).bindPopup(`${vanId.toUpperCase()} · Live`);
  }
  liveMap.panTo(latlng);

  // Stop pin + proximity circle
  const stop = VAN_STOPS[vanId];
  if (stop) {
    if (!vanMarkers[vanId].stop) {
      const stopIcon = L.divIcon({ html: `<div style="background:#f59e0b;color:#000;padding:3px 7px;border-radius:5px;font-size:11px;font-weight:700;white-space:nowrap;box-shadow:0 2px 6px rgba(0,0,0,.3)">${stop.label}</div>`, className: '' });
      vanMarkers[vanId].stop = L.marker([stop.lat, stop.lng], { icon: stopIcon }).addTo(liveMap).bindPopup(`Stop: ${stop.label}`);
    }
    if (!vanMarkers[vanId].circle) {
      vanMarkers[vanId].circle = L.circle([stop.lat, stop.lng], { radius: PROXIMITY_RADIUS_KM * 1000, color: '#f59e0b', fillColor: '#f59e0b', fillOpacity: 0.08, weight: 1.5, dashArray: '5,5' }).addTo(liveMap);
    }
  }
}

function safeInitMap() {
  const dashEl = document.getElementById('dash-map');
  if (!dashEl) { setTimeout(safeInitMap, 300); return; }
  if (dashEl.offsetWidth === 0) { setTimeout(safeInitMap, 300); return; }
  if (dashMap) return;
  try {
    dashMap = L.map('dash-map', { preferCanvas: true, dragging: true }).setView([7.3022, 80.6352], 13);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OpenStreetMap contributors', maxZoom: 19 }).addTo(dashMap);
    updateFleetMap();
  } catch (e) { console.error('Dash map init failed:', e); }
}

function initLiveMap() {
  const liveEl = document.getElementById('live-map');
  if (!liveEl || liveEl.offsetWidth === 0) { setTimeout(initLiveMap, 300); return; }
  if (liveMap) return;
  try {
    liveMap = L.map('live-map', { preferCanvas: true }).setView([7.3022, 80.6352], 15);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OpenStreetMap contributors' }).addTo(liveMap);
    renderVanSelector();
    const sel = STATE.selectedVan || STATE.registeredVans[0];
    if (sel) selectVan(sel);
  } catch (e) { console.error('Live map init error:', e); }
}

// ── VAN SELECTOR ──────────────────────────────────────────────────────────────
function renderVanSelector() {
  const container = document.getElementById('van-selector-row');
  if (!container) return;
  const vans = STATE.registeredVans;
  const sel = STATE.selectedVan || vans[0];
  container.innerHTML = vans.map(v => `<button class="btn ${v === sel ? 'btn-primary' : 'btn-ghost'} btn-sm" onclick="selectVan('${v}')" style="margin-right:6px">🚌 ${v.toUpperCase()}</button>`).join('');
}

function selectVan(vanId) {
  STATE.selectedVan = vanId;
  STATE.location = STATE.vanLocations[vanId] || null;
  STATE.alerts   = STATE.vanAlerts[vanId]    || null;
  onLocationUpdate();
  onAlertsUpdate();
  updateLiveMap(vanId);
  renderVanSelector();
  const driver = Object.values(STATE.drivers).find(d => (d.vanId || '').toLowerCase() === vanId);
  setTxt('live-van-label', `${vanId.toUpperCase()} · ${driver?.name || vanId.toUpperCase()}`);
}

// ── LIVE UPDATE HANDLERS ──────────────────────────────────────────────────────
function onLocationUpdate() {
  const loc = STATE.location;
  if (!loc) return;
  const lat = parseFloat(loc.lat ?? loc.latitude);
  const lng = parseFloat(loc.lng ?? loc.longitude);
  if (Number.isNaN(lat) || Number.isNaN(lng)) return;
  const spd = parseFloat(loc.speed || 0).toFixed(1);
  const isActive = loc.isActive === true || loc.status === 'active';

  setTxt('van-speed', spd + ' km/h');
  setEl('van-active-chip', isActive ? '<span class="chip green">Active</span>' : '<span class="chip gray">Inactive</span>');
  setTxt('live-speed', spd);
  setTxt('live-lat',   lat.toFixed(6));
  setTxt('live-lng',   lng.toFixed(6));
  setTxt('live-updated', tsToDateTime(loc.lastUpdate));
  setTxt('map-coords', `${lat.toFixed(6)}, ${lng.toFixed(6)}`);
  setTxt('live-coords', `${lat.toFixed(6)}, ${lng.toFixed(6)}`);
  const gmapLink = el('gmap-link');
  if (gmapLink) gmapLink.href = `https://maps.google.com/?q=${lat},${lng}&z=16`;
  updateFleetMap();
  const sel = STATE.selectedVan || STATE.registeredVans[0];
  if (sel) updateLiveMap(sel);
}

function onAlertsUpdate() {
  const a = STATE.alerts;
  if (!a) return;
  setEl('van-drowsy-status', a.isDrowsy ? '<span style="color:var(--warn)">⚠ Drowsy</span>' : '<span style="color:var(--accent)">✓ Alert</span>');
  setTxt('van-last-alert', a.lastAlert || '—');
  setEl('live-drowsy-status', a.isDrowsy ? '<span style="color:var(--warn)">⚠ Detected</span>' : '<span style="color:var(--accent)">✓ OK</span>');
  setTxt('live-last-alert', a.lastAlert || '—');
  updateAlertBadge();
}

function onSOSUpdate() {
  const sos = STATE.sos;
  if (!sos) return;
  const active = sos.active === true;
  el('sos-bar').style.display = active ? 'flex' : 'none';
  if (active) setTxt('sos-msg', sos.message || 'Emergency SOS activated.');
  setTxt('stat-sos', active ? '1' : '0');
  setTxt('stat-sos-sub', active ? '⚠ EMERGENCY ACTIVE' : 'No active SOS');
  el('notif-pip').style.display = active ? 'block' : 'none';
  const sosCard = el('sos-card');
  if (sosCard) {
    sosCard.innerHTML = `<div style="display:flex;align-items:center;gap:14px"><div style="font-size:36px">${active ? '🆘' : '✅'}</div><div><div style="font-family:'Syne',sans-serif;font-size:15px;font-weight:700;color:${active ? 'var(--danger)' : 'var(--accent)'}">${active ? 'EMERGENCY ACTIVE' : 'No Active SOS'}</div><div style="font-size:12px;color:var(--text2);margin-top:4px">${sos.message || '—'}</div><div style="font-size:11px;color:var(--text3);font-family:'DM Mono',monospace;margin-top:4px">${tsToDateTime(sos.timestamp)}</div></div></div>${active ? `<button class="btn btn-ghost btn-sm" style="margin-top:14px" onclick="acknowledgeSOS()">Acknowledge</button>` : ''}`;
  }
  updateAlertBadge();
}

function onSafetyUpdate() {
  const s = STATE.safety;
  if (!s) return;
  const safetyEl = el('safety-status-list');
  if (!safetyEl) return;
  const rows = STATE.registeredVans.map(vid => {
    const driver = Object.values(STATE.drivers).find(d => (d.vanId||'').toLowerCase() === vid);
    const van = s[vid] || {};
    return `<div style="display:flex;align-items:center;gap:10px;padding:10px 0;border-bottom:1px solid var(--border)"><div style="width:8px;height:8px;border-radius:50%;background:${van.isDrowsy ? 'var(--warn)' : 'var(--accent)'}"></div><div style="flex:1"><div style="font-size:13px;font-weight:600">${vid.toUpperCase()} · ${driver?.name || 'Unknown'}</div><div style="font-size:11px;color:var(--text2);font-family:'DM Mono',monospace">${van.lastAlert || '—'} · ${tsToDateTime(van.timestamp)}</div></div>${statusChip(van.isDrowsy)}</div>`;
  }).join('');
  safetyEl.innerHTML = rows || '<div style="color:var(--text3);font-size:12px;padding:14px 0">No safety data</div>';
}

function updateAlertBadge() {
  const count = STATE.drowsyCount + (STATE.sos?.active ? 1 : 0);
  setTxt('badge-alerts', count > 99 ? '99+' : count);
}

// ── DASHBOARD ─────────────────────────────────────────────────────────────────
function renderDashboard() {
  const driverCount  = Object.keys(STATE.drivers).length;
  const studentCount = Object.keys(STATE.students).length;
  const vanCount     = STATE.registeredVans.length;
  const aiCount      = STATE.drowsyCount;

  setTxt('stat-vans', vanCount || driverCount);
  setTxt('stat-vans-sub', `${vanCount} van${vanCount !== 1 ? 's' : ''} · ${driverCount} driver${driverCount !== 1 ? 's' : ''}`);
  setTxt('stat-students', studentCount);
  setTxt('stat-students-sub', `${studentCount} student${studentCount !== 1 ? 's' : ''} enrolled`);
  setTxt('stat-drowsy', aiCount);
  setTxt('stat-drowsy-sub', `${aiCount} AI events logged`);

  let onBoard = 0, exited = 0, waiting = 0;
  Object.values(STATE.attendance).forEach(trip => {
    Object.values(trip).forEach(s => {
      if (s.status === 'onBoard')  onBoard++;
      if (s.status === 'exited')   exited++;
      if (s.status === 'waiting')  waiting++;
    });
  });
  const total = onBoard + exited + waiting || 1;
  setTxt('att-stat-label', `${onBoard + exited} / ${total} today`);
  setEl('att-breakdown', `<div style="display:flex;justify-content:space-between;font-size:13px;margin-bottom:4px"><span>On Board</span><span style="color:var(--accent);font-weight:600">${onBoard}</span></div><div class="progress-bar mb" style="margin-bottom:10px"><div class="progress-fill" style="width:${(onBoard/total*100).toFixed(0)}%"></div></div><div style="display:flex;justify-content:space-between;font-size:13px;margin-bottom:4px"><span>Exited</span><span style="color:var(--accent2);font-weight:600">${exited}</span></div><div class="progress-bar mb" style="margin-bottom:10px"><div class="progress-fill blue" style="width:${(exited/total*100).toFixed(0)}%"></div></div><div style="display:flex;justify-content:space-between;font-size:13px;margin-bottom:4px"><span>Waiting</span><span style="color:var(--text2);font-weight:600">${waiting}</span></div><div class="progress-bar"><div class="progress-fill" style="width:${(waiting/total*100).toFixed(0)}%;background:var(--text3)"></div></div>`);

  const logEntries = Object.entries(STATE.aiLogs).sort((a, b) => b[1].timestamp - a[1].timestamp).slice(0, 5);
  setEl('dash-drowsy-recent', logEntries.map(([k, v]) => `<div style="display:flex;align-items:center;gap:8px;padding:6px 0;border-bottom:1px solid var(--border)"><div style="width:6px;height:6px;border-radius:50%;background:var(--warn);flex-shrink:0"></div><div><div style="font-size:12px;font-weight:500">${v.event}</div><div style="font-size:10px;color:var(--text3);font-family:'DM Mono',monospace">${tsToDateTime(v.timestamp)}</div></div></div>`).join('') || '<div style="font-size:12px;color:var(--text3)">No logs</div>');

  buildActivityFeed();
  onLocationUpdate();
  onAlertsUpdate();
  onSOSUpdate();
  onSafetyUpdate();
}

function buildActivityFeed() {
  const items = [];
  Object.values(STATE.attendance).forEach(trip => {
    Object.values(trip).forEach(s => {
      items.push({ ts: s.boardTimestamp || s.exitTimestamp || 0, icon: 'fas fa-check', bg: 'rgba(0,229,160,.1)', color: 'var(--accent)', text: `<strong>${s.name}</strong> ${s.status === 'exited' ? 'exited' : 'boarded'} ${(s.vanId||'').toUpperCase()}`, sub: `${s.boardTime || ''} · ${s.grade || ''}` });
    });
  });
  const aiEntries = Object.entries(STATE.aiLogs).sort((a,b) => b[1].timestamp - a[1].timestamp).slice(0, 3);
  aiEntries.forEach(([k, v]) => {
    items.push({ ts: v.timestamp < 1e10 ? v.timestamp * 1000 : v.timestamp, icon: 'fas fa-eye-slash', bg: 'rgba(255,107,53,.1)', color: 'var(--warn)', text: 'AI drowsiness event — <strong>Driver</strong>', sub: tsToDateTime(v.timestamp) });
  });
  Object.values(STATE.messages).slice(-2).forEach(m => {
    items.push({ ts: m.timestamp, icon: 'fas fa-comment', bg: 'rgba(0,102,255,.1)', color: 'var(--accent2)', text: `<strong>${m.sender || (m.fromDriver ? 'Driver' : 'Parent')}</strong>: ${m.text}`, sub: tsToDateTime(m.timestamp) });
  });
  items.sort((a, b) => b.ts - a.ts);
  setEl('activity-list', items.slice(0, 10).map(item => `<li class="activity-item"><div class="activity-ico" style="background:${item.bg};color:${item.color}"><i class="${item.icon}"></i></div><div class="activity-txt"><p>${item.text}</p><span>${item.sub}</span></div></li>`).join('') || '<li class="activity-item"><div class="activity-txt"><p style="color:var(--text3)">No recent activity</p></div></li>');
}

function renderLive() { onLocationUpdate(); onAlertsUpdate(); }

function renderDrivers(filter = '') {
  const grid = el('drivers-grid');
  if (!grid) return;
  const entries = Object.entries(STATE.drivers).filter(([uid, d]) =>
    !filter || (d.name||'').toLowerCase().includes(filter) || (d.email||'').toLowerCase().includes(filter) || (d.licenseNumber||'').toLowerCase().includes(filter));
  if (!entries.length) { grid.innerHTML = '<div class="empty-state"><i class="fas fa-id-card"></i><p>No drivers found</p></div>'; return; }
  grid.innerHTML = entries.map(([uid, d]) => {
    const p = d.profile || {};
    const avatarContent = p.photoBase64 ? `<img src="data:image/jpeg;base64,${p.photoBase64}" alt="${d.name}">` : (d.name || '?')[0];
    return `<div class="driver-card"><div class="driver-top"><div class="driver-avatar">${avatarContent}</div><div><div class="driver-name">${d.name||'—'}</div><div class="driver-email">${d.email||'—'}</div><div style="margin-top:5px">${d.isActive ? '<span class="chip green">Active</span>' : '<span class="chip gray">Inactive</span>'}</div></div></div><div class="driver-meta"><div class="driver-meta-item"><label>Van</label><p>${(d.vanId||p.vehicle||'—').toUpperCase()}</p></div><div class="driver-meta-item"><label>License</label><p>${d.licenseNumber||p.license||'—'}</p></div><div class="driver-meta-item"><label>Phone</label><p style="font-size:12px">${d.phone||p.phone||'—'}</p></div><div class="driver-meta-item"><label>Route</label><p style="font-size:11px">${p.route||'—'}</p></div></div><div style="margin-top:10px;padding-top:10px;border-top:1px solid var(--border)"><div style="font-size:10px;color:var(--text3);font-family:'DM Mono',monospace">Registered: ${tsToDateTime(d.registeredAt)}</div><div style="font-size:10px;color:var(--text3);font-family:'DM Mono',monospace;margin-top:2px">UID: ${uid.substring(0,20)}...</div><div style="display:flex;gap:8px;margin-top:10px"><button class="btn btn-ghost btn-sm" style="flex:1;justify-content:center" onclick="editDriver('${uid}')">Edit</button><button class="btn btn-ghost btn-sm" style="flex:1;justify-content:center;color:var(--danger)" onclick="deleteDriver('${uid}')">Remove</button></div></div></div>`;
  }).join('');
}

function renderStudents(filter = '') {
  const tbody = el('students-tbody');
  if (!tbody) return;
  const entries = Object.entries(STATE.students).filter(([id, s]) =>
    !filter || (s.name||'').toLowerCase().includes(filter) || (s.parentEmail||'').toLowerCase().includes(filter) || (s.grade||'').toLowerCase().includes(filter));
  if (!entries.length) { tbody.innerHTML = '<tr><td colspan="7" class="loading-cell">No students found</td></tr>'; return; }
  tbody.innerHTML = entries.map(([id, s], i) => `<tr><td class="td-dim">${i+1}</td><td><strong>${s.name||'—'}</strong></td><td>${s.grade||'—'}</td><td class="td-mono">${(s.vanId||'—').toUpperCase()}</td><td class="td-dim">${s.parentEmail||'—'}</td><td class="td-mono">${s.driverId ? s.driverId.substring(0,14)+'...' : '—'}</td><td class="td-mono">${tsToDateTime(s.addedAt)}</td></tr>`).join('');
}

function renderParents(filter = '') {
  const tbody = el('parents-tbody');
  if (!tbody) return;
  const entries = Object.entries(STATE.parents).filter(([id, p]) =>
    !filter || (p.name||'').toLowerCase().includes(filter) || (p.email||'').toLowerCase().includes(filter));
  if (!entries.length) { tbody.innerHTML = '<tr><td colspan="7" class="loading-cell">No parents found</td></tr>'; return; }
  tbody.innerHTML = entries.map(([id, p], i) => `<tr>
    <td class="td-dim">${i+1}</td>
    <td><strong>${p.name||'—'}</strong></td>
    <td class="td-dim">${p.email||'—'}</td>
    <td class="td-dim">${p.contact_number||'—'}</td>
    <td class="td-dim" style="max-width:160px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${p.address||'—'}</td>
    <td class="td-mono">${tsToDate(p.created_at)}</td>
    <td><button class="btn btn-ghost btn-sm" style="color:var(--danger)" onclick="deleteParent('${id}')">Delete</button></td>
  </tr>`).join('');
}

async function addParentToFirebase() {
  const name     = el('p-name').value.trim();
  const email    = el('p-email').value.trim();
  const phone    = el('p-phone').value.trim();
  const address  = el('p-address').value.trim();
  const password = el('p-password').value;

  if (!name || !email || !phone) { toast('Name, email and phone are required', 'warn'); return; }
  if (!email.includes('@'))      { toast('Enter a valid email address', 'warn'); return; }
  if (password.length < 6)       { toast('Password must be at least 6 characters', 'warn'); return; }

  try {
    // 1. Create Firebase Auth user via REST API (sign-up endpoint)
    const apiKey = FIREBASE_CONFIG.apiKey;
    const authRes = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: true })
      }
    );
    const authData = await authRes.json();
    if (authData.error) throw new Error(authData.error.message);

    const uid = authData.localId;

    // 2. Write parent profile to Realtime Database
    await dbSet(`parents/${uid}`, {
      name,
      email,
      contact_number: phone,
      address,
      role: 'parent',
      created_at: Date.now(),
    });

    STATE.parents = await dbGet('parents') || {};
    renderParents();
    closeModal('add-parent-modal');
    toast(`Parent ${name} added successfully`, 'success');
    ['p-name','p-email','p-phone','p-address','p-password'].forEach(id => el(id).value = '');

  } catch (e) {
    const msg = e.message.includes('EMAIL_EXISTS')
      ? 'An account already exists with this email.'
      : e.message.includes('WEAK_PASSWORD')
      ? 'Password is too weak. Use at least 6 characters.'
      : 'Error: ' + e.message;
    toast(msg, 'danger');
  }
}

async function deleteParent(uid) {
  if (!confirm('Remove this parent from the database? Their Auth account will remain — contact Firebase Console to fully delete.')) return;
  try {
    await dbDelete(`parents/${uid}`);
    STATE.parents = await dbGet('parents') || {};
    renderParents();
    toast('Parent removed', 'warn');
  } catch (e) { toast('Error: ' + e.message, 'danger'); }
}

function renderAlerts() {
  const logEntries = Object.entries(STATE.aiLogs).sort((a, b) => b[1].timestamp - a[1].timestamp);
  setTxt('ai-log-count', `${logEntries.length} events`);
  setEl('alert-log-list', logEntries.slice(0, 60).map(([k, v], i) => `<div style="display:flex;align-items:center;gap:10px;padding:9px 0;border-bottom:1px solid var(--border)"><div style="width:7px;height:7px;border-radius:50%;background:var(--warn);flex-shrink:0"></div><div style="flex:1"><div style="font-size:13px;font-weight:500">#${logEntries.length - i} · ${v.event}</div><div style="font-size:11px;color:var(--text2);font-family:'DM Mono',monospace">${tsToDateTime(v.timestamp)}</div></div></div>`).join('') || '<div style="color:var(--text3);font-size:12px;padding:14px 0">No logs yet</div>');
  onSOSUpdate();
  onSafetyUpdate();
}

function renderAttendance() {
  const tbody = el('attendance-tbody');
  if (!tbody) return;

  // Populate van dropdown
  const vanSelect = el('att-van-filter');
  if (vanSelect) {
    const selectedVal = vanSelect.value;
    vanSelect.innerHTML = '<option value="">All Vans</option>' +
      STATE.registeredVans.map(v => `<option value="${v}" ${selectedVal === v ? 'selected' : ''}>${v.toUpperCase()}</option>`).join('');
  }
  const filterVan = vanSelect ? vanSelect.value : '';

  const rows = [];
  let onBoard = 0, exited = 0, waiting = 0;
  Object.entries(STATE.attendance).forEach(([tripId, students]) => {
    setTxt('att-trip-label', tripId);
    Object.values(students).forEach(s => {
      const sVan = (s.vanId || '').toLowerCase();
      if (filterVan && sVan && sVan !== filterVan) return;
      if (s.status === 'onBoard')  onBoard++;
      if (s.status === 'exited')   exited++;
      if (s.status === 'waiting')  waiting++;
      rows.push(`<tr><td class="td-dim">${rows.length+1}</td><td><strong>${s.name||'—'}</strong></td><td>${s.grade||'—'}</td><td class="td-mono">${(s.vanId||'—').toUpperCase()}</td><td>${statusChip(s.status)}</td><td class="td-mono">${s.boardTime||'—'}</td><td class="td-mono">${s.exitTime||'—'}</td><td class="td-dim">${s.parentEmail||'—'}</td></tr>`);
    });
  });
  tbody.innerHTML = rows.join('') || '<tr><td colspan="8" class="loading-cell">No attendance records</td></tr>';
  setEl('att-stats', `<span class="chip green" style="margin-right:6px">On Board: ${onBoard}</span><span class="chip blue" style="margin-right:6px">Exited: ${exited}</span><span class="chip gray">Waiting: ${waiting}</span>`);
}

// ── MULTI-VAN MESSAGES ────────────────────────────────────────────────────────
let _msgListeners = [];

function startMessagesPolling() {
  // Cancel any previous listeners
  _msgListeners.forEach(cancel => cancel());
  _msgListeners = [];
  const vans = STATE.registeredVans;
  vans.forEach(vanId => {
    const cancel = dbListen(`messages/${vanId}`, data => {
      STATE.vanMessages[vanId] = data || {};
      // Keep STATE.messages in sync with selected van
      if (STATE.selectedMsgVan === vanId) {
        STATE.messages = STATE.vanMessages[vanId];
        renderMessages();
      }
      renderMsgVanList();
    }, 5000);
    _msgListeners.push(cancel);
  });
}

function renderMsgVanList() {
  const container = document.getElementById('msg-van-list');
  if (!container) return;
  const vans = STATE.registeredVans;
  if (!vans.length) {
    container.innerHTML = '<div style="text-align:center;color:var(--text3);font-size:13px;padding:20px">No vans registered yet</div>';
    return;
  }
  container.innerHTML = vans.map(vanId => {
    const msgs = STATE.vanMessages[vanId] || {};
    const entries = Object.values(msgs).sort((a,b) => (a.timestamp||0) - (b.timestamp||0));
    const last = entries[entries.length - 1];
    const preview = last ? `${last.sender || (last.fromDriver ? 'Driver' : 'Parent')}: ${last.text}` : 'No messages yet';
    const count = entries.length;
    const driver = Object.values(STATE.drivers).find(d => (d.vanId||'').toLowerCase() === vanId);
    const driverName = driver?.name || vanId.toUpperCase();
    const isSelected = STATE.selectedMsgVan === vanId;
    return `<div onclick="selectMsgVan('${vanId}')" style="padding:12px;border-radius:8px;margin-bottom:8px;cursor:pointer;background:${isSelected ? 'rgba(0,229,160,.12)' : 'rgba(255,255,255,.03)'};border:1px solid ${isSelected ? 'rgba(0,229,160,.4)' : 'rgba(255,255,255,.06)'}">
      <div style="display:flex;align-items:center;gap:10px">
        <div style="width:36px;height:36px;border-radius:9px;background:var(--accent2);display:flex;align-items:center;justify-content:center;font-size:16px;flex-shrink:0">🚌</div>
        <div style="flex:1;min-width:0">
          <div style="font-size:13px;font-weight:600">${vanId.toUpperCase()} · ${driverName}</div>
          <div style="font-size:11px;color:var(--text2);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${preview}</div>
        </div>
        ${count ? `<div style="background:var(--accent);color:#000;border-radius:99px;font-size:10px;font-weight:700;padding:2px 7px">${count}</div>` : ''}
      </div>
    </div>`;
  }).join('');
}

function selectMsgVan(vanId) {
  STATE.selectedMsgVan = vanId;
  STATE.messages = STATE.vanMessages[vanId] || {};
  const driver = Object.values(STATE.drivers).find(d => (d.vanId||'').toLowerCase() === vanId);
  const driverName = driver?.name || vanId.toUpperCase();
  const titleEl = document.getElementById('msg-chat-title');
  if (titleEl) titleEl.textContent = `${vanId.toUpperCase()} · ${driverName}`;
  renderMsgVanList();
  renderMessages();
}

function renderMessages() {
  const chatDiv = el('chat-messages');
  if (!chatDiv) return;
  const entries = Object.entries(STATE.messages).sort((a, b) => a[1].timestamp - b[1].timestamp);
  setTxt('msg-count', `${entries.length} messages`);
  if (!entries.length) { chatDiv.innerHTML = '<div style="text-align:center;color:var(--text3);font-size:13px;padding:20px">No messages yet</div>'; return; }
  chatDiv.innerHTML = entries.map(([k, m]) => {
    const isDriver = m.fromDriver === true;
    const isAdmin  = m.sender === 'Admin';
    const bubbleCls = isAdmin ? 'admin' : isDriver ? 'driver' : 'parent';
    const wrapCls   = (isAdmin || !isDriver) ? 'right' : '';
    const who = m.sender || (isDriver ? 'Driver' : 'Parent');
    return `<div class="chat-wrap ${wrapCls}"><div class="bubble ${bubbleCls}"><div class="bubble-who">${who}</div><div class="bubble-txt">${m.text}</div><div class="bubble-time">${tsToDateTime(m.timestamp)}</div></div></div>`;
  }).join('');
  chatDiv.scrollTop = chatDiv.scrollHeight;
}

async function sendMessage() {
  const input = el('msg-input');
  const text  = input.value.trim();
  if (!text) return;
  const vanId = STATE.selectedMsgVan;
  if (!vanId) { toast('Please select a van first', 'warn'); return; }
  try {
    await dbPush(`messages/${vanId}`, { fromDriver: false, sender: 'Admin', text, timestamp: Date.now() });
    input.value = '';
    toast('Message sent', 'success');
    const msgs = await dbGet(`messages/${vanId}`);
    STATE.vanMessages[vanId] = msgs || {};
    STATE.messages = STATE.vanMessages[vanId];
    renderMessages();
    renderMsgVanList();
  } catch (e) { toast('Send failed: ' + e.message, 'danger'); }
}



function renderTrips() {
  const tbody = el('trips-tbody');
  if (!tbody) return;
  const entries = Object.entries(STATE.trips);
  setTxt('trip-count', `${entries.length} trips`);
  if (!entries.length) { tbody.innerHTML = '<tr><td colspan="7" class="loading-cell">No trips found</td></tr>'; return; }
  tbody.innerHTML = entries.map(([id, t]) => `<tr><td class="td-mono">${id}</td><td class="td-mono">${(t.vanId||'—').toUpperCase()}</td><td class="td-dim">${statusChip(t.status)}</td><td class="td-mono">${tsToDateTime(t.startTime)}</td><td class="td-mono">${t.endTime ? tsToDateTime(t.endTime) : '—'}</td><td class="td-mono">${t.lat ? `${parseFloat(t.lat).toFixed(5)}, ${parseFloat(t.lng).toFixed(5)}` : '—'}</td><td class="td-mono">${t.speed != null ? parseFloat(t.speed).toFixed(2)+' km/h' : '—'}</td></tr>`).join('');
}

async function acknowledgeSOS() {
  try {
    await dbUpdate('sos', { active: false });
    toast('SOS acknowledged', 'success');
    STATE.sos = await dbGet('sos');
    onSOSUpdate();
  } catch (e) { toast('Failed: ' + e.message, 'danger'); }
}

async function addDriverToFirebase() {
  const name    = el('d-name').value.trim();
  const phone   = el('d-phone').value.trim();
  const email   = el('d-email').value.trim();
  const license = el('d-license').value.trim();
  const van     = el('d-van').value.trim().toLowerCase();
  const route   = el('d-route').value.trim();
  if (!name || !email) { toast('Name and email are required', 'warn'); return; }
  if (!van) { toast('Van ID is required (e.g. van01, van02)', 'warn'); return; }
  try {
    const key = `driver_${Date.now()}`;
    await dbSet(`drivers/${key}`, { name, phone, email, licenseNumber: license, vanId: van, role: 'driver', isActive: true, registeredAt: Date.now(), profile: { name, phone, email, license, vehicle: van, route, updatedAt: Date.now() } });
    // Init location slot for new van
    const existingLoc = await dbGet(`v1/locations/${van}`);
    if (!existingLoc) {
      await dbSet(`v1/locations/${van}`, { lat: 7.3022, lng: 80.6352, speed: 0, isActive: false, lastUpdate: Date.now() });
    }
    STATE.drivers = await dbGet('drivers') || {};
    getRegisteredVans();
    startMessagesPolling(); // pick up new van's message channel
    renderDrivers();
    closeModal('add-driver-modal');
    toast(`Driver ${name} added · Van ${van.toUpperCase()} registered`, 'success');
    ['d-name','d-phone','d-email','d-license','d-van','d-route'].forEach(id => el(id).value = '');
  } catch (e) { toast('Error: ' + e.message, 'danger'); }
}

async function addStudentToFirebase() {
  const name        = el('s-name').value.trim();
  const grade       = el('s-grade').value.trim();
  const parentEmail = el('s-parent').value.trim();
  const vanId       = el('s-van').value.trim();
  const driverId    = el('s-driver').value.trim();
  if (!name || !parentEmail) { toast('Name and parent email are required', 'warn'); return; }
  try {
    const sid = `stu_${name.toLowerCase().replace(/\s+/g,'_')}_${Date.now()}`;
    await dbSet(`students/${sid}`, { name, grade, parentEmail, vanId, driverId, addedAt: Date.now() });
    STATE.students = await dbGet('students') || {};
    renderStudents();
    closeModal('add-student-modal');
    toast(`Student ${name} added`, 'success');
    ['s-name','s-grade','s-parent','s-van','s-driver'].forEach(id => el(id).value = '');
  } catch (e) { toast('Error: ' + e.message, 'danger'); }
}

async function saveVanStop() {
  const vanId = el('stop-van').value.trim().toLowerCase();
  const lat   = el('stop-lat').value.trim();
  const lng   = el('stop-lng').value.trim();
  const label = el('stop-label').value.trim();
  if (!vanId || !lat || !lng || !label) { toast('All fields required', 'warn'); return; }
  if (isNaN(parseFloat(lat)) || isNaN(parseFloat(lng))) { toast('Invalid coordinates', 'warn'); return; }
  setVanStop(vanId, lat, lng, label);
  closeModal('van-stops-modal');
  ['stop-van','stop-lat','stop-lng','stop-label'].forEach(id => el(id).value = '');
}

async function deleteDriver(uid) {
  if (!confirm('Remove this driver from Firebase?')) return;
  try {
    await dbDelete(`drivers/${uid}`);
    STATE.drivers = await dbGet('drivers') || {};
    getRegisteredVans();
    renderDrivers();
    toast('Driver removed', 'warn');
  } catch (e) { toast('Error: ' + e.message, 'danger'); }
}

function editDriver(uid) { toast('Edit: use Firebase Console or connect backend write permissions', 'info'); }

function showPage(pageName) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  const page = document.getElementById(`page-${pageName}`);
  if (page) page.classList.add('active');
  document.querySelectorAll('.nav-item').forEach(item => item.classList.toggle('active', item.dataset.page === pageName));
  const titles = { dashboard:'Dashboard', live:'Live Tracking', drivers:'Drivers', students:'Students', parents:'Parents', alerts:'Alerts', attendance:'Attendance', messages:'Messages', trips:'Trips' };
  const titleEl = document.getElementById('page-title');
  if (titleEl) titleEl.textContent = titles[pageName] || 'Dashboard';
  if (pageName === 'dashboard' || pageName === 'live') handleMapTransition(pageName);
}

function handleMapTransition(pageName) {
  setTimeout(() => {
    if (pageName === 'live') {
      if (!liveMap) initLiveMap();
      else { liveMap.invalidateSize(); const sel = STATE.selectedVan || STATE.registeredVans[0]; if (sel) updateLiveMap(sel); }
    } else {
      if (!dashMap) safeInitMap();
      else { dashMap.invalidateSize(); updateFleetMap(); }
    }
  }, 200);
}

function openModal(id)  { el(id).classList.add('open'); }
function closeModal(id) { el(id).classList.remove('open'); }

document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.modal-overlay').forEach(o =>
    o.addEventListener('click', e => { if (e.target === o) o.classList.remove('open'); }));
  busIcon = L.icon({ iconUrl: 'https://cdn-icons-png.flaticon.com/512/3448/3448339.png', iconSize: [35, 35], iconAnchor: [17, 17] });
  bootstrap();
  safeInitMap();
});