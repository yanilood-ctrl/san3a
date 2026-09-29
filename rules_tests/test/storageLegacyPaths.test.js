'use strict';

// Covers every Storage path shape that has no uid-scoped segment at all --
// objects written before Phase 6B2 under chat_images/chat_voice/{conversationId}
// and orders/{orderId}/images. Kept in one file since the shared trait these
// paths have is "ownership can only ever be proven via a Firestore lookup,
// never via the path itself".

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { getStorageTestEnv, STORAGE_BUCKET } = require('./storageHelpers');
const { customerData, professionalData, adminData, orderData } = require('./fixtures');

const TINY_JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x01, 0x02, 0x03]);

describe('legacy Storage paths (no uid segment) security rules', function () {
  this.timeout(20000);
  let testEnv;

  const CUSTOMER = 'legacy_customer_uid';
  const PROVIDER = 'legacy_provider_uid';
  const ADMIN = 'legacy_admin_uid';
  const OTHER_USER = 'legacy_other_uid';

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

  describe('legacy chat_images/{conversationId}/{fileName}', () => {
    const CONV_ID = [CUSTOMER, PROVIDER].sort().join('_');
    const NO_DOC_CONV_ID = 'legacy_convo_with_no_doc';

    before(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection('conversations').doc(CONV_ID).set({
          id: CONV_ID,
          participantIds: [CUSTOMER, PROVIDER],
        });
      });
    });

    beforeEach(async () => {
      await testEnv.clearStorage();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.storage(STORAGE_BUCKET).ref(`chat_images/${CONV_ID}/legacy1.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' });
      });
    });

    it('A. participant read succeeds', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertSucceeds(storage.ref(`chat_images/${CONV_ID}/legacy1.jpg`).getDownloadURL());
    });

    it('B. unrelated user denied', async () => {
      const storage = testEnv.authenticatedContext(OTHER_USER).storage(STORAGE_BUCKET);
      await assertFails(storage.ref(`chat_images/${CONV_ID}/legacy1.jpg`).getDownloadURL());
    });

    it('C. Admin succeeds', async () => {
      const storage = testEnv.authenticatedContext(ADMIN).storage(STORAGE_BUCKET);
      await assertSucceeds(storage.ref(`chat_images/${CONV_ID}/legacy1.jpg`).getDownloadURL());
    });

    it('D. nonexistent conversation denied', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.storage(STORAGE_BUCKET).ref(`chat_images/${NO_DOC_CONV_ID}/x.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' });
      });
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(storage.ref(`chat_images/${NO_DOC_CONV_ID}/x.jpg`).getDownloadURL());
    });

    it('E. create denied', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${CONV_ID}/new_legacy.jpg`).put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('F. update (overwrite) denied', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${CONV_ID}/legacy1.jpg`).put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('G. delete denied', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(storage.ref(`chat_images/${CONV_ID}/legacy1.jpg`).delete());
    });
  });

  describe('legacy chat_voice/{conversationId}/{fileName}', () => {
    const CONV_ID = [CUSTOMER, PROVIDER].sort().join('_');

    beforeEach(async () => {
      await testEnv.clearStorage();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.storage(STORAGE_BUCKET).ref(`chat_voice/${CONV_ID}/legacy1.m4a`)
          .put(TINY_JPEG, { contentType: 'audio/mp4' });
      });
    });

    it('H. participant read succeeds', async () => {
      const storage = testEnv.authenticatedContext(PROVIDER).storage(STORAGE_BUCKET);
      await assertSucceeds(storage.ref(`chat_voice/${CONV_ID}/legacy1.m4a`).getDownloadURL());
    });

    it('I. unrelated user denied', async () => {
      const storage = testEnv.authenticatedContext(OTHER_USER).storage(STORAGE_BUCKET);
      await assertFails(storage.ref(`chat_voice/${CONV_ID}/legacy1.m4a`).getDownloadURL());
    });

    it('J. delete denied', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(storage.ref(`chat_voice/${CONV_ID}/legacy1.m4a`).delete());
    });
  });

  describe('legacy orders/{orderId}/images/{fileName}', () => {
    beforeEach(async () => {
      await testEnv.clearStorage();
    });

    async function seedOrderDoc(orderId) {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection('orders').doc(orderId)
          .set(orderData(CUSTOMER, PROVIDER, 'professional', orderId));
      });
    }

    async function seedLegacyImage(orderId, fileName = 'legacy1.jpg') {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.storage(STORAGE_BUCKET).ref(`orders/${orderId}/images/${fileName}`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' });
      });
    }

    it('K. customer read succeeds when the Order document exists', async () => {
      await seedOrderDoc('legacy_order_1');
      await seedLegacyImage('legacy_order_1');
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertSucceeds(storage.ref('orders/legacy_order_1/images/legacy1.jpg').getDownloadURL());
    });

    it('L. provider read succeeds', async () => {
      await seedOrderDoc('legacy_order_2');
      await seedLegacyImage('legacy_order_2');
      const storage = testEnv.authenticatedContext(PROVIDER).storage(STORAGE_BUCKET);
      await assertSucceeds(storage.ref('orders/legacy_order_2/images/legacy1.jpg').getDownloadURL());
    });

    it('M. Admin read succeeds', async () => {
      await seedOrderDoc('legacy_order_3');
      await seedLegacyImage('legacy_order_3');
      const storage = testEnv.authenticatedContext(ADMIN).storage(STORAGE_BUCKET);
      await assertSucceeds(storage.ref('orders/legacy_order_3/images/legacy1.jpg').getDownloadURL());
    });

    it('N. unrelated user denied', async () => {
      await seedOrderDoc('legacy_order_4');
      await seedLegacyImage('legacy_order_4');
      const storage = testEnv.authenticatedContext(OTHER_USER).storage(STORAGE_BUCKET);
      await assertFails(storage.ref('orders/legacy_order_4/images/legacy1.jpg').getDownloadURL());
    });

    it('O. nonexistent Order denied (even for Admin)', async () => {
      await seedLegacyImage('legacy_order_missing');
      const custStorage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(custStorage.ref('orders/legacy_order_missing/images/legacy1.jpg').getDownloadURL());
      const adminStorage = testEnv.authenticatedContext(ADMIN).storage(STORAGE_BUCKET);
      await assertFails(adminStorage.ref('orders/legacy_order_missing/images/legacy1.jpg').getDownloadURL());
    });

    it('P. create denied', async () => {
      await seedOrderDoc('legacy_order_5');
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref('orders/legacy_order_5/images/new.jpg').put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('Q. update (overwrite) denied', async () => {
      await seedOrderDoc('legacy_order_6');
      await seedLegacyImage('legacy_order_6');
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref('orders/legacy_order_6/images/legacy1.jpg').put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('R. customer delete succeeds -- fixes the previously-broken cleanup flow', async () => {
      await seedOrderDoc('legacy_order_7');
      await seedLegacyImage('legacy_order_7');
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertSucceeds(storage.ref('orders/legacy_order_7/images/legacy1.jpg').delete());
    });

    it('S. Admin delete succeeds', async () => {
      await seedOrderDoc('legacy_order_8');
      await seedLegacyImage('legacy_order_8');
      const storage = testEnv.authenticatedContext(ADMIN).storage(STORAGE_BUCKET);
      await assertSucceeds(storage.ref('orders/legacy_order_8/images/legacy1.jpg').delete());
    });

    it('T. provider delete denied', async () => {
      await seedOrderDoc('legacy_order_9');
      await seedLegacyImage('legacy_order_9');
      const storage = testEnv.authenticatedContext(PROVIDER).storage(STORAGE_BUCKET);
      await assertFails(storage.ref('orders/legacy_order_9/images/legacy1.jpg').delete());
    });
  });
});
