#!/usr/bin/env node
/**
 * Kiba — Full reset + seed
 *
 * 1. Deletes every Firebase Auth user
 * 2. Wipes every Firestore collection recursively
 * 3. Seeds fresh users (admin + FA × 3 + clerk × 2) with complete profiles
 * 4. Seeds the employee-ID counter and default attendance thresholds
 *
 * Usage:
 *   cd scripts && node reset_and_seed.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId:  serviceAccount.project_id,
});

const auth = admin.auth();
const db   = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

const FieldValue  = admin.firestore.FieldValue;
const Timestamp   = admin.firestore.Timestamp;

// ─────────────────────────────────────────────────────────────────────────────
//  SEED DATA
// ─────────────────────────────────────────────────────────────────────────────

const SEED_USERS = [
  // ── Admin ────────────────────────────────────────────────────────────────
  {
    email:       'admin@kiba.app',
    password:    'Kiba@1234',
    displayName: 'Ravi Shankar',
    role:        'admin',
    employeeId:  'AD-001',
    phone:       '+91 98765 00001',
    age:         38,
    gender:      'male',
    aadharNo:    'XXXX-XXXX-0001',
    panCard:     'RAVXX0001R',
    emergencyContactName:  'Lakshmi Shankar',
    emergencyContactPhone: '+91 98765 10001',
    address:     '12, Anna Nagar, Chennai, Tamil Nadu — 600040',
  },

  // ── Field Advisors ────────────────────────────────────────────────────────
  {
    email:       'fa1@kiba.app',
    password:    'Kiba@1234',
    displayName: 'Arjun Mehta',
    role:        'field_advisor',
    employeeId:  'FA-001',
    phone:       '+91 98765 00101',
    age:         27,
    gender:      'male',
    aadharNo:    'XXXX-XXXX-0101',
    panCard:     'ARJXX0101A',
    emergencyContactName:  'Sunita Mehta',
    emergencyContactPhone: '+91 98765 10101',
    address:     '45, Koramangala 5th Block, Bengaluru, Karnataka — 560095',
  },
  {
    email:       'fa2@kiba.app',
    password:    'Kiba@1234',
    displayName: 'Divya Nair',
    role:        'field_advisor',
    employeeId:  'FA-002',
    phone:       '+91 98765 00102',
    age:         24,
    gender:      'female',
    aadharNo:    'XXXX-XXXX-0102',
    panCard:     'DIVXX0102D',
    emergencyContactName:  'Prakash Nair',
    emergencyContactPhone: '+91 98765 10102',
    address:     '8, Palarivattom, Ernakulam, Kerala — 682025',
  },
  {
    email:       'fa3@kiba.app',
    password:    'Kiba@1234',
    displayName: 'Suresh Babu',
    role:        'field_advisor',
    employeeId:  'FA-003',
    phone:       '+91 98765 00103',
    age:         31,
    gender:      'male',
    aadharNo:    'XXXX-XXXX-0103',
    panCard:     'SURXX0103S',
    emergencyContactName:  'Kamala Babu',
    emergencyContactPhone: '+91 98765 10103',
    address:     '22, T Nagar, Chennai, Tamil Nadu — 600017',
  },

  // ── Clerks ────────────────────────────────────────────────────────────────
  {
    email:       'clerk1@kiba.app',
    password:    'Kiba@1234',
    displayName: 'Priya Iyer',
    role:        'clerk',
    employeeId:  'CL-001',
    phone:       '+91 98765 00201',
    age:         26,
    gender:      'female',
    aadharNo:    'XXXX-XXXX-0201',
    panCard:     'PRIXX0201P',
    emergencyContactName:  'Venkat Iyer',
    emergencyContactPhone: '+91 98765 10201',
    address:     '3, Mylapore, Chennai, Tamil Nadu — 600004',
  },
  {
    email:       'clerk2@kiba.app',
    password:    'Kiba@1234',
    displayName: 'Karthik Raja',
    role:        'clerk',
    employeeId:  'CL-002',
    phone:       '+91 98765 00202',
    age:         29,
    gender:      'male',
    aadharNo:    'XXXX-XXXX-0202',
    panCard:     'KARXX0202K',
    emergencyContactName:  'Malathi Raja',
    emergencyContactPhone: '+91 98765 10202',
    address:     '17, Velachery Main Road, Chennai, Tamil Nadu — 600042',
  },
];

// Default attendance thresholds (matches AttendanceThreshold model)
const DEFAULT_THRESHOLDS = {
  minKmForPresent:          10.0,
  minVisitsForPresent:      3,
  minDutyHoursForPresent:   7.0,
  lateCheckinCutoffHour:    9,
  lateCheckinCutoffMinute:  30,
  updatedAt:                FieldValue.serverTimestamp(),
};

// ─────────────────────────────────────────────────────────────────────────────
//  STEP 1 — Delete all Firebase Auth users
// ─────────────────────────────────────────────────────────────────────────────

async function deleteAllAuthUsers() {
  console.log('\n── Step 1: Deleting Firebase Auth users ─────────────────────');
  const uids = [];
  let pageToken;

  do {
    const result = await auth.listUsers(1000, pageToken);
    result.users.forEach(u => uids.push(u.uid));
    pageToken = result.pageToken;
  } while (pageToken);

  if (uids.length === 0) {
    console.log('  No auth users to delete.');
    return;
  }

  // deleteUsers accepts max 1000 per call
  for (let i = 0; i < uids.length; i += 1000) {
    const batch = uids.slice(i, i + 1000);
    const result = await auth.deleteUsers(batch);
    console.log(`  ✓ Deleted ${result.successCount} auth users`);
    if (result.failureCount > 0) {
      result.errors.forEach(e => console.warn(`  ✗ Failed: ${e.error.message}`));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STEP 2 — Wipe all Firestore collections
// ─────────────────────────────────────────────────────────────────────────────

async function deleteAllFirestore() {
  console.log('\n── Step 2: Wiping Firestore collections ──────────────────────');

  const collections = await db.listCollections();

  if (collections.length === 0) {
    console.log('  Firestore is already empty.');
    return;
  }

  for (const col of collections) {
    await db.recursiveDelete(col);
    console.log(`  ✓ Deleted collection: ${col.id}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STEP 3 — Seed users
// ─────────────────────────────────────────────────────────────────────────────

async function seedUsers() {
  console.log('\n── Step 3: Seeding users ─────────────────────────────────────');
  const now = Timestamp.now();

  for (const u of SEED_USERS) {
    // Create Firebase Auth account
    let authUser;
    try {
      authUser = await auth.createUser({
        email:       u.email,
        password:    u.password,
        displayName: u.displayName,
      });
    } catch (err) {
      if (err.code === 'auth/email-already-exists') {
        authUser = await auth.getUserByEmail(u.email);
        await auth.updateUser(authUser.uid, {
          password:    u.password,
          displayName: u.displayName,
        });
      } else {
        throw err;
      }
    }

    // Write Firestore user doc
    await db.collection('users').doc(authUser.uid).set({
      uid:                    authUser.uid,
      email:                  u.email,
      displayName:            u.displayName,
      role:                   u.role,
      status:                 'approved',
      isActive:               true,
      employeeId:             u.employeeId,
      phone:                  u.phone,
      age:                    u.age,
      gender:                 u.gender,
      aadharNo:               u.aadharNo,
      panCard:                u.panCard,
      emergencyContactName:   u.emergencyContactName,
      emergencyContactPhone:  u.emergencyContactPhone,
      address:                u.address,
      teamId:                 null,
      photoUrl:               null,
      approvedAt:             now,
      approvedBy:             'system_seed',
      rejectionReason:        null,
      createdAt:              now,
      lastLoginAt:            null,
    });

    const badge = u.employeeId.padEnd(8);
    console.log(`  ✓ ${badge}  ${u.role.padEnd(15)}  ${u.email}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STEP 4 — Seed counter + thresholds
// ─────────────────────────────────────────────────────────────────────────────

async function seedMeta() {
  console.log('\n── Step 4: Seeding counter + thresholds ──────────────────────');

  // Employee sequence counters — set to match the seeded IDs
  await db.collection('counters').doc('employee_sequences').set({
    fa_count: 3,   // FA-001 through FA-003 used
    cl_count: 2,   // CL-001 through CL-002 used
    ad_count: 1,   // AD-001 used
  });
  console.log('  ✓ counters/employee_sequences  { fa: 3, cl: 2, ad: 1 }');

  // Default attendance thresholds
  await db.collection('settings').doc('thresholds').set(DEFAULT_THRESHOLDS);
  console.log('  ✓ settings/thresholds          { minKm: 10, minVisits: 3, dutyHours: 7, late: 09:30 }');
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  console.log('╔══════════════════════════════════════════════════════╗');
  console.log('║   Kiba — Reset + Seed                                ║');
  console.log('╚══════════════════════════════════════════════════════╝');

  await deleteAllAuthUsers();
  await deleteAllFirestore();
  await seedUsers();
  await seedMeta();

  console.log('\n══════════════════════════════════════════════════════');
  console.log('  All done! Test credentials:');
  console.log('══════════════════════════════════════════════════════');

  const roleOrder = ['admin', 'field_advisor', 'clerk'];
  const sorted = [...SEED_USERS].sort(
    (a, b) => roleOrder.indexOf(a.role) - roleOrder.indexOf(b.role)
  );

  sorted.forEach(u => {
    const id   = u.employeeId.padEnd(8);
    const role = u.role.padEnd(15);
    console.log(`  ${id}  ${role}  ${u.email}  /  ${u.password}`);
  });

  console.log('══════════════════════════════════════════════════════\n');
  process.exit(0);
}

main().catch(err => {
  console.error('\n✗ Fatal error:', err.message || err);
  process.exit(1);
});
