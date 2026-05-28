#!/usr/bin/env node
/**
 * Writes Firestore user profile documents using REST API directly
 * (bypasses firebase-admin Firestore region issue).
 */
const { initializeApp, cert, getApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const https = require('https');

const serviceAccount = require('./serviceAccountKey.json');

const app = initializeApp({
  credential: cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const auth = getAuth(app);
const PROJECT = serviceAccount.project_id;

const PROFILES = [
  { email: 'fa@kiba.app',    displayName: 'Arjun Kumar',  role: 'field_advisor', phone: '+91 9876543210' },
  { email: 'clerk@kiba.app', displayName: 'Priya Sharma', role: 'clerk',         phone: '+91 9876543211' },
  { email: 'admin@kiba.app', displayName: 'Kiba Admin',   role: 'admin',         phone: '+91 9876543212' },
];

function toFirestoreFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    if (typeof v === 'string')  fields[k] = { stringValue: v };
    if (typeof v === 'boolean') fields[k] = { booleanValue: v };
  }
  return fields;
}

async function firestoreSet(token, docPath, data) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ fields: toFirestoreFields(data) });
    const options = {
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT}/databases/(default)/documents/${docPath}`,
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    };
    const req = https.request(options, res => {
      let raw = '';
      res.on('data', c => raw += c);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) resolve(JSON.parse(raw));
        else reject(new Error(`HTTP ${res.statusCode}: ${raw}`));
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function run() {
  console.log('📝 Writing Firestore profiles via REST API...\n');
  console.log('Project:', PROJECT, '\n');

  // Get access token from the credential
  const credential = cert(serviceAccount);
  const tokenObj = await app.options.credential.getAccessToken();
  const token = tokenObj.access_token;

  for (const profile of PROFILES) {
    try {
      const userRecord = await auth.getUserByEmail(profile.email);
      const doc = {
        email:       profile.email,
        displayName: profile.displayName,
        role:        profile.role,
        phone:       profile.phone,
        isActive:    true,
        createdAt:   new Date().toISOString(),
      };
      await firestoreSet(token, `users/${userRecord.uid}`, doc);
      console.log(`✅ ${profile.role.padEnd(15)} ${profile.email}`);
      console.log(`   UID: ${userRecord.uid}\n`);
    } catch (e) {
      console.error(`❌ ${profile.email}: ${e.message}\n`);
    }
  }

  console.log('─────────────────────────────────────────');
  PROFILES.forEach(p =>
    console.log(`  ${p.role.padEnd(15)} ${p.email}  /  Kiba@1234`)
  );
  console.log('─────────────────────────────────────────');
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
