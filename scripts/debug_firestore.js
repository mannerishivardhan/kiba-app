#!/usr/bin/env node
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

console.log('Project ID from key:', serviceAccount.project_id);
console.log('Client email:', serviceAccount.client_email);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

// Explicitly reference the default database
const db = admin.firestore();
db.settings({ databaseId: '(default)', ignoreUndefinedProperties: true });

async function run() {
  console.log('\nTesting Firestore write...');
  try {
    const ref = db.collection('users').doc('_test_');
    await ref.set({ ping: true, ts: new Date().toISOString() });
    console.log('✅ Firestore write SUCCESS');
    await ref.delete();
    console.log('✅ Firestore delete SUCCESS');
  } catch (e) {
    console.error('❌ Error code:', e.code);
    console.error('❌ Error message:', e.message);
    console.error('❌ Full error:', JSON.stringify(e, null, 2));
  }
  process.exit(0);
}

run();
