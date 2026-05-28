#!/usr/bin/env node
/**
 * Kiba — Firebase seed script
 * Creates test users for each role so you can test login immediately.
 *
 * Usage:
 *   npm install firebase-admin
 *   node scripts/seed_users.js
 *
 * Prerequisites:
 *   1. Download service account key from:
 *      Firebase Console → Project Settings → Service accounts → Generate new private key
 *   2. Save it as scripts/serviceAccountKey.json
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'kiba-3f0fa',
});

const auth = admin.auth();
const db = admin.firestore();
// Point to default Firestore database
db.settings({ ignoreUndefinedProperties: true });


const TEST_USERS = [
  {
    email: 'fa@kiba.app',
    password: 'Kiba@1234',
    displayName: 'Arjun Kumar (FA)',
    role: 'field_advisor',
    phone: '+91 9876543210',
  },
  {
    email: 'clerk@kiba.app',
    password: 'Kiba@1234',
    displayName: 'Priya Sharma (Clerk)',
    role: 'clerk',
    phone: '+91 9876543211',
  },
  {
    email: 'admin@kiba.app',
    password: 'Kiba@1234',
    displayName: 'Kiba Admin',
    role: 'admin',
    phone: '+91 9876543212',
  },
];

async function seedUsers() {
  console.log('🌱 Seeding Kiba test users...\n');

  for (const user of TEST_USERS) {
    try {
      // Create or get Firebase Auth user
      let authUser;
      try {
        authUser = await auth.getUserByEmail(user.email);
        console.log(`⚡ Auth user already exists: ${user.email}`);
      } catch {
        authUser = await auth.createUser({
          email: user.email,
          password: user.password,
          displayName: user.displayName,
        });
        console.log(`✅ Created auth user: ${user.email}`);
      }

      // Create Firestore profile
      await db.collection('users').doc(authUser.uid).set({
        email: user.email,
        displayName: user.displayName,
        role: user.role,
        phone: user.phone,
        isActive: true,
        createdAt: new Date().toISOString(),
      }, { merge: true });

      console.log(`   → Firestore profile saved (role: ${user.role})\n`);
    } catch (err) {
      console.error(`❌ Failed for ${user.email}:`, err.message);
    }
  }

  console.log('─────────────────────────────────────────');
  console.log('Test credentials:');
  TEST_USERS.forEach(u => {
    console.log(`  ${u.role.padEnd(15)} ${u.email}  /  ${u.password}`);
  });
  console.log('─────────────────────────────────────────');

  process.exit(0);
}

seedUsers();
