'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  customerData, professionalData, contractorData, adminData,
  orderDocId, orderData, reviewDocId, reviewData,
  categoryRequestData, orderComplaintData,
  orderUpdateNotificationData, reviewNotificationData,
  complaintRequesterNotificationData, complaintAdminNotificationData,
  categoryRequestRequesterNotificationData, categoryRequestAdminNotificationData,
  systemNotificationData, broadcastNotificationData,
} = require('./fixtures');

describe('notifications/{notificationId} security rules', function () {
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
    const custA = 'nf_read_custA';
    const custB = 'nf_read_custB';
    const proUid = 'nf_read_pro';
    const adminUid = 'nf_read_admin';
    let personalId, roleId, allId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));

        const orderId = orderDocId();
        await setDoc(doc(db, 'orders', orderId), orderData(custA, proUid, 'professional', orderId));

        const pRef = doc(collection(db, 'notifications'));
        personalId = pRef.id;
        await setDoc(pRef, { id: personalId, ...orderUpdateNotificationData(custA, orderId) });

        const rRef = doc(collection(db, 'notifications'));
        roleId = rRef.id;
        await setDoc(rRef, { id: roleId, ...complaintRequesterNotificationData('some_complaint_id') });

        const aRef = doc(collection(db, 'notifications'));
        allId = aRef.id;
        await setDoc(aRef, { id: allId, ...broadcastNotificationData('all') });
      });
    });

    it('userId owner direct read succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(db, 'notifications', personalId)));
    });

    it("userId equality query succeeds", async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'notifications'), where('userId', '==', custA));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 1) throw new Error(`Expected 1 personal notification, got ${snap.size}`);
    });

    it('another user direct read fails', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(getDoc(doc(db, 'notifications', personalId)));
    });

    it('role-matching user direct read succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'notifications', roleId)));
    });

    it("role whereIn [role, all] query succeeds", async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const q = query(collection(db, 'notifications'), where('targetRole', 'in', ['admin', 'all']));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 2) throw new Error(`Expected 2 (role + all) notifications, got ${snap.size}`);
    });

    it('wrong role fails', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(getDoc(doc(db, 'notifications', roleId)));
    });

    it('targetRole all succeeds for Customer/Professional/Contractor/Admin', async () => {
      for (const uid of [custA, custB, proUid, adminUid]) {
        const db = testEnv.authenticatedContext(uid).firestore();
        await assertSucceeds(getDoc(doc(db, 'notifications', allId)));
      }
    });

    it('non-admin unfiltered query fails', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(getDocs(collection(db, 'notifications')));
    });

    it('Admin unfiltered query also fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(getDocs(collection(db, 'notifications')));
    });

    it("Admin sees userId-targeted/Admin-role/all notifications only", async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      // Admin's own userId query — should not include the customer-targeted doc.
      const ownQ = query(collection(db, 'notifications'), where('userId', '==', adminUid));
      const ownSnap = await assertSucceeds(getDocs(ownQ));
      if (ownSnap.size !== 0) throw new Error(`Expected 0 admin-userId notifications, got ${ownSnap.size}`);
      // Admin's role/all query — should see the admin-role complaint notification + broadcast, not the customer-personal one.
      const roleQ = query(collection(db, 'notifications'), where('targetRole', 'in', ['admin', 'all']));
      const roleSnap = await assertSucceeds(getDocs(roleQ));
      if (roleSnap.size !== 2) throw new Error(`Expected 2, got ${roleSnap.size}`);
      await assertFails(getDoc(doc(db, 'notifications', personalId)));
    });

    it('unauthenticated reads fail', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'notifications', personalId)));
      await assertFails(getDoc(doc(db, 'notifications', roleId)));
      await assertFails(getDoc(doc(db, 'notifications', allId)));
    });
  });

  // ── create: order_update ───────────────────────────────────────────────
  describe('create — order_update', () => {
    const custA = 'nf_ord_custA';
    const proUid = 'nf_ord_pro';
    const otherUid = 'nf_ord_other';
    const adminUid = 'nf_ord_admin';
    let orderId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        orderId = orderDocId();
        await setDoc(doc(db, 'orders', orderId), orderData(custA, proUid, 'professional', orderId));
      });
    });

    it('provider -> customer succeeds (accept/complete/reject)', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, { id: ref.id, ...orderUpdateNotificationData(custA, orderId) }));
    });

    it('customer -> provider succeeds (new order)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...orderUpdateNotificationData(proUid, orderId, { title: 'New Order', message: 'You received a new order request.' }),
      }));
    });

    it('Admin -> customer succeeds (approve/complete)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, { id: ref.id, ...orderUpdateNotificationData(custA, orderId) }));
    });

    it('unrelated order actor fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...orderUpdateNotificationData(custA, orderId) }));
    });

    it('wrong order target fails (provider targeting self instead of customer)', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...orderUpdateNotificationData(proUid, orderId) }));
    });

    it('Admin -> provider fails (no real Admin->provider path exists)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...orderUpdateNotificationData(proUid, orderId) }));
    });

    it('targetRole present fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...orderUpdateNotificationData(custA, orderId, { targetRole: 'customer' }),
      }));
    });

    it('unknown related order id fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...orderUpdateNotificationData(custA, 'nonexistent_order') }));
    });
  });

  // ── create: review ─────────────────────────────────────────────────────
  describe('create — review', () => {
    const custA = 'nf_rev_custA';
    const proUid = 'nf_rev_pro';
    const otherUid = 'nf_rev_other';
    const adminUid = 'nf_rev_admin';
    let reviewId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        reviewId = reviewDocId(custA, proUid);
        await setDoc(doc(db, 'reviews', reviewId), reviewData(custA, proUid, 'professional'));
      });
    });

    it('Customer -> reviewed provider succeeds (with relatedUserId)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...reviewNotificationData(proUid, reviewId, { relatedUserId: custA }),
      }));
    });

    it('Admin -> reviewer succeeds (hide/restore shape, no relatedUserId/createdByRole)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...reviewNotificationData(custA, reviewId, { title: 'Review Hidden', message: 'Your review was hidden by an administrator.' }),
      }));
    });

    it('Admin -> reviewer succeeds (warn-reviewer shape, createdByRole present)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...reviewNotificationData(custA, reviewId, { title: 'Warning From Administration', createdByRole: 'admin' }),
      }));
    });

    it('fake review target fails (wrong userId)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...reviewNotificationData(otherUid, reviewId) }));
    });

    it('non-participant customer cannot create a review notification', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...reviewNotificationData(proUid, reviewId) }));
    });

    it('spoofed createdByRole fails for the non-admin producer', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...reviewNotificationData(proUid, reviewId, { createdByRole: 'admin' }),
      }));
    });
  });

  // ── create: complaint ──────────────────────────────────────────────────
  describe('create — complaint', () => {
    const custA = 'nf_cmp_custA';
    const otherUid = 'nf_cmp_other';
    const adminUid = 'nf_cmp_admin';
    let complaintId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        const ref = doc(collection(db, 'complaints'));
        complaintId = ref.id;
        await setDoc(ref, { id: complaintId, ...orderComplaintData(custA, 'customer', 'some_order') });
      });
    });

    it('complaint requester -> admin succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, { id: ref.id, ...complaintRequesterNotificationData(complaintId) }));
    });

    it('complaint Admin -> owner succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, { id: ref.id, ...complaintAdminNotificationData(custA, complaintId) }));
    });

    it('non-owner cannot create the requester->admin notification', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...complaintRequesterNotificationData(complaintId) }));
    });

    it('Admin -> wrong complainant fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...complaintAdminNotificationData(otherUid, complaintId) }));
    });

    it('non-admin cannot create the admin->complainant shape', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...complaintAdminNotificationData(custA, complaintId) }));
    });

    it('unknown related complaint id fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...complaintRequesterNotificationData('nonexistent_complaint') }));
    });

    it('spoofed createdByRole fails for the requester->admin producer', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...complaintRequesterNotificationData(complaintId, { createdByRole: 'admin' }),
      }));
    });
  });

  // ── create: category_request ───────────────────────────────────────────
  describe('create — category_request (Phase 5C3: relatedCategoryRequestId required)', () => {
    const custA = 'nf_cat_custA';
    const custOther = 'nf_cat_custOther';
    const proX = 'nf_cat_proX';
    const conX = 'nf_cat_conX';
    const adminUid = 'nf_cat_admin';
    let pendingCustReqId, pendingProReqId, pendingConReqId;
    let approvedReqId, rejectedReqId, mismatchedRoleReqId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custOther), customerData(custOther));
        await setDoc(doc(db, 'users', proX), professionalData(proX));
        await setDoc(doc(db, 'users', conX), contractorData(conX));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));

        const mk = async (requesterId, requesterRole, overrides = {}) => {
          const ref = doc(collection(db, 'category_requests'));
          await setDoc(ref, categoryRequestData(requesterId, requesterRole, overrides));
          return ref.id;
        };
        pendingCustReqId = await mk(custA, 'customer');
        pendingProReqId = await mk(proX, 'professional');
        pendingConReqId = await mk(conX, 'contractor');
        approvedReqId = await mk(custA, 'customer', { status: 'approved' });
        rejectedReqId = await mk(custA, 'customer', { status: 'rejected' });
        // Doc claims the requester is a professional, but custA's stored
        // account role is 'customer' — the mismatch the rule must catch.
        mismatchedRoleReqId = await mk(custA, 'professional');
      });
    });

    // ── requester -> admin ──────────────────────────────────────────────
    it('Customer with own pending request succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...categoryRequestRequesterNotificationData(pendingCustReqId),
      }));
    });

    it('Professional with own pending request succeeds', async () => {
      const db = testEnv.authenticatedContext(proX).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...categoryRequestRequesterNotificationData(pendingProReqId),
      }));
    });

    it('Contractor with own pending request succeeds', async () => {
      const db = testEnv.authenticatedContext(conX).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...categoryRequestRequesterNotificationData(pendingConReqId),
      }));
    });

    it('missing relatedCategoryRequestId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        targetRole: 'admin',
        title: 'New Category Request',
        message: 'A user requested a new category.',
        type: 'category_request',
        isRead: false,
        createdAt: new Date().toISOString(),
        isDeleted: false,
      }));
    });

    it('nonexistent request fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestRequesterNotificationData('ghost_category_request'),
      }));
    });

    it("another user's request fails", async () => {
      const db = testEnv.authenticatedContext(custOther).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestRequesterNotificationData(pendingCustReqId),
      }));
    });

    it('mismatched requesterRole fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestRequesterNotificationData(mismatchedRoleReqId),
      }));
    });

    it('approved request fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestRequesterNotificationData(approvedReqId),
      }));
    });

    it('rejected request fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestRequesterNotificationData(rejectedReqId),
      }));
    });

    it('fake createdByRole:admin fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestRequesterNotificationData(pendingCustReqId, { createdByRole: 'admin' }),
      }));
    });

    it('unrelated related field (relatedOrderId) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestRequesterNotificationData(pendingCustReqId, { relatedOrderId: 'some_order' }),
      }));
    });

    it('unknown field fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestRequesterNotificationData(pendingCustReqId, { extraField: 'hack' }),
      }));
    });

    // ── Admin -> requester ──────────────────────────────────────────────
    it('approval notification succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...categoryRequestAdminNotificationData(custA, approvedReqId),
      }));
    });

    it('rejection notification succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...categoryRequestAdminNotificationData(custA, rejectedReqId, { title: 'Category Request Rejected', message: 'Your request was rejected.' }),
      }));
    });

    it('wrong target user fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestAdminNotificationData(custOther, approvedReqId),
      }));
    });

    it('non-admin approval notification fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestAdminNotificationData(custA, approvedReqId),
      }));
    });

    it('non-admin rejection notification fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestAdminNotificationData(custA, rejectedReqId),
      }));
    });

    it('Admin notification against a still-pending request fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestAdminNotificationData(custA, pendingCustReqId),
      }));
    });

    it('Admin notification with a nonexistent relatedCategoryRequestId fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...categoryRequestAdminNotificationData(custA, 'ghost_category_request'),
      }));
    });

    it('Admin notification with missing relatedCategoryRequestId fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        userId: custA,
        title: 'Category Request Approved',
        message: 'Your request was approved.',
        type: 'category_request',
        isRead: false,
        createdAt: new Date().toISOString(),
        isDeleted: false,
      }));
    });
  });

  // ── create: system ─────────────────────────────────────────────────────
  describe('create — system', () => {
    const custA = 'nf_sys_custA';
    const adminUid = 'nf_sys_admin';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
      });
    });

    it('Admin creates a valid profile/worker/warning-shaped system notification', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertSucceeds(setDoc(ref, { id: ref.id, ...systemNotificationData(custA) }));
    });

    it('non-admin system create fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...systemNotificationData(custA) }));
    });

    it('Admin system create without createdByRole:admin fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...systemNotificationData(custA, { createdByRole: 'system' }),
      }));
    });

    it('system notification targeting a deleted user fails', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users', 'nf_sys_deleted'), customerData('nf_sys_deleted', { isDeleted: true }));
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...systemNotificationData('nf_sys_deleted') }));
    });

    it('system notification targeting a nonexistent user fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...systemNotificationData('nf_sys_ghost') }));
    });
  });

  // ── create: broadcast ──────────────────────────────────────────────────
  describe('create — broadcast', () => {
    const custA = 'nf_bc_custA';
    const adminUid = 'nf_bc_admin';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
      });
    });

    it('Admin broadcast to each allowed role/all succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      for (const role of ['all', 'customer', 'professional', 'contractor']) {
        const ref = doc(collection(db, 'notifications'));
        await assertSucceeds(setDoc(ref, { id: ref.id, ...broadcastNotificationData(role) }));
      }
    });

    it('non-admin broadcast fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...broadcastNotificationData('all') }));
    });

    it('broadcast to admin fails (no real Admin self-broadcast path)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...broadcastNotificationData('admin') }));
    });

    it('broadcast to an unknown targetRole fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...broadcastNotificationData('superuser') }));
    });

    it('broadcast with a userId fails (broadcasts are targetRole-only, never per-user)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...broadcastNotificationData('all', { userId: custA }) }));
    });

    it('spoofed Admin broadcast identity (createdByRole != admin) fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...broadcastNotificationData('all', { createdByRole: 'system' }) }));
    });
  });

  // ── create: general / chat (no real producer) ──────────────────────────
  describe('create — general / chat', () => {
    const custA = 'nf_gc_custA';
    const adminUid = 'nf_gc_admin';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
      });
    });

    it('general create fails for any signed-in user, including Admin', async () => {
      for (const uid of [custA, adminUid]) {
        const db = testEnv.authenticatedContext(uid).firestore();
        const ref = doc(collection(db, 'notifications'));
        await assertFails(setDoc(ref, {
          id: ref.id, title: 'General', message: 'msg', type: 'general',
          isRead: false, createdAt: new Date().toISOString(), isDeleted: false,
        }));
      }
    });

    it('chat create fails for any signed-in user, including Admin', async () => {
      for (const uid of [custA, adminUid]) {
        const db = testEnv.authenticatedContext(uid).firestore();
        const ref = doc(collection(db, 'notifications'));
        await assertFails(setDoc(ref, {
          id: ref.id, title: 'Chat', message: 'msg', type: 'chat',
          isRead: false, createdAt: new Date().toISOString(), isDeleted: false,
        }));
      }
    });
  });

  // ── create: base-field / unknown-field validation ──────────────────────
  describe('create — base validation', () => {
    const custA = 'nf_base_custA';
    const proUid = 'nf_base_pro';
    let orderId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        orderId = orderDocId();
        await setDoc(doc(db, 'orders', orderId), orderData(custA, proUid, 'professional', orderId));
      });
    });

    it('unknown field fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...orderUpdateNotificationData(custA, orderId, { extraField: 'hack' }),
      }));
    });

    it('wrong id field fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: 'not_the_real_id', ...orderUpdateNotificationData(custA, orderId) }));
    });

    it('empty title fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...orderUpdateNotificationData(custA, orderId, { title: '' }) }));
    });

    it('invalid initial isRead:true fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...orderUpdateNotificationData(custA, orderId, { isRead: true }) }));
    });

    it('invalid initial isDeleted:true fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, { id: ref.id, ...orderUpdateNotificationData(custA, orderId, { isDeleted: true }) }));
    });

    it('readAt present at creation fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'notifications'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...orderUpdateNotificationData(custA, orderId, { readAt: new Date().toISOString() }),
      }));
    });
  });

  // ── content immutability ───────────────────────────────────────────────
  describe('content immutability', () => {
    const custA = 'nf_imm_custA';
    const proUid = 'nf_imm_pro';
    const adminUid = 'nf_imm_admin';
    let notifId, orderId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        orderId = orderDocId();
        await setDoc(doc(db, 'orders', orderId), orderData(custA, proUid, 'professional', orderId));
        const ref = doc(collection(db, 'notifications'));
        notifId = ref.id;
        await setDoc(ref, { id: notifId, ...orderUpdateNotificationData(custA, orderId) });
      });
    });

    it('owner cannot mark shared notification content read', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'notifications', notifId), { isRead: true }));
    });

    it('owner cannot soft-delete shared content', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'notifications', notifId), { isDeleted: true }));
    });

    it('Admin cannot update notification content', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'notifications', notifId), { isRead: true }));
    });

    it('retarget userId fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'notifications', notifId), { userId: proUid }));
    });

    it('type change fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'notifications', notifId), { type: 'broadcast' }));
    });

    it('related-ID change fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'notifications', notifId), { relatedOrderId: 'someone_elses_order' }));
    });

    it('title/message change fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'notifications', notifId), { title: 'Hacked', message: 'Hacked' }));
    });

    it('physical delete fails (owner)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(deleteDoc(doc(db, 'notifications', notifId)));
    });

    it('physical delete fails (Admin)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(deleteDoc(doc(db, 'notifications', notifId)));
    });
  });

  // ── legacy documents ───────────────────────────────────────────────────
  describe('legacy documents', () => {
    const custA = 'nf_legacy_custA';
    const custB = 'nf_legacy_custB';
    let notifId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        const ref = doc(collection(db, 'notifications'));
        notifId = ref.id;
        // Pre-Phase-5C2 shared-state shape: isRead/isDeleted already true on
        // the shared content document itself (the exact bug Phase 5C1B
        // proved) — targeting is still the source of truth for visibility.
        await setDoc(ref, {
          id: notifId,
          userId: custA,
          title: 'Legacy Notice',
          message: 'Old shared-state notification.',
          type: 'system',
          isRead: true,
          isDeleted: true,
          createdAt: new Date().toISOString(),
        });
      });
    });

    it('legacy content doc with shared isRead:true/isDeleted:true remains readable according to targeting', async () => {
      const dbA = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(dbA, 'notifications', notifId)));
    });

    it('the shared legacy isRead/isDeleted fields do not grant another user read access', async () => {
      const dbB = testEnv.authenticatedContext(custB).firestore();
      await assertFails(getDoc(doc(dbB, 'notifications', notifId)));
    });

    // Effective per-user isRead/isDeleted for this legacy document (i.e.
    // whether the Flutter overlay in _mergeNotifications treats it as
    // unread/visible despite the shared fields saying otherwise) is client
    // logic, not something Firestore Rules can express — verified by code
    // review of _mergeNotifications (app_providers.dart) in the Phase 5C2
    // report and confirmed manually per the QA checklist there, not here.
  });
});
