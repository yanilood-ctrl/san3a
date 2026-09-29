'use strict';

// Shared Firestore Emulator test-environment helper for the rules_tests
// suite. Isolated local dev tooling only — never imported by the Flutter
// app or Cloud Functions runtime.

const fs = require('fs');
const net = require('net');
const path = require('path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const ROOT_DIR = path.resolve(__dirname, '..', '..');
const FIRESTORE_HOST = '127.0.0.1';
const FIRESTORE_PORT = 8080;

function readProjectId() {
  const rcPath = path.join(ROOT_DIR, '.firebaserc');
  const rc = JSON.parse(fs.readFileSync(rcPath, 'utf8'));
  const projectId = rc && rc.projects && rc.projects.default;
  if (!projectId) {
    throw new Error(`Could not resolve a project id from ${rcPath}`);
  }
  return projectId;
}

// Fails fast with a clear message instead of letting the SDK hang/retry
// silently when the emulator isn't running.
function checkEmulatorReachable(host, port, timeoutMs = 3000) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host, port });
    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error(
        `Timed out connecting to the Firestore Emulator at ${host}:${port}. ` +
        'Run these tests through the emulator, e.g.: ' +
        'firebase emulators:exec --only firestore "npm --prefix rules_tests test"'
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
        `Firestore Emulator is not reachable at ${host}:${port} (${err.code || err.message}). ` +
        'Run these tests through the emulator, e.g.: ' +
        'firebase emulators:exec --only firestore "npm --prefix rules_tests test"'
      ));
    });
  });
}

let testEnvPromise = null;

// Cached across all spec files in the process so every test file shares one
// emulator connection / rules load instead of re-initializing per file.
async function getTestEnv() {
  if (!testEnvPromise) {
    testEnvPromise = (async () => {
      await checkEmulatorReachable(FIRESTORE_HOST, FIRESTORE_PORT);
      const rulesPath = path.join(ROOT_DIR, 'firestore.rules');
      return initializeTestEnvironment({
        projectId: readProjectId(),
        firestore: {
          rules: fs.readFileSync(rulesPath, 'utf8'),
          host: FIRESTORE_HOST,
          port: FIRESTORE_PORT,
        },
      });
    })();
  }
  return testEnvPromise;
}

module.exports = {
  getTestEnv,
  FIRESTORE_HOST,
  FIRESTORE_PORT,
  readProjectId,
};
