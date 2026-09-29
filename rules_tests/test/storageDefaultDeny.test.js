'use strict';

const { assertFails } = require('@firebase/rules-unit-testing');
const { getStorageTestEnv, STORAGE_BUCKET } = require('./storageHelpers');

const TINY_JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x01, 0x02, 0x03]);

describe('unknown Storage paths default-deny', function () {
  this.timeout(20000);
  let testEnv;

  const SOME_UID = 'default_deny_uid';

  before(async () => {
    testEnv = await getStorageTestEnv();
  });

  beforeEach(async () => {
    await testEnv.clearStorage();
  });

  it('A. write to an unmapped top-level folder denied', async () => {
    const storage = testEnv.authenticatedContext(SOME_UID).storage(STORAGE_BUCKET);
    await assertFails(
      storage.ref('some_random_unmapped_folder/x.jpg').put(TINY_JPEG, { contentType: 'image/jpeg' })
    );
  });

  it('B. read from an unmapped top-level folder denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref('some_random_unmapped_folder/x.jpg')
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(SOME_UID).storage(STORAGE_BUCKET);
    await assertFails(storage.ref('some_random_unmapped_folder/x.jpg').getDownloadURL());
  });

  it('C. delete from an unmapped top-level folder denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref('some_random_unmapped_folder/x.jpg')
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(SOME_UID).storage(STORAGE_BUCKET);
    await assertFails(storage.ref('some_random_unmapped_folder/x.jpg').delete());
  });

  it('D. write to bucket root (no folder) denied', async () => {
    const storage = testEnv.authenticatedContext(SOME_UID).storage(STORAGE_BUCKET);
    await assertFails(storage.ref('root_level_file.jpg').put(TINY_JPEG, { contentType: 'image/jpeg' }));
  });

  it('E. unauthenticated write to an unmapped folder denied', async () => {
    const storage = testEnv.unauthenticatedContext().storage(STORAGE_BUCKET);
    await assertFails(
      storage.ref('some_random_unmapped_folder/y.jpg').put(TINY_JPEG, { contentType: 'image/jpeg' })
    );
  });
});
