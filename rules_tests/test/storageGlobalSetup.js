'use strict';

// Mocha root hooks for the storage*.test.js suite (loaded via --require).
// Mirrors globalSetup.js's pattern exactly but against the Firestore+Storage
// pair via storageHelpers.js, so the plain Firestore-only suite never needs
// the Storage emulator running.

const { getStorageTestEnv } = require('./storageHelpers');

exports.mochaHooks = {
  async beforeAll() {
    this.timeout(30000);
    await getStorageTestEnv();
  },
  async afterAll() {
    this.timeout(30000);
    const testEnv = await getStorageTestEnv();
    await testEnv.cleanup();
  },
};
