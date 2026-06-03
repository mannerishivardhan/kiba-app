#!/usr/bin/env node
/**
 * Kiba — Create first admin account
 * Prompts for all profile fields, creates Firebase Auth user + Firestore doc.
 *
 * Usage:
 *   cd scripts && node create_admin.js
 */

const admin = require('firebase-admin');
const readline = require('readline');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'kiba-3f0fa',
});

const auth = admin.auth();
const db   = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

// ── Masking helpers (must match auth_repository.dart) ────────────────────────
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

// ── Interactive prompt ────────────────────────────────────────────────────────
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

function ask(question, required = true) {
  return new Promise(resolve => {
    const prompt = () => rl.question(question, answer => {
      const trimmed = answer.trim();
      if (required && !trimmed) {
        console.log('  (this field is required)');
        prompt();
      } else {
        resolve(trimmed);
      }
    });
    prompt();
  });
}

function askPassword(question) {
  return new Promise(resolve => {
    process.stdout.write(question);
    // readline doesn't hide input; we just prompt normally for CLI use
    rl.question('', answer => resolve(answer.trim()));
  });
}

// ── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n╔══════════════════════════════════════════╗');
  console.log('║   Kiba Admin Account Setup               ║');
  console.log('╚══════════════════════════════════════════╝\n');
  console.log('Fill in the admin profile. All fields marked * are required.\n');

  // ── Account credentials ───────────────────────────────────────────────────
  console.log('── Account ──────────────────────────────────');
  const displayName = await ask('* Full Name          : ');
  const email       = await ask('* Email              : ');
  const password    = await ask('* Password (min 6)   : ');

  // ── Personal info ─────────────────────────────────────────────────────────
  console.log('\n── Personal Info ────────────────────────────');
  const ageRaw  = await ask('* Age                : ');
  const age     = parseInt(ageRaw, 10);
  if (isNaN(age) || age < 18 || age > 99) {
    console.error('Age must be a number between 18 and 99. Aborting.');
    process.exit(1);
  }
  const gender  = await ask('* Gender (male/female/other) : ');
  const phone   = await ask('* Phone (+91XXXXXXXXXX)       : ');

  // ── Identity documents ────────────────────────────────────────────────────
  console.log('\n── Identity Documents ───────────────────────');
  const aadharRaw = await ask('* Aadhar (12 digits) : ');
  const panRaw    = await ask('* PAN (ABCDE1234F)   : ');

  let maskedAadhar, maskedPan;
  try {
    maskedAadhar = maskAadhar(aadharRaw);
    maskedPan    = maskPan(panRaw);
  } catch (err) {
    console.error(`\nValidation error: ${err.message}`);
    process.exit(1);
  }

  // ── Emergency contact ─────────────────────────────────────────────────────
  console.log('\n── Emergency Contact ────────────────────────');
  const emergencyContactName  = await ask('* Contact Name  : ');
  const emergencyContactPhone = await ask('* Contact Phone : ');

  // ── Address ───────────────────────────────────────────────────────────────
  console.log('\n── Address ──────────────────────────────────');
  const address = await ask('* Address (full) : ');

  rl.close();

  // ── Summary ───────────────────────────────────────────────────────────────
  console.log('\n─────────────────────────────────────────────');
  console.log('Creating admin account with:');
  console.log(`  Name     : ${displayName}`);
  console.log(`  Email    : ${email}`);
  console.log(`  Role     : admin`);
  console.log(`  Age      : ${age}`);
  console.log(`  Gender   : ${gender}`);
  console.log(`  Phone    : ${phone}`);
  console.log(`  Aadhar   : ${maskedAadhar}  (masked for storage)`);
  console.log(`  PAN      : ${maskedPan}  (masked for storage)`);
  console.log(`  Emergency: ${emergencyContactName} · ${emergencyContactPhone}`);
  console.log(`  Address  : ${address}`);
  console.log('─────────────────────────────────────────────\n');

  // ── Create Firebase Auth user ─────────────────────────────────────────────
  let authUser;
  try {
    authUser = await auth.getUserByEmail(email);
    console.log(`⚡  Auth user already exists (${authUser.uid}), updating profile…`);
    await auth.updateUser(authUser.uid, { displayName, password });
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      authUser = await auth.createUser({ email, password, displayName });
      console.log(`✅  Firebase Auth user created (${authUser.uid})`);
    } else {
      throw err;
    }
  }

  // ── Write Firestore doc ────────────────────────────────────────────────────
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection('users').doc(authUser.uid).set({
    uid:                    authUser.uid,
    email:                  email,
    displayName:            displayName,
    role:                   'admin',
    status:                 'approved',
    isActive:               true,
    phone:                  phone,
    age:                    age,
    gender:                 gender.toLowerCase(),
    aadharNo:               maskedAadhar,
    panCard:                maskedPan,
    emergencyContactName:   emergencyContactName,
    emergencyContactPhone:  emergencyContactPhone,
    address:                address,
    photoUrl:               null,
    approvedAt:             now,
    approvedBy:             'system',
    rejectionReason:        null,
    createdAt:              now,
  });

  console.log('✅  Firestore user doc written');
  console.log('\n╔══════════════════════════════════════════╗');
  console.log('║  Admin account ready!                    ║');
  console.log(`║  Email    : ${email.padEnd(28)}║`);
  console.log(`║  Password : ${'(the one you entered)'.padEnd(28)}║`);
  console.log('╚══════════════════════════════════════════╝\n');

  process.exit(0);
}

main().catch(err => {
  console.error('\n❌ Error:', err.message || err);
  process.exit(1);
});
