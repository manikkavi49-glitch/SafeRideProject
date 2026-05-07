// ── FIREBASE CONFIG ─────────────────────────────────────────────────────────
// Project: saferide-g5  |  DB: saferide-g5-default-rtdb
const FIREBASE_CONFIG = {
  apiKey: "AIzaSyDxyrPsg21_-76YSyC3GiebjR87k1vnM4c",
  authDomain: "saferide-g5.firebaseapp.com",
  databaseURL: "https://saferide-g5-default-rtdb.firebaseio.com",
  projectId: "saferide-g5",
  storageBucket: "saferide-g5.firebasestorage.app",
  messagingSenderId: "116790427666",
  appId: "1:116790427666:web:d2941f71b85ad16f7498cb"
};

// ── REALTIME DATABASE REST API ────────────────────────────────────────────────
const DB_URL = "https://saferide-g5-default-rtdb.firebaseio.com";

/**
 * Get Firebase ID token for authenticated REST write calls.
 * Returns null if not signed in (read-only paths don't need it).
 */
async function getIdToken() {
  try {
    const user = firebase.auth().currentUser;
    if (!user) return null;
    return await user.getIdToken();
  } catch (e) {
    console.warn('getIdToken failed:', e.message);
    return null;
  }
}

/**
 * Read a path from Firebase Realtime Database via REST.
 * Returns parsed JSON or null on failure.
 */
async function dbGet(path) {
  try {
    const res = await fetch(`${DB_URL}/${path}.json`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (e) {
    console.warn(`dbGet(${path}) failed:`, e.message);
    return null;
  }
}

/**
 * Write/overwrite a path via REST (PUT). Requires auth token.
 */
async function dbSet(path, value) {
  const token = await getIdToken();
  if (!token) throw new Error('Not authenticated');
  const res = await fetch(`${DB_URL}/${path}.json?auth=${token}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(value)
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

/**
 * Push (POST) a new child under a path. Requires auth token.
 */
async function dbPush(path, value) {
  const token = await getIdToken();
  if (!token) throw new Error('Not authenticated');
  const res = await fetch(`${DB_URL}/${path}.json?auth=${token}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(value)
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

/**
 * Update specific fields (PATCH). Requires auth token.
 */
async function dbUpdate(path, value) {
  const token = await getIdToken();
  if (!token) throw new Error('Not authenticated');
  const res = await fetch(`${DB_URL}/${path}.json?auth=${token}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(value)
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

/**
 * Delete a path (DELETE). Requires auth token.
 */
async function dbDelete(path) {
  const token = await getIdToken();
  if (!token) throw new Error('Not authenticated');
  const res = await fetch(`${DB_URL}/${path}.json?auth=${token}`, { method: 'DELETE' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return true;
}

/**
 * Poll a path every N ms, calling callback(data) each time.
 * Returns a cancel function.
 */
function dbListen(path, callback, intervalMs = 4000) {
  let active = true;
  const poll = async () => {
    if (!active) return;
    const data = await dbGet(path);
    if (active) callback(data);
    if (active) setTimeout(poll, intervalMs);
  };
  poll();
  return () => { active = false; };
}