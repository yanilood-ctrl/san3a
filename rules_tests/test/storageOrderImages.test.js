'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { getStorageTestEnv, STORAGE_BUCKET } = require('./storageHelpers');
const { customerData, professionalData, adminData, orderData } = require('./fixtures');

const TINY_JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x01, 0x02, 0x03]);
const OVERSIZED_IMAGE = Buffer.alloc(6 * 1024 * 1024, 1); // > 5 MiB

describe('orders/{customerUid}/{orderId}/images security rules (new + legacy paths)', function () {
  this.timeout(20000);
  let testEnv;

  const CUSTOMER = 'order_customer_uid';
  const PROVIDER = 'order_provider_uid';
  const ADMIN = 'order_admin_uid';
  const OTHER_USER = 'order_other_uid';

  before(async () => {
    testEnv = await getStorageTestEnv();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection('users').doc(CUSTOMER).set(customerData(CUSTOMER));
      await db.collection('users').doc(PROVIDER).set(professionalData(PROVIDER));
      await db.collection('users').doc(ADMIN).set(adminData(ADMIN));
      await db.collection('users').doc(OTHER_USER).set(customerData(OTHER_USER));
    });
  });

  beforeEach(async () => {
    await testEnv.clearStorage();
    await testEnv.clearFirestore();
    // clearFirestore wipes users too -- reseed them for every test.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection('users').doc(CUSTOMER).set(customerData(CUSTOMER));
      await db.collection('users').doc(PROVIDER).set(professionalData(PROVIDER));
      await db.collection('users').doc(ADMIN).set(adminData(ADMIN));
      await db.collection('users').doc(OTHER_USER).set(customerData(OTHER_USER));
    });
  });

  async function seedOrderDoc(orderId) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('orders').doc(orderId)
        .set(orderData(CUSTOMER, PROVIDER, 'professional', orderId));
    });
  }

  it('A. customer creates before the Order document exists', async () => {
    const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
    await assertSucceeds(
      storage.ref(`orders/${CUSTOMER}/order_new_1/images/main.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' })
    );
  });

  it('B. immediate owner read succeeds before the Order document exists', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`orders/${CUSTOMER}/order_new_2/images/main.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
    await assertSucceeds(
      storage.ref(`orders/${CUSTOMER}/order_new_2/images/main.jpg`).getDownloadURL()
    );
  });

  it('C. another user cannot create in that customer folder', async () => {
    const storage = testEnv.authenticatedContext(OTHER_USER).storage(STORAGE_BUCKET);
    await assertFails(
      storage.ref(`orders/${CUSTOMER}/order_new_3/images/hack.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' })
    );
  });

  it('D. provider reads after the Order document exists', async () => {
    await seedOrderDoc('order_new_4');
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`orders/${CUSTOMER}/order_new_4/images/main.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(PROVIDER).storage(STORAGE_BUCKET);
    await assertSucceeds(
      storage.ref(`orders/${CUSTOMER}/order_new_4/images/main.jpg`).getDownloadURL()
    );
  });

  it('E. unrelated user denied read after the Order document exists', async () => {
    await seedOrderDoc('order_new_5');
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`orders/${CUSTOMER}/order_new_5/images/main.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(OTHER_USER).storage(STORAGE_BUCKET);
    await assertFails(
      storage.ref(`orders/${CUSTOMER}/order_new_5/images/main.jpg`).getDownloadURL()
    );
  });

  it('F. Admin reads regardless of Order existence', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`orders/${CUSTOMER}/order_new_6/images/main.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(ADMIN).storage(STORAGE_BUCKET);
    await assertSucceeds(
      storage.ref(`orders/${CUSTOMER}/order_new_6/images/main.jpg`).getDownloadURL()
    );
  });

  it('G. overwrite denied', async () => {
    const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
    const ref = storage.ref(`orders/${CUSTOMER}/order_new_7/images/main.jpg`);
    await assertSucceeds(ref.put(TINY_JPEG, { contentType: 'image/jpeg' }));
    await assertFails(ref.put(TINY_JPEG, { contentType: 'image/jpeg' }));
  });

  it('H. customer delete succeeds before the Order document exists (orphan cleanup)', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`orders/${CUSTOMER}/order_new_8/images/main.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
    await assertSucceeds(
      storage.ref(`orders/${CUSTOMER}/order_new_8/images/main.jpg`).delete()
    );
  });

  it('I. customer delete succeeds after the Order document exists', async () => {
    await seedOrderDoc('order_new_9');
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`orders/${CUSTOMER}/order_new_9/images/main.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
    await assertSucceeds(
      storage.ref(`orders/${CUSTOMER}/order_new_9/images/main.jpg`).delete()
    );
  });

  it('J. provider delete denied', async () => {
    await seedOrderDoc('order_new_10');
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`orders/${CUSTOMER}/order_new_10/images/main.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(PROVIDER).storage(STORAGE_BUCKET);
    await assertFails(
      storage.ref(`orders/${CUSTOMER}/order_new_10/images/main.jpg`).delete()
    );
  });

  it('K. Admin delete succeeds', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage(STORAGE_BUCKET).ref(`orders/${CUSTOMER}/order_new_11/images/main.jpg`)
        .put(TINY_JPEG, { contentType: 'image/jpeg' });
    });
    const storage = testEnv.authenticatedContext(ADMIN).storage(STORAGE_BUCKET);
    await assertSucceeds(
      storage.ref(`orders/${CUSTOMER}/order_new_11/images/main.jpg`).delete()
    );
  });

  it('L. invalid MIME fails', async () => {
    const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
    await assertFails(
      storage.ref(`orders/${CUSTOMER}/order_new_12/images/main.png`)
        .put(TINY_JPEG, { contentType: 'image/png' })
    );
  });

  it('M. oversized image fails', async () => {
    const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
    await assertFails(
      storage.ref(`orders/${CUSTOMER}/order_new_13/images/main.jpg`)
        .put(OVERSIZED_IMAGE, { contentType: 'image/jpeg' })
    );
  });
});
