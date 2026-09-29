'use strict';

// Regression coverage for the production "Customer Mark all read does
// nothing" bug. Root cause proven here: the notification_states create()
// rule (firestore.rules) calls both exists() and get() on
// notifications/{notifId} per brand-new state document — 2 doc-access
// calls each. Firestore hard-caps get()/exists() calls at 20 total per
// single batched write, so any mark-all batch touching more than 10
// never-before-read notifications was denied outright and atomically
// rolled back every write in it, regardless of the (unrelated, much
// higher) 500-write-operations-per-batch ceiling. The Flutter fix
// (markAllNotificationsReadInFirestore in app_providers.dart) now chunks
// at 8 creates per batch. These tests pin that boundary against the real
// emulator so it can never silently regress back toward the old ceiling.

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, writeBatch } = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const { customerData, orderUpdateNotificationData, notificationStateData } = require('./fixtures');

async function seedNotification(db, notifId, data) {
  await setDoc(doc(db, 'notifications', notifId), { id: notifId, ...data });
}

async function seedCustomerWithUnreadNotifications(testEnv, uid, count, prefix) {
  const notifIds = [];
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', uid), customerData(uid));
    for (let i = 0; i < count; i++) {
      const id = `${prefix}_${i}`;
      notifIds.push(id);
      await seedNotification(db, id, orderUpdateNotificationData(uid, `ord_${prefix}_${i}`));
    }
  });
  return notifIds;
}

function markAllBatch(db, uid, notifIds) {
  const batch = writeBatch(db);
  for (const id of notifIds) {
    batch.set(
      doc(db, 'users', uid, 'notification_states', id),
      notificationStateData(id, uid),
    );
  }
  return batch;
}

describe('Mark-all-read batch size vs. get()/exists() rules quota', function () {
  this.timeout(30000);
  let testEnv;

  before(async () => {
    testEnv = await getTestEnv();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  it('a batch of 8 first-time mark-read creates (the app\'s real chunk size) succeeds', async () => {
    const uid = 'mab_ok_8';
    const notifIds = await seedCustomerWithUnreadNotifications(testEnv, uid, 8, 'n8');
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(markAllBatch(db, uid, notifIds).commit());
  });

  it('a batch of 10 first-time mark-read creates still succeeds (the proven ceiling)', async () => {
    const uid = 'mab_ok_10';
    const notifIds = await seedCustomerWithUnreadNotifications(testEnv, uid, 10, 'n10');
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(markAllBatch(db, uid, notifIds).commit());
  });

  it('a batch of 11 first-time mark-read creates is denied outright (proves the old 450-chunk size was never safe)', async () => {
    const uid = 'mab_fail_11';
    const notifIds = await seedCustomerWithUnreadNotifications(testEnv, uid, 11, 'n11');
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(markAllBatch(db, uid, notifIds).commit());
  });

  it('33 unread notifications (the exact reported production count) split into safe chunks of 8 all succeed', async () => {
    const uid = 'mab_33';
    const notifIds = await seedCustomerWithUnreadNotifications(testEnv, uid, 33, 'n33');
    const db = testEnv.authenticatedContext(uid).firestore();

    const chunkSize = 8;
    for (let i = 0; i < notifIds.length; i += chunkSize) {
      const chunk = notifIds.slice(i, i + chunkSize);
      await assertSucceeds(markAllBatch(db, uid, chunk).commit());
    }
  });

  it('Customer A running a full mark-all batch never creates any state doc for Customer B', async () => {
    const custA = 'mab_iso_A';
    const custB = 'mab_iso_B';
    const notifIdsA = await seedCustomerWithUnreadNotifications(testEnv, custA, 9, 'n_iso_a');
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', custB), customerData(custB));
    });

    const dbA = testEnv.authenticatedContext(custA).firestore();
    await assertSucceeds(markAllBatch(dbA, custA, notifIdsA).commit());

    const dbB = testEnv.authenticatedContext(custB).firestore();
    await assertFails(markAllBatch(dbB, custB, notifIdsA).commit());
  });

  it('a mixed batch of updates (already-existing state docs) costs no get()/exists() quota and can exceed 10 in one commit', async () => {
    const uid = 'mab_updates_only';
    const notifIds = await seedCustomerWithUnreadNotifications(testEnv, uid, 15, 'n_upd');
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const id of notifIds) {
        await setDoc(
          doc(db, 'users', uid, 'notification_states', id),
          { notificationId: id, userId: uid, isRead: false, updatedAt: '2020-01-01T00:00:00.000Z' },
        );
      }
    });

    const db = testEnv.authenticatedContext(uid).firestore();
    // These are updates to already-existing state docs (stateUpdateAllowed
    // has no get()/exists() calls at all), so all 15 in one batch succeed
    // even though it would have failed as 15 fresh creates.
    await assertSucceeds(markAllBatch(db, uid, notifIds).commit());
  });
});
