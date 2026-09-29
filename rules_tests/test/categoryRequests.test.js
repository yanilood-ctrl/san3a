'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, query, where,
  setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  nowIso, customerData, professionalData, contractorData, adminData,
  categoryRequestData,
} = require('./fixtures');

describe('category_requests/{requestId} security rules', function () {
  this.timeout(20000);
  let testEnv;

  before(async () => {
    testEnv = await getTestEnv();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  // ── reads ───────────────────────────────────────────────────────────────
  describe('reads', () => {
    const ownerUid = 'req_owner';
    const otherUid = 'req_other_user';
    const adminUid = 'req_reader_admin';
    const reqId = 'req_read_1';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', ownerUid), customerData(ownerUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'category_requests', reqId),
          categoryRequestData(ownerUid, 'customer'));
      });
    });

    it('owner single-document read succeeds', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'category_requests', reqId)));
    });

    it('owner query constrained by requesterId succeeds', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      const q = query(collection(db, 'category_requests'), where('requesterId', '==', ownerUid));
      await assertSucceeds(getDocs(q));
    });

    it('another user read fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(getDoc(doc(db, 'category_requests', reqId)));
    });

    it('unauthenticated read fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'category_requests', reqId)));
    });

    it('non-admin unfiltered collection query fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(getDocs(collection(db, 'category_requests')));
    });

    it('admin single-document read succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'category_requests', reqId)));
    });

    it('admin unfiltered collection read succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDocs(collection(db, 'category_requests')));
    });
  });

  // ── create ──────────────────────────────────────────────────────────────
  describe('create', () => {
    const customerUid = 'creq_customer';
    const proUid = 'creq_pro';
    const conUid = 'creq_con';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', customerUid), customerData(customerUid));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
      });
    });

    it('Customer valid pending request succeeds', async () => {
      const db = testEnv.authenticatedContext(customerUid).firestore();
      await assertSucceeds(setDoc(doc(db, 'category_requests', 'c1'),
        categoryRequestData(customerUid, 'customer')));
    });

    it('Professional valid pending request succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(setDoc(doc(db, 'category_requests', 'p1'),
        categoryRequestData(proUid, 'professional')));
    });

    it('Contractor valid pending request succeeds', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      await assertSucceeds(setDoc(doc(db, 'category_requests', 'k1'),
        categoryRequestData(conUid, 'contractor')));
    });

    it('spoofed requesterId fails', async () => {
      const db = testEnv.authenticatedContext(customerUid).firestore();
      await assertFails(setDoc(doc(db, 'category_requests', 'bad1'),
        categoryRequestData(otherUidFor(customerUid), 'customer')));
    });

    it('requesterRole not matching stored role fails', async () => {
      const db = testEnv.authenticatedContext(customerUid).firestore();
      await assertFails(setDoc(doc(db, 'category_requests', 'bad2'),
        categoryRequestData(customerUid, 'professional')));
    });

    it('requesterRole == admin fails', async () => {
      const db = testEnv.authenticatedContext(customerUid).firestore();
      await assertFails(setDoc(doc(db, 'category_requests', 'bad3'),
        categoryRequestData(customerUid, 'admin')));
    });

    it('unsupported requesterRole fails', async () => {
      const db = testEnv.authenticatedContext(customerUid).firestore();
      await assertFails(setDoc(doc(db, 'category_requests', 'bad4'),
        categoryRequestData(customerUid, 'superuser')));
    });

    it('status approved at creation fails', async () => {
      const db = testEnv.authenticatedContext(customerUid).firestore();
      await assertFails(setDoc(doc(db, 'category_requests', 'bad5'),
        categoryRequestData(customerUid, 'customer', { status: 'approved' })));
    });

    it('status rejected at creation fails', async () => {
      const db = testEnv.authenticatedContext(customerUid).firestore();
      await assertFails(setDoc(doc(db, 'category_requests', 'bad6'),
        categoryRequestData(customerUid, 'customer', { status: 'rejected' })));
    });

    it('privileged reviewedAt at creation fails', async () => {
      const db = testEnv.authenticatedContext(customerUid).firestore();
      await assertFails(setDoc(doc(db, 'category_requests', 'bad7'),
        categoryRequestData(customerUid, 'customer', { reviewedAt: nowIso() })));
    });

    it('privileged reviewedBy at creation fails', async () => {
      const db = testEnv.authenticatedContext(customerUid).firestore();
      await assertFails(setDoc(doc(db, 'category_requests', 'bad8'),
        categoryRequestData(customerUid, 'customer', { reviewedBy: 'Admin' })));
    });

    it('privileged adminNote at creation fails', async () => {
      const db = testEnv.authenticatedContext(customerUid).firestore();
      await assertFails(setDoc(doc(db, 'category_requests', 'bad9'),
        categoryRequestData(customerUid, 'customer', { adminNote: 'sneaky' })));
    });

    function otherUidFor(uid) {
      return `not_${uid}`;
    }
  });

  // ── owner update ────────────────────────────────────────────────────────
  describe('owner update', () => {
    const ownerUid = 'oupd_owner';
    const otherUid = 'oupd_other';
    const pendingId = 'oupd_pending';
    const approvedId = 'oupd_approved';
    const rejectedId = 'oupd_rejected';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', ownerUid), customerData(ownerUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'category_requests', pendingId),
          categoryRequestData(ownerUid, 'customer'));
        await setDoc(doc(db, 'category_requests', approvedId),
          categoryRequestData(ownerUid, 'customer', {
            status: 'approved', reviewedAt: nowIso(), reviewedBy: 'Admin',
          }));
        await setDoc(doc(db, 'category_requests', rejectedId),
          categoryRequestData(ownerUid, 'customer', {
            status: 'rejected', reviewedAt: nowIso(), reviewedBy: 'Admin',
          }));
      });
    });

    it('owner edits the exact allowed pending fields successfully', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'category_requests', pendingId), {
        requestedName: 'Updated Name',
        requestedDescription: 'Updated description',
      }));
    });

    it('another user edit fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', pendingId), {
        requestedName: 'Hacked',
      }));
    });

    it('requesterId change fails', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', pendingId), {
        requesterId: otherUid,
      }));
    });

    it('requesterRole change fails', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', pendingId), {
        requesterRole: 'professional',
      }));
    });

    it('status change by owner fails', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', pendingId), {
        status: 'approved',
      }));
    });

    it('reviewedAt/reviewedBy change by owner fails', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', pendingId), {
        reviewedAt: nowIso(),
        reviewedBy: 'Admin',
      }));
    });

    it('owner edit after approved fails', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', approvedId), {
        requestedName: 'Too late',
      }));
    });

    it('owner edit after rejected fails', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', rejectedId), {
        requestedName: 'Too late',
      }));
    });

    it('unknown-field update fails', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', pendingId), {
        secretField: 'nope',
      }));
    });
  });

  // ── admin update ────────────────────────────────────────────────────────
  describe('admin update', () => {
    const adminUid = 'aupd_admin';
    const ownerUid = 'aupd_owner';
    const pendingId = 'aupd_pending';
    const approvedId = 'aupd_approved';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'users', ownerUid), customerData(ownerUid));
        await setDoc(doc(db, 'category_requests', pendingId),
          categoryRequestData(ownerUid, 'customer'));
        await setDoc(doc(db, 'category_requests', approvedId),
          categoryRequestData(ownerUid, 'customer', {
            status: 'approved', reviewedAt: nowIso(), reviewedBy: 'Admin',
          }));
      });
    });

    it('Admin approval of a pending request succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'category_requests', pendingId), {
        status: 'approved',
        reviewedAt: nowIso(),
        reviewedBy: 'Admin',
      }));
    });

    it('Admin rejection of a pending request succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'category_requests', pendingId), {
        status: 'rejected',
        reviewedAt: nowIso(),
        reviewedBy: 'Admin',
      }));
    });

    it('Admin cannot change requesterId', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', pendingId), {
        requesterId: adminUid,
        status: 'approved',
        reviewedAt: nowIso(),
        reviewedBy: 'Admin',
      }));
    });

    it('Admin cannot change requesterRole', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', pendingId), {
        requesterRole: 'professional',
        status: 'approved',
        reviewedAt: nowIso(),
        reviewedBy: 'Admin',
      }));
    });

    it('Admin cannot change createdAt', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', pendingId), {
        createdAt: nowIso(),
        status: 'approved',
        reviewedAt: nowIso(),
        reviewedBy: 'Admin',
      }));
    });

    it('invalid status value fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', pendingId), {
        status: 'archived',
        reviewedAt: nowIso(),
        reviewedBy: 'Admin',
      }));
    });

    it('re-reviewing a non-pending request is denied (pending-only transition)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'category_requests', approvedId), {
        status: 'rejected',
        reviewedAt: nowIso(),
        reviewedBy: 'Admin',
      }));
    });
  });

  // ── delete ──────────────────────────────────────────────────────────────
  describe('delete', () => {
    const ownerUid = 'del_owner';
    const otherUid = 'del_other';
    const adminUid = 'del_admin';
    const pendingId = 'del_pending';
    const approvedId = 'del_approved';
    const rejectedId = 'del_rejected';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', ownerUid), customerData(ownerUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'category_requests', pendingId),
          categoryRequestData(ownerUid, 'customer'));
        await setDoc(doc(db, 'category_requests', approvedId),
          categoryRequestData(ownerUid, 'customer', {
            status: 'approved', reviewedAt: nowIso(), reviewedBy: 'Admin',
          }));
        await setDoc(doc(db, 'category_requests', rejectedId),
          categoryRequestData(ownerUid, 'customer', {
            status: 'rejected', reviewedAt: nowIso(), reviewedBy: 'Admin',
          }));
      });
    });

    it('owner deletes own pending request successfully', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertSucceeds(deleteDoc(doc(db, 'category_requests', pendingId)));
    });

    it('another user delete fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(deleteDoc(doc(db, 'category_requests', pendingId)));
    });

    it('owner delete after approved fails', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertFails(deleteDoc(doc(db, 'category_requests', approvedId)));
    });

    it('owner delete after rejected fails', async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertFails(deleteDoc(doc(db, 'category_requests', rejectedId)));
    });

    it('Admin delete fails (no legitimate Admin delete flow exists)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(deleteDoc(doc(db, 'category_requests', pendingId)));
    });
  });
});
