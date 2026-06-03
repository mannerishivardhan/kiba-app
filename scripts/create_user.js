#!/usr/bin/env node
/**
 * Kiba — Create a seeded user account for any role
 *
 * Usage:
 *   node create_user.js admin
 *   node create_user.js field_advisor
 *   node create_user.js clerk
 *
 * Admin accounts are created pre-approved (status=approved, isActive=true).
 * Field advisor / clerk accounts are also created pre-approved so you can
 * test role flows directly without going through the approval UI.
 */

const admin = require('firebase-admin');
const readline = require('readline');
const serviceAccount = require('./serviceAccountKey.json');

const VALID_ROLES = ['admin', 'field_advisor', 'clerk'];
const role = process.argv[2];

if (!role || !VALID_ROLES.includes(role)) {
  console.error(`\nUsage: node create_user.js <role>\nRoles: ${VALID_ROLES.join(' | ')}\n`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'kiba-3f0fa',
});

const auth = admin.auth();
const db   = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

// ── Masking helpers ───────────────────────────────────────────────────────────
function maskAadhar(raw) {
  const digits = raw.replace(/\D/g, '');
  if (digits.length !== 12) throw new Error('Aadhar must be exactly 12 digits');
  return `XXXX-XXXX-${digits.slice(8)}`;
}

function maskPan(raw) {
  const pan = raw.toUpperCase().trim();
  if (!/^[A-Z]{5}[0-9]{4}[A-Z]$/.test(pan)) throw new Error('PAN format must be ABCDE1234F');
  return `${pan.slice(0, 3)}XX${pan.slice(5)}`;
}

// ── Prompt helper ─────────────────────────────────────────────────────────────
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

function ask(question, required = true) {
  return new Promise(resolve => {
    const prompt = () => rl.question(question, answer => {
      const trimmed = answer.trim();
      if (required && !trimmed) { console.log('  (required)'); prompt(); }
      else resolve(trimmed);
    });
    prompt();
  });
}

// ── Role display label ────────────────────────────────────────────────────────
const roleLabel = { admin: 'Admin', field_advisor: 'Field Advisor', clerk: 'Clerk' }[role];

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n╔══════════════════════════════════════════╗`);
  console.log(`║   Kiba — Create ${roleLabel.padEnd(26)}║`);
  console.log(`╚══════════════════════════════════════════╝\n`);

  // Account
  console.log('── Account ──────────────────────────────────');
  const displayName = await ask('* Full Name          : ');
  const email       = await ask('* Email              : ');
  const password    = await ask('* Password (min 6)   : ');

  // Personal info
  console.log('\n── Personal Info ────────────────────────────');
  const ageRaw = await ask('* Age                : ');
  const age    = parseInt(ageRaw, 10);
  if (isNaN(age) || age < 18 || age > 99) {
    console.error('Age must be 18–99. Aborting.'); process.exit(1);
  }
  const gender = await ask('* Gender (male/female/other) : ');
  const phone  = await ask('* Phone (+91XXXXXXXXXX)       : ');

  // Identity docs
  console.log('\n── Identity Documents ───────────────────────');
  const aadharRaw = await ask('* Aadhar (12 digits) : ');
  const panRaw    = await ask('* PAN (ABCDE1234F)   : ');

  let maskedAadhar, maskedPan;
  try {
    maskedAadhar = maskAadhar(aadharRaw);
    maskedPan    = maskPan(panRaw);
  } catch (err) {
    console.error(`\nValidation error: ${err.message}`); process.exit(1);
  }

  // Emergency contact
  console.log('\n── Emergency Contact ────────────────────────');
  const emergencyContactName  = await ask('* Contact Name  : ');
  const emergencyContactPhone = await ask('* Contact Phone : ');

  // Address
  console.log('\n── Address ──────────────────────────────────');
  const address = await ask('* Address (full) : ');

  rl.close();

  // Summary
  console.log('\n─────────────────────────────────────────────');
  console.log(`  Name     : ${displayName}`);
  console.log(`  Email    : ${email}`);
  console.log(`  Role     : ${role}`);
  console.log(`  Status   : approved (pre-seeded)`);
  console.log(`  Age      : ${age}`);
  console.log(`  Gender   : ${gender}`);
  console.log(`  Phone    : ${phone}`);
  console.log(`  Aadhar   : ${maskedAadhar}`);
  console.log(`  PAN      : ${maskedPan}`);
  console.log(`  Emergency: ${emergencyContactName} · ${emergencyContactPhone}`);
  console.log(`  Address  : ${address}`);
  console.log('─────────────────────────────────────────────\n');

  // Firebase Auth
  let authUser;
  try {
    authUser = await auth.getUserByEmail(email);
    console.log(`⚡  Auth user already exists (${authUser.uid}), updating…`);
    await auth.updateUser(authUser.uid, { displayName, password });
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      authUser = await auth.createUser({ email, password, displayName });
      console.log(`✅  Firebase Auth user created (${authUser.uid})`);
    } else {
      throw err;
    }
  }

  // Firestore doc
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection('users').doc(authUser.uid).set({
    uid:                   authUser.uid,
    email,
    displayName,
    role,
    status:                'approved',
    isActive:              true,
    phone,
    age,
    gender:                gender.toLowerCase(),
    aadharNo:              maskedAadhar,
    panCard:               maskedPan,
    emergencyContactName,
    emergencyContactPhone,
    address,
    photoUrl:              null,
    approvedAt:            now,
    approvedBy:            'system',
    rejectionReason:       null,
    createdAt:             now,
  });

  console.log('✅  Firestore user doc written');
  console.log(`\n╔══════════════════════════════════════════╗`);
  console.log(`║  ${roleLabel} account ready!${' '.repeat(Math.max(0, 26 - roleLabel.length))}║`);
  console.log(`║  Email : ${email.padEnd(32)}║`);
  console.log(`╚══════════════════════════════════════════╝\n`);

  process.exit(0);
}

main().catch(err => {
  console.error('\n❌ Error:', err.message || err);
  process.exit(1);
});
