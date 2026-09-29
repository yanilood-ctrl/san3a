'use strict';

// Mocha root hooks (loaded via --require). Initializes the shared test
// environment once before any spec file runs, and cleans it up once after
// the whole suite finishes.

const { getTestEnv } = require('./helpers');

exports.mochaHooks = {
  async beforeAll() {
    this.timeout(30000);
    await getTestEnv();
  },
  async afterAll() {
    this.timeout(30000);
    const testEnv = await getTestEnv();
    await testEnv.cleanup();
  },
};
