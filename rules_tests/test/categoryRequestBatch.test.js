'use strict';

// Atomic-batch compatibility check for the real
// CategoryRequestsNotifier.approveInFirestore() batch (admin_providers.dart):
//   batch.set(categories/{categoryId}, newCategory.toMap())
//   batch.update(category_requests/{requestId}, {status, reviewedAt, reviewedBy})
// Both categories/{categoryId} (Phase 1B) and category_requests/{requestId}
// (Phase 2A) are now hardened to Admin-only for this kind of write, so these
// tests prove the real batch still commits for Admin and still fails
// atomically (leaving no partial category doc) for a non-admin.

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, writeBatch } = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const { adminData, customerData, nowIso } = require('./fixtures');

describe('Category Request approval — atomic batch compatibility', function () {
  this.timeout(20000);
  let testEnv;

  const adminUid = 'batch_admin';
  const customerUid = 'batch_customer';
  const reqId = 'req_1';
  const approvedReqId = 'req_already_approved';

  before(async () => {
    testEnv = await getTestEnv();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
      await setDoc(doc(db, 'users', customerUid), customerData(customerUid));
      await setDoc(doc(db, 'category_requests', reqId), {
        requesterId: customerUid,
        requesterName: 'Test Customer',
        requesterRole: 'customer',
        requestedName: 'Carpentry',
        requestedDescription: 'Wood work',
        status: 'pending',
        createdAt: nowIso(),
      });
      await setDoc(doc(db, 'category_requests', approvedReqId), {
        requesterId: customerUid,
        requesterName: 'Test Customer',
        requesterRole: 'customer',
        requestedName: 'Masonry',
        requestedDescription: 'Stone work',
        status: 'approved',
        createdAt: nowIso(),
        reviewedAt: nowIso(),
        reviewedBy: 'Admin',
      });
    });
  });

  it('N. Admin batch (categories.set + category_requests.update) succeeds', async () => {
    const db = testEnv.authenticatedContext(adminUid).firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'categories', 'carpentry'), {
      nameKey: 'carpentry', icon: '🪚', providerCount: 0, isActive: true,
    });
    batch.update(doc(db, 'category_requests', reqId), {
      status: 'approved',
      reviewedAt: nowIso(),
      reviewedBy: 'Admin',
    });
    await assertSucceeds(batch.commit());
  });

  it('O. Customer batch is denied because the categories create is denied', async () => {
    const db = testEnv.authenticatedContext(customerUid).firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'categories', 'carpentry_by_customer'), {
      nameKey: 'carpentry', icon: '🪚', providerCount: 0, isActive: true,
    });
    // Since Phase 2A, the category_requests half alone would ALSO now be
    // denied for this customer (status/reviewedAt/reviewedBy are not in the
    // owner's allowed field list) — the batch is doubly guaranteed to fail,
    // and still fails atomically as a single unit either way.
    batch.update(doc(db, 'category_requests', reqId), {
      status: 'approved',
      reviewedAt: nowIso(),
      reviewedBy: 'Customer',
    });
    await assertFails(batch.commit());

    // Atomicity proof: the categories half must not have landed either.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), 'categories', 'carpentry_by_customer'));
      if (snap.exists()) {
        throw new Error('Atomicity violated: category document was created despite batch denial.');
      }
    });
  });

  it('Admin batch approving an already-approved request fails (pending-only transition)', async () => {
    const db = testEnv.authenticatedContext(adminUid).firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'categories', 'masonry'), {
      nameKey: 'masonry', icon: '🧱', providerCount: 0, isActive: true,
    });
    batch.update(doc(db, 'category_requests', approvedReqId), {
      status: 'approved',
      reviewedAt: nowIso(),
      reviewedBy: 'Admin',
    });
    await assertFails(batch.commit());

    // The failed batch must create no category document.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), 'categories', 'masonry'));
      if (snap.exists()) {
        throw new Error('Atomicity violated: category document was created despite batch denial.');
      }
    });
  });
});
