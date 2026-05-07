// ── UTILITIES ────────────────────────────────────────────────────────────────

function el(id) { return document.getElementById(id); }

function tsToTime(ts) {
  if (!ts) return '—';
  // Firebase timestamps can be seconds (float) or ms (int > 1e10)
  const d = new Date(ts < 1e10 ? ts * 1000 : ts);
  return d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
}

function tsToDate(ts) {
  if (!ts) return '—';
  const d = new Date(ts < 1e10 ? ts * 1000 : ts);
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
}

function tsToDateTime(ts) {
  if (!ts) return '—';
  const d = new Date(ts < 1e10 ? ts * 1000 : ts);
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short' }) +
    ' ' + d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
}

function statusChip(s) {
  const map = {
    onBoard:   ['green',  'On Board'],
    exited:    ['blue',   'Exited'],
    waiting:   ['gray',   'Waiting'],
    active:    ['green',  'Active'],
    completed: ['blue',   'Completed'],
    true:      ['orange', 'Drowsy'],
    false:     ['green',  'Alert'],
  };
  const [cls, label] = map[String(s)] || ['gray', s || '—'];
  return `<span class="chip ${cls}">${label}</span>`;
}

function toast(msg, type = 'success') {
  const t = el('toast');
  const colors = { success: 'var(--accent)', warn: 'var(--warn)', danger: 'var(--danger)', info: 'var(--accent2)' };
  const icons  = { success: '✓', warn: '⚠', danger: '🆘', info: 'ℹ' };
  t.innerHTML = `<span style="color:${colors[type]};font-weight:700;flex-shrink:0">${icons[type]}</span><span>${msg}</span>`;
  t.style.transform = 'translateY(0)';
  t.style.opacity = '1';
  clearTimeout(t._timer);
  t._timer = setTimeout(() => { t.style.transform = 'translateY(80px)'; t.style.opacity = '0'; }, 3500);
}

function setEl(id, html) {
  const e = el(id);
  if (e) e.innerHTML = html;
}

function setTxt(id, text) {
  const e = el(id);
  if (e) e.textContent = text;
}

function showSpinner(id) {
  setEl(id, '<span class="spinner"></span> Loading...');
}

// ── NAVIGATION ────────────────────────────────────────────────────────────────
const PAGE_META = {
  dashboard:  ['Dashboard',   'Live overview · saferide-g5'],
  live:       ['Live Tracking','v1/locations · GPS polling every 4s'],
  drivers:    ['Drivers',     'drivers/ collection'],
  students:   ['Students',    'students/ collection'],
  parents:    ['Parents',     'parents/ collection'],
  alerts:     ['Alerts',      'ai_logs/ · safety_status/ · sos/'],
  attendance: ['Attendance',  'attendance/trip_van01_20260429'],
  messages:   ['Messages',    'messages/van01/'],
  trips:      ['Trips',       'trips/ collection'],
};

function showPage(id) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));

  const page = el('page-' + id);
  if (page) page.classList.add('active');

  const navEl = document.querySelector(`.nav-item[data-page="${id}"]`);
  if (navEl) navEl.classList.add('active');

  const [title, sub] = PAGE_META[id] || [id, ''];
  setTxt('page-title', title);
  setTxt('page-sub', sub);
}