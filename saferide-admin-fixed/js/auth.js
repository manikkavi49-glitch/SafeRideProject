// ─────────────────────────────────────────────────────────────────────────────
// auth.js  –  Firebase Authentication helpers
// Used by: login.html, register.html, index.html
// ─────────────────────────────────────────────────────────────────────────────

const FIREBASE_CONFIG = {
  apiKey:            "AIzaSyDxyrPsg21_-76YSyC3GiebjR87k1vnM4c",
  authDomain:        "saferide-g5.firebaseapp.com",
  databaseURL:       "https://saferide-g5-default-rtdb.firebaseio.com",
  projectId:         "saferide-g5",
  storageBucket:     "saferide-g5.firebasestorage.app",
  messagingSenderId: "116790427666",
  appId:             "1:116790427666:web:d2941f71b85ad16f7498cb"
};

// Initialise Firebase (guard against double-init when both auth.js + firebase.js load)
if (!firebase.apps.length) {
  firebase.initializeApp(FIREBASE_CONFIG);
}

const auth = firebase.auth();
const DB_URL = "https://saferide-g5-default-rtdb.firebaseio.com";

// ── Session helpers ───────────────────────────────────────────────────────────

/** Save minimal admin profile to sessionStorage after login */
function saveSession(user, profile) {
  sessionStorage.setItem('sr_admin', JSON.stringify({
    uid:   user.uid,
    email: user.email,
    name:  profile?.name || user.email.split('@')[0],
    role:  profile?.role || 'admin',
  }));
}

/** Read session */
function getSession() {
  try { return JSON.parse(sessionStorage.getItem('sr_admin')); }
  catch { return null; }
}

/** Clear session and redirect to login */
function logout() {
  auth.signOut().finally(() => {
    sessionStorage.removeItem('sr_admin');
    window.location.href = 'login.html';
  });
}

// ── Guard: call this at top of index.html ─────────────────────────────────────
/**
 * Waits for Firebase Auth state. If no user → redirect to login.html.
 * Resolves with the Firebase user object when authenticated.
 */
function requireAuth() {
  return new Promise((resolve) => {
    auth.onAuthStateChanged(async (user) => {
      if (!user) {
        window.location.href = 'login.html';
        return;
      }
      // Fetch admin profile from admins/{uid} in Realtime DB
      let profile = null;
      try {
        const res = await fetch(`${DB_URL}/admins/${user.uid}.json`);
        if (res.ok) profile = await res.json();
      } catch (_) {}

      saveSession(user, profile);
      resolve({ user, profile });
    });
  });
}

// ── Login ─────────────────────────────────────────────────────────────────────
async function loginWithEmail(email, password) {
  const cred = await auth.signInWithEmailAndPassword(email, password);

  // Fetch profile from admins/{uid}
  let profile = null;
  try {
    const res = await fetch(`${DB_URL}/admins/${cred.user.uid}.json`);
    if (res.ok) profile = await res.json();
  } catch (_) {}

  saveSession(cred.user, profile);
  return { user: cred.user, profile };
}

// ── Register ──────────────────────────────────────────────────────────────────
async function registerAdmin(name, email, password) {
  const cred = await auth.createUserWithEmailAndPassword(email, password);

  // Update display name in Firebase Auth
  await cred.user.updateProfile({ displayName: name });

  // Write admin record to Realtime DB → admins/{uid}
  const adminRecord = {
    name,
    email,
    role: 'admin',
    createdAt: Date.now(),
    isActive: true,
  };

  // Must pass the Firebase ID token so REST write is authenticated
  const idToken = await cred.user.getIdToken();
  const writeRes = await fetch(`${DB_URL}/admins/${cred.user.uid}.json?auth=${idToken}`, {
    method:  'PUT',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify(adminRecord),
  });
  if (!writeRes.ok) throw new Error(`Failed to save admin record: ${writeRes.status}`);

  saveSession(cred.user, adminRecord);
  return { user: cred.user, profile: adminRecord };
}