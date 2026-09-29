'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { getStorageTestEnv, STORAGE_BUCKET } = require('./storageHelpers');

const TINY_JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x01, 0x02, 0x03]);
const OVERSIZED_BYTES = Buffer.alloc(6 * 1024 * 1024, 1); // > 5 MiB

describe('profile_images/{userId}/{fileName} security rules', function () {
  this.timeout(20000);
  let testEnv;

  before(async () => {
    testEnv = await getStorageTestEnv();
  });

  beforeEach(async () => {
    await testEnv.clearStorage();
  });

  const OWNER = 'profile_owner_uid';
  const OTHER = 'profile_other_uid';

  it('A. owner valid create succeeds', async () => {
    const storage = testEnv.authenticatedContext(OWNER).storage(STORAGE_BUCKET);
    await assertSucceeds(
      storage.ref(`profile_images/${OWNER}/avatar_1.jpg`).put(TINY_JPEG, { contentType: 'image/jpeg' })
    );
  });

  it('B. non-owner create fails', async () => {
    const storage = testEnv.authenticatedContext(OTHER).storage(STORAGE_BUCKET);
    await assertFails(
      storage.ref(`profile_images/${OWNER}/avatar_hack.jpg`).put(TINY_JPEG, { contentType: 'image/jpeg' })
    );
  });

  it('C. any authenticated user read succeeds', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`profile_images/${OWNER}/avatar_1.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(OTHER).storage(STORAGE_BUCKET);
    await assertSucceeds(storage.ref(`profile_images/${OWNER}/avatar_1.jpg`).getDownloadURL());
  });

  it('D. unauthenticated read fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`profile_images/${OWNER}/avatar_1.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.unauthenticatedContext().storage(STORAGE_BUCKET);
    await assertFails(storage.ref(`profile_images/${OWNER}/avatar_1.jpg`).getDownloadURL());
  });

  it('E. overwrite of an existing object fails (create-only)', async () => {
    const storage = testEnv.authenticatedContext(OWNER).storage(STORAGE_BUCKET);
    const ref = storage.ref(`profile_images/${OWNER}/avatar_2.jpg`);
    await assertSucceeds(ref.put(TINY_JPEG, { contentType: 'image/jpeg' }));
    await assertFails(ref.put(TINY_JPEG, { contentType: 'image/jpeg' }));
  });

  it('F. owner delete succeeds', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`profile_images/${OWNER}/avatar_3.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(OWNER).storage(STORAGE_BUCKET);
    await assertSucceeds(storage.ref(`profile_images/${OWNER}/avatar_3.jpg`).delete());
  });

  it('G. non-owner delete fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`profile_images/${OWNER}/avatar_4.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(OTHER).storage(STORAGE_BUCKET);
    await assertFails(storage.ref(`profile_images/${OWNER}/avatar_4.jpg`).delete());
  });

  it('H. invalid MIME type fails', async () => {
    const storage = testEnv.authenticatedContext(OWNER).storage(STORAGE_BUCKET);
    await assertFails(
      storage.ref(`profile_images/${OWNER}/avatar_bad.gif`).put(TINY_JPEG, { contentType: 'image/gif' })
    );
  });

  it('I. oversized file fails', async () => {
    const storage = testEnv.authenticatedContext(OWNER).storage(STORAGE_BUCKET);
    await assertFails(
      storage.ref(`profile_images/${OWNER}/avatar_big.jpg`).put(OVERSIZED_BYTES, { contentType: 'image/jpeg' })
    );
  });
});
