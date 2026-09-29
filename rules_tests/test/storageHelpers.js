'use strict';

// Shared Firestore + Storage Emulator test-environment helper for the
// storage*.test.js specs. Separate from helpers.js on purpose: the plain
// Firestore-only suite (helpers.js/globalSetup.js) must keep working without
// ever requiring the Storage emulator to be running. Isolated local dev
// tooling only — never imported by the Flutter app or Cloud Functions
// runtime.

const fs = require('fs');
const net = require('net');
const path = require('path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const ROOT_DIR = path.resolve(__dirname, '..', '..');
const FIRESTORE_HOST = '127.0.0.1';
const FIRESTORE_PORT = 8080;
const STORAGE_HOST = '127.0.0.1';
const STORAGE_PORT = 9199;

// Real bucket name from lib/firebase_options.dart — the Storage emulator
// still requires a bucket identifier even though it never touches the real
// bucket.
const STORAGE_BUCKET = 'san3a-app-4d4fc.firebasestorage.app';

function readProjectId() {
  const rcPath = path.join(ROOT_DIR, '.firebaserc');
  const rc = JSON.parse(fs.readFileSync(rcPath, 'utf8'));
  const projectId = rc && rc.projects && rc.projects.default;
  if (!projectId) {
    throw new Error(`Could not resolve a project id from ${rcPath}`);
  }
  return projectId;
}

function checkEmulatorReachable(label, host, port, timeoutMs = 3000) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host, port });
    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error(
        `Timed out connecting to the ${label} Emulator at ${host}:${port}. ` +
        'Run these tests through the emulator, e.g.: ' +
        'firebase emulators:exec --only firestore,storage "npm --prefix rules_tests run test:storage"'
      ));
    }, timeoutMs);
    socket.once('connect', () => {
      clearTimeout(timer);
      socket.end();
      resolve();
    });
    socket.once('error', (err) => {
      clearTimeout(timer);
      reject(new Error(
        `${label} Emulator is not reachable at ${host}:${port} (${err.code || err.message}). ` +
        'Run these tests through the emulator, e.g.: ' +
        'firebase emulators:exec --only firestore,storage "npm --prefix rules_tests run test:storage"'
      ));
    });
  });
}

let testEnvPromise = null;

// Cached across all storage*.test.js spec files so every file shares one
// emulator connection / rules load instead of re-initializing per file.
async function getStorageTestEnv() {
  if (!testEnvPromise) {
    testEnvPromise = (async () => {
      await checkEmulatorReachable('Firestore', FIRESTORE_HOST, FIRESTORE_PORT);
      await checkEmulatorReachable('Storage', STORAGE_HOST, STORAGE_PORT);
      const firestoreRulesPath = path.join(ROOT_DIR, 'firestore.rules');
      const storageRulesPath = path.join(ROOT_DIR, 'storage.rules');
      return initializeTestEnvironment({
        projectId: readProjectId(),
        firestore: {
          rules: fs.readFileSync(firestoreRulesPath, 'utf8'),
          host: FIRESTORE_HOST,
          port: FIRESTORE_PORT,
        },
        storage: {
          rules: fs.readFileSync(storageRulesPath, 'utf8'),
          host: STORAGE_HOST,
          port: STORAGE_PORT,
        },
      });
    })();
  }
  return testEnvPromise;
}

module.exports = {
  getStorageTestEnv,
  STORAGE_BUCKET,
  FIRESTORE_HOST,
  FIRESTORE_PORT,
  STORAGE_HOST,
  STORAGE_PORT,
  readProjectId,
};
