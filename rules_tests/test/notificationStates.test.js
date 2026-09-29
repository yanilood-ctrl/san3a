'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, writeBatch,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  customerData, adminData,
  orderUpdateNotificationData, complaintRequesterNotificationData,
  notificationStateData,
} = require('./fixtures');

// Seeds a notifications/{id} content document (bypassing rules — content
// creation itself is covered by notifications.test.js) so the state
// subcollection's create rule has a real document to exists()+visibility
// check against.
async function seedNotification(db, notifId, data) {
  await setDoc(doc(db, 'notifications', notifId), { id: notifId, ...data });
}

describe('users/{uid}/notification_states/{notificationId} security rules', function () {
  this.timeout(20000);
  let testEnv;

  before(async () => {
    testEnv = await getTestEnv();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  // ── read ────────────────────────────────────────────────────────────────
  describe('reads', () => {
    const custA = 'ns_read_custA';
    const custB = 'ns_read_custB';
    let notifId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        notifId = 'ns_notif_1';
        await seedNotification(db, notifId, orderUpdateNotificationData(custA, 'ord_1'));
        await setDoc(
          doc(db, 'users', custA, 'notification_states', notifId),
          notificationStateData(notifId, custA),
        );
      });
    });

    it('owner reads own state doc succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(db, 'users', custA, 'notification_states', notifId)));
    });

    it('owner reads own state subcollection (collection query) succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const snap = await assertSucceeds(getDocs(collection(db, 'users', custA, 'notification_states')));
      if (snap.size !== 1) throw new Error(`Expected 1 state doc, got ${snap.size}`);
    });

    it('another user cannot get a specific state doc', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(getDoc(doc(db, 'users', custA, 'notification_states', notifId)));
    });

    it('another user cannot query the subcollection', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(getDocs(collection(db, 'users', custA, 'notification_states')));
    });

    it("Admin cannot read another user's state", async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users', 'ns_read_admin'), adminData('ns_read_admin'));
      });
      const db = testEnv.authenticatedContext('ns_read_admin').firestore();
      await assertFails(getDoc(doc(db, 'users', custA, 'notification_states', notifId)));
      await assertFails(getDocs(collection(db, 'users', custA, 'notification_states')));
    });

    it('unauthenticated read fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'users', custA, 'notification_states', notifId)));
    });
  });

  // ── create ──────────────────────────────────────────────────────────────
  describe('create', () => {
    const custA = 'ns_create_custA';
    const custB = 'ns_create_custB';
    let personalNotifId, roleNotifId, otherRoleNotifId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        personalNotifId = 'ns_c_personal';
        await seedNotification(db, personalNotifId, orderUpdateNotificationData(custA, 'ord_1'));
        roleNotifId = 'ns_c_role';
        await seedNotification(db, roleNotifId, { title: 'Broadcast Message', message: 'hi', type: 'broadcast', targetRole: 'all', isRead: false, createdAt: new Date().toISOString(), isDeleted: false });
        otherRoleNotifId = 'ns_c_other_role';
        await seedNotification(db, otherRoleNotifId, complaintRequesterNotificationData('some_complaint'));
      });
    });

    it('valid mark-read state create succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        notificationStateData(personalNotifId, custA),
      ));
    });

    it('valid delete-first state create succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        { notificationId: personalNotifId, userId: custA, isDeleted: true, updatedAt: new Date().toISOString() },
      ));
    });

    it('valid create for an all-targeted notification succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(setDoc(
        doc(db, 'users', custA, 'notification_states', roleNotifId),
        notificationStateData(roleNotifId, custA),
      ));
    });

    it('false isRead create fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        { notificationId: personalNotifId, userId: custA, isRead: false, updatedAt: new Date().toISOString() },
      ));
    });

    it('false isDeleted create fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        { notificationId: personalNotifId, userId: custA, isDeleted: false, updatedAt: new Date().toISOString() },
      ));
    });

    it('create with neither isRead nor isDeleted (no real action) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        { notificationId: personalNotifId, userId: custA, updatedAt: new Date().toISOString() },
      ));
    });

    it('readAt without isRead:true fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        { notificationId: personalNotifId, userId: custA, isDeleted: true, readAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
      ));
    });

    it('missing updatedAt fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        { notificationId: personalNotifId, userId: custA, isRead: true, readAt: new Date().toISOString() },
      ));
    });

    it('reference to a nonexistent notification fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(
        doc(db, 'users', custA, 'notification_states', 'ghost_notif'),
        notificationStateData('ghost_notif', custA),
      ));
    });

    it('state for a notification not visible to that user fails', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      // personalNotifId targets custA only — custB cannot even read it, so
      // custB must not be able to create state for it either.
      await assertFails(setDoc(
        doc(db, 'users', custB, 'notification_states', personalNotifId),
        notificationStateData(personalNotifId, custB),
      ));
    });

    it('mismatched notificationId field fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        notificationStateData('a_different_id', custA),
      ));
    });

    it('mismatched userId field fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        notificationStateData(personalNotifId, custB),
      ));
    });

    it('unknown field fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        notificationStateData(personalNotifId, custA, { extraField: 'hack' }),
      ));
    });

    it('a user cannot write into another user\'s state path', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        notificationStateData(personalNotifId, custA),
      ));
    });

    it('unauthenticated create fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(setDoc(
        doc(db, 'users', custA, 'notification_states', personalNotifId),
        notificationStateData(personalNotifId, custA),
      ));
    });
  });

  // ── update ──────────────────────────────────────────────────────────────
  describe('update', () => {
    const custA = 'ns_update_custA';
    const custB = 'ns_update_custB';
    let notifId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        notifId = 'ns_u_notif';
        await seedNotification(db, notifId, orderUpdateNotificationData(custA, 'ord_1'));
        // Fixed, deliberately-old updatedAt — guarantees every subsequent
        // `new Date().toISOString()` write in these tests is a genuinely
        // distinct (newer) value, so diff().affectedKeys() reliably includes
        // 'updatedAt' instead of racing a same-millisecond Date() collision.
        await setDoc(
          doc(db, 'users', custA, 'notification_states', notifId),
          { notificationId: notifId, userId: custA, isRead: false, updatedAt: '2020-01-01T00:00:00.000Z' },
        );
      });
    });

    it('mark read update succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'users', custA, 'notification_states', notifId),
        { isRead: true, readAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
      ));
    });

    it('soft delete update succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'users', custA, 'notification_states', notifId),
        { isDeleted: true, updatedAt: new Date().toISOString() },
      ));
    });

    it('isRead true -> false rollback fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'users', custA, 'notification_states', notifId),
        { isRead: true, readAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
      ));
      await assertFails(updateDoc(
        doc(db, 'users', custA, 'notification_states', notifId),
        { isRead: false, updatedAt: new Date().toISOString() },
      ));
    });

    it('isDeleted true -> false rollback fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'users', custA, 'notification_states', notifId),
        { isDeleted: true, updatedAt: new Date().toISOString() },
      ));
      await assertFails(updateDoc(
        doc(db, 'users', custA, 'notification_states', notifId),
        { isDeleted: false, updatedAt: new Date().toISOString() },
      ));
    });

    it('identity change (notificationId) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(
        doc(db, 'users', custA, 'notification_states', notifId),
        { notificationId: 'someone_elses_id', isRead: true, updatedAt: new Date().toISOString() },
      ));
    });

    it('identity change (userId) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(
        doc(db, 'users', custA, 'notification_states', notifId),
        { userId: custB, isRead: true, updatedAt: new Date().toISOString() },
      ));
    });

    it('update without changing updatedAt fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(
        doc(db, 'users', custA, 'notification_states', notifId),
        { isRead: true, readAt: new Date().toISOString() },
      ));
    });

    it('unknown field on update fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(
        doc(db, 'users', custA, 'notification_states', notifId),
        { isRead: true, updatedAt: new Date().toISOString(), extraField: 'hack' },
      ));
    });

    it("another user cannot update this user's state", async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(updateDoc(
        doc(db, 'users', custA, 'notification_states', notifId),
        { isRead: true, updatedAt: new Date().toISOString() },
      ));
    });

    it('physical state delete fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(deleteDoc(doc(db, 'users', custA, 'notification_states', notifId)));
    });
  });

  // ── independent per-user state scenarios (Phase 5C1B bug, now fixed) ────
  describe('independent per-user state', () => {
    const custA = 'ns_indep_custA';
    const custB = 'ns_indep_custB';
    const adminX = 'ns_indep_adminX';
    const adminY = 'ns_indep_adminY';
    let roleNotifId, adminNotifId, personalNotifId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', adminX), adminData(adminX));
        await setDoc(doc(db, 'users', adminY), adminData(adminY));

        roleNotifId = 'ns_i_role';
        await seedNotification(db, roleNotifId, { title: 'Broadcast Message', message: 'hi', type: 'broadcast', targetRole: 'customer', isRead: false, createdAt: new Date().toISOString(), isDeleted: false });

        adminNotifId = 'ns_i_admin';
        await seedNotification(db, adminNotifId, complaintRequesterNotificationData('some_complaint'));

        personalNotifId = 'ns_i_personal';
        await seedNotification(db, personalNotifId, orderUpdateNotificationData(custA, 'ord_1'));
      });
    });

    it('two Customers can both read one customer-role notification', async () => {
      const dbA = testEnv.authenticatedContext(custA).firestore();
      const dbB = testEnv.authenticatedContext(custB).firestore();
      await assertSucceeds(getDoc(doc(dbA, 'notifications', roleNotifId)));
      await assertSucceeds(getDoc(doc(dbB, 'notifications', roleNotifId)));
    });

    it("Customer A marking it read never touches Customer B's state", async () => {
      const dbA = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(setDoc(
        doc(dbA, 'users', custA, 'notification_states', roleNotifId),
        notificationStateData(roleNotifId, custA),
      ));
      // B's own state doc still doesn't exist — B was never touched.
      const dbB = testEnv.authenticatedContext(custB).firestore();
      const bState = await getDoc(doc(dbB, 'users', custB, 'notification_states', roleNotifId));
      if (bState.exists()) throw new Error('Customer B unexpectedly has state after Customer A marked it read');
      // And A cannot have written into B's path even if attempted directly.
      await assertFails(setDoc(
        doc(dbA, 'users', custB, 'notification_states', roleNotifId),
        notificationStateData(roleNotifId, custB),
      ));
    });

    it("Customer A soft-deleting it never touches Customer B's state", async () => {
      const dbA = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(setDoc(
        doc(dbA, 'users', custA, 'notification_states', roleNotifId),
        { notificationId: roleNotifId, userId: custA, isDeleted: true, updatedAt: new Date().toISOString() },
      ));
      const dbB = testEnv.authenticatedContext(custB).firestore();
      // B still sees the content document (targeting is unaffected by A's state).
      await assertSucceeds(getDoc(doc(dbB, 'notifications', roleNotifId)));
      const bState = await getDoc(doc(dbB, 'users', custB, 'notification_states', roleNotifId));
      if (bState.exists()) throw new Error('Customer B unexpectedly has state after Customer A deleted it');
    });

    it('two Admins independently mark one admin-role notification read', async () => {
      const dbX = testEnv.authenticatedContext(adminX).firestore();
      const dbY = testEnv.authenticatedContext(adminY).firestore();
      await assertSucceeds(setDoc(
        doc(dbX, 'users', adminX, 'notification_states', adminNotifId),
        notificationStateData(adminNotifId, adminX),
      ));
      const yState = await getDoc(doc(dbY, 'users', adminY, 'notification_states', adminNotifId));
      if (yState.exists()) throw new Error('Admin Y unexpectedly has state after Admin X marked it read');
      await assertSucceeds(setDoc(
        doc(dbY, 'users', adminY, 'notification_states', adminNotifId),
        notificationStateData(adminNotifId, adminY),
      ));
    });

    it('user-targeted notification state remains private', async () => {
      const dbA = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(setDoc(
        doc(dbA, 'users', custA, 'notification_states', personalNotifId),
        notificationStateData(personalNotifId, custA),
      ));
      const dbB = testEnv.authenticatedContext(custB).firestore();
      await assertFails(getDoc(doc(dbB, 'users', custA, 'notification_states', personalNotifId)));
    });

    it('mark-all-style batched writes only ever touch the acting uid', async () => {
      const dbA = testEnv.authenticatedContext(custA).firestore();
      const batch = writeBatch(dbA);
      batch.set(
        doc(dbA, 'users', custA, 'notification_states', roleNotifId),
        notificationStateData(roleNotifId, custA),
      );
      batch.set(
        doc(dbA, 'users', custA, 'notification_states', personalNotifId),
        notificationStateData(personalNotifId, custA),
      );
      await assertSucceeds(batch.commit());

      // A batch that also tries to slip in a write to another user's path
      // must fail atomically (Firestore batches are all-or-nothing; a
      // single denied operation fails the whole batch).
      const badBatch = writeBatch(dbA);
      badBatch.set(
        doc(dbA, 'users', custA, 'notification_states', roleNotifId),
        notificationStateData(roleNotifId, custA),
      );
      badBatch.set(
        doc(dbA, 'users', custB, 'notification_states', roleNotifId),
        notificationStateData(roleNotifId, custB),
      );
      await assertFails(badBatch.commit());
    });
  });
});
