'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  customerData, professionalData, contractorData, adminData,
  orderDocId, orderData, reviewDocId, reviewData,
  orderComplaintData, providerReportData, reviewReportComplaintData, generalComplaintData,
} = require('./fixtures');

describe('complaints/{complaintId} security rules', function () {
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
    const custA = 'cx_read_custA';
    const otherUid = 'cx_read_other';
    const adminUid = 'cx_read_admin';
    let complaintId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        const ref = doc(collection(db, 'complaints'));
        complaintId = ref.id;
        await setDoc(ref, { id: complaintId, ...generalComplaintData(custA, 'customer') });
      });
    });

    it('owner single read succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(db, 'complaints', complaintId)));
    });

    it("owner's real where('complainantId', isEqualTo: uid) query succeeds", async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'complaints'), where('complainantId', '==', custA));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 1) throw new Error(`Expected 1 complaint, got ${snap.size}`);
    });

    it('another user read fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(getDoc(doc(db, 'complaints', complaintId)));
    });

    it('unauthenticated read fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'complaints', complaintId)));
    });

    it('non-Admin unfiltered collection query fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(getDocs(collection(db, 'complaints')));
    });

    it('Admin single read succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'complaints', complaintId)));
    });

    it('Admin unfiltered query succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const snap = await assertSucceeds(getDocs(collection(db, 'complaints')));
      if (snap.size !== 1) throw new Error(`Expected 1 complaint for admin, got ${snap.size}`);
    });
  });

  // ── create: order_problem ─────────────────────────────────────────────────
  describe('create — order_problem', () => {
    const custA = 'cx_ord_custA';
    const proUid = 'cx_ord_pro';
    const conUid = 'cx_ord_con';
    const otherUid = 'cx_ord_other';
    let orderCustPro, orderCustCon;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        orderCustPro = orderDocId();
        await setDoc(doc(db, 'orders', orderCustPro),
          orderData(custA, proUid, 'professional', orderCustPro));
        orderCustCon = orderDocId();
        await setDoc(doc(db, 'orders', orderCustCon),
          orderData(custA, conUid, 'contractor', orderCustCon));
      });
    });

    it('valid order_problem by Customer succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...orderComplaintData(custA, 'customer', orderCustPro, {
          targetUserId: proUid, targetUserName: 'Test Provider', targetUserRole: 'professional',
          relatedProviderId: proUid, relatedProviderName: 'Test Provider',
        }),
      }));
    });

    it('valid order_problem by Professional succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...orderComplaintData(proUid, 'professional', orderCustPro, {
          targetUserId: custA, targetUserName: 'Test Customer', targetUserRole: 'customer',
        }),
      }));
    });

    it('valid order_problem by Contractor succeeds', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...orderComplaintData(conUid, 'contractor', orderCustCon, {
          targetUserId: custA, targetUserName: 'Test Customer', targetUserRole: 'customer',
        }),
      }));
    });

    it('order_problem without an optional targetUserId still succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertSucceeds(setDoc(ref, { id: ref.id, ...orderComplaintData(custA, 'customer', orderCustPro) }));
    });

    it('unrelated user (not a participant of the order) fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, { id: ref.id, ...orderComplaintData(otherUid, 'customer', orderCustPro) }));
    });

    it('wrong order counterparty target fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...orderComplaintData(custA, 'customer', orderCustPro, { targetUserId: otherUid }),
      }));
    });

    it('nonexistent order fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...orderComplaintData(custA, 'customer', 'not_a_real_order'),
      }));
    });
  });

  // ── create: provider_report ───────────────────────────────────────────────
  describe('create — provider_report', () => {
    const custA = 'cx_prov_custA';
    const proUid = 'cx_prov_pro';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
      });
    });

    it('valid provider_report by Customer succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertSucceeds(setDoc(ref, { id: ref.id, ...providerReportData(custA, proUid) }));
    });

    it('provider_report by a non-customer role fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...providerReportData(proUid, custA, { complainantRole: 'professional' }),
      }));
    });

    it('provider_report targeting a Customer (not a provider) fails', async () => {
      const otherCust = 'cx_prov_other_cust';
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users', otherCust), customerData(otherCust));
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, { id: ref.id, ...providerReportData(custA, otherCust) }));
    });
  });

  // ── create: review_report ─────────────────────────────────────────────────
  describe('create — review_report', () => {
    const custA = 'cx_rev_custA';
    const proUid = 'cx_rev_pro';
    const conUid = 'cx_rev_con';
    const otherProUid = 'cx_rev_other_pro';
    let reviewForPro, reviewForCon, reviewForOtherPro;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', otherProUid), professionalData(otherProUid));
        reviewForPro = reviewDocId(custA, proUid);
        await setDoc(doc(db, 'reviews', reviewForPro), reviewData(custA, proUid, 'professional'));
        reviewForCon = reviewDocId(custA, conUid);
        await setDoc(doc(db, 'reviews', reviewForCon), reviewData(custA, conUid, 'contractor'));
        reviewForOtherPro = reviewDocId(custA, otherProUid);
        await setDoc(doc(db, 'reviews', reviewForOtherPro), reviewData(custA, otherProUid, 'professional'));
      });
    });

    it('valid review_report by Professional succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...reviewReportComplaintData(proUid, 'professional', reviewForPro, custA),
      }));
    });

    it('valid review_report by Contractor succeeds', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertSucceeds(setDoc(ref, {
        id: ref.id,
        ...reviewReportComplaintData(conUid, 'contractor', reviewForCon, custA),
      }));
    });

    it("review_report for another provider's review fails", async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...reviewReportComplaintData(proUid, 'professional', reviewForOtherPro, custA),
      }));
    });

    it('review_report targeting the wrong customer fails', async () => {
      const otherCust = 'cx_rev_other_cust';
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users', otherCust), customerData(otherCust));
      });
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...reviewReportComplaintData(proUid, 'professional', reviewForPro, otherCust),
      }));
    });
  });

  // ── create: general_complaint ─────────────────────────────────────────────
  describe('create — general_complaint', () => {
    const custA = 'cx_gen_custA';
    const proUid = 'cx_gen_pro';
    const conUid = 'cx_gen_con';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
      });
    });

    it('valid general_complaint by Customer succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertSucceeds(setDoc(ref, { id: ref.id, ...generalComplaintData(custA, 'customer') }));
    });

    it('valid general_complaint by Professional succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertSucceeds(setDoc(ref, { id: ref.id, ...generalComplaintData(proUid, 'professional') }));
    });

    it('valid general_complaint by Contractor succeeds', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertSucceeds(setDoc(ref, { id: ref.id, ...generalComplaintData(conUid, 'contractor') }));
    });

    it('general complaint containing a relatedOrderId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer'), relatedOrderId: 'some_order',
      }));
    });

    it('general complaint containing a targetUserId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer'), targetUserId: proUid,
      }));
    });
  });

  // ── create: common validation ─────────────────────────────────────────────
  describe('create — common validation', () => {
    const custA = 'cx_common_custA';
    const otherUid = 'cx_common_other';
    const adminUid = 'cx_common_admin';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
      });
    });

    it('spoofed complainantId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, { id: ref.id, ...generalComplaintData(otherUid, 'customer') }));
    });

    it('mismatched complainantRole fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer', { complainantRole: 'professional' }),
      }));
    });

    it('Admin cannot create a complaint (admin is not a supported complainant role)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(adminUid, 'admin'),
      }));
    });

    it('customer_report type fails (no real create path)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer', { type: 'customer_report' }),
      }));
    });

    it('service_problem type fails (no real create path)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer', { type: 'service_problem' }),
      }));
    });

    it('unknown type fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer', { type: 'not_a_real_type' }),
      }));
    });

    it('non-open initial status fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer', { status: 'resolved' }),
      }));
    });

    it('non-medium initial priority fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer', { priority: 'urgent' }),
      }));
    });

    it('isDeleted true at creation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer', { isDeleted: true }),
      }));
    });

    it('adminNote present at creation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer'), adminNote: 'pre-seeded',
      }));
    });

    it('replyText/repliedBy present at creation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer'),
        replyText: 'hi', repliedBy: 'System Admin',
      }));
    });

    it('title != reason fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      const data = generalComplaintData(custA, 'customer');
      data.title = 'Different title';
      await assertFails(setDoc(ref, { id: ref.id, ...data }));
    });

    it('wrong id field fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, { id: 'not_the_real_id', ...generalComplaintData(custA, 'customer') }));
    });

    it('unknown field fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'complaints'));
      await assertFails(setDoc(ref, {
        id: ref.id, ...generalComplaintData(custA, 'customer'), extraField: 'nope',
      }));
    });
  });

  // ── requester updates ──────────────────────────────────────────────────────
  describe('requester updates', () => {
    const custA = 'cx_req_custA';
    const otherUid = 'cx_req_other';
    let complaintId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        const ref = doc(collection(db, 'complaints'));
        complaintId = ref.id;
        await setDoc(ref, { id: complaintId, ...generalComplaintData(custA, 'customer') });
      });
    });

    it('owner edit succeeds while open', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        reason: 'Updated reason', title: 'Updated reason', description: 'Updated description.',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('owner edit succeeds while in_review', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'complaints', complaintId), { status: 'in_review' });
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        reason: 'Updated again', title: 'Updated again', updatedAt: new Date().toISOString(),
      }));
    });

    it('owner edit fails once resolved', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'complaints', complaintId), { status: 'resolved' });
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        reason: 'Too late', title: 'Too late', updatedAt: new Date().toISOString(),
      }));
    });

    it('owner edit fails once rejected', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'complaints', complaintId), { status: 'rejected' });
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        reason: 'Too late', title: 'Too late', updatedAt: new Date().toISOString(),
      }));
    });

    it('owner edit fails once deleted', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'complaints', complaintId), { status: 'deleted', isDeleted: true });
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        reason: 'Too late', title: 'Too late', updatedAt: new Date().toISOString(),
      }));
    });

    it('edit with title != reason fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        reason: 'Reason A', title: 'Reason B', updatedAt: new Date().toISOString(),
      }));
    });

    it('another user cannot edit someone else\'s complaint', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        reason: 'Hijacked', title: 'Hijacked', updatedAt: new Date().toISOString(),
      }));
    });

    it('owner soft-delete succeeds while open', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'deleted', isDeleted: true, updatedAt: new Date().toISOString(),
      }));
    });

    it('owner soft-delete succeeds while in_review', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'complaints', complaintId), { status: 'in_review' });
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'deleted', isDeleted: true, updatedAt: new Date().toISOString(),
      }));
    });

    it('owner soft-delete fails once resolved', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'complaints', complaintId), { status: 'resolved' });
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'deleted', isDeleted: true, updatedAt: new Date().toISOString(),
      }));
    });

    it('owner soft-delete fails once rejected', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'complaints', complaintId), { status: 'rejected' });
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'deleted', isDeleted: true, updatedAt: new Date().toISOString(),
      }));
    });

    it('owner cannot inject adminNote via their edit', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        reason: 'Updated', title: 'Updated', adminNote: 'sneaky', updatedAt: new Date().toISOString(),
      }));
    });

    it('owner cannot change identity fields (type/priority) via their edit', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        reason: 'Updated', title: 'Updated', priority: 'urgent', updatedAt: new Date().toISOString(),
      }));
    });
  });

  // ── admin updates ───────────────────────────────────────────────────────────
  describe('admin updates', () => {
    const custA = 'cx_admin_custA';
    const adminUid = 'cx_admin_admin';
    let complaintId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        const ref = doc(collection(db, 'complaints'));
        complaintId = ref.id;
        await setDoc(ref, { id: complaintId, ...generalComplaintData(custA, 'customer') });
      });
    });

    it('open -> in_review succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'in_review', updatedAt: new Date().toISOString(),
      }));
    });

    it('open -> resolved succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'resolved', resolvedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('in_review -> resolved succeeds', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'complaints', complaintId), { status: 'in_review' });
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'resolved', resolvedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('open -> rejected succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'rejected', updatedAt: new Date().toISOString(),
      }));
    });

    it('in_review -> rejected succeeds', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'complaints', complaintId), { status: 'in_review' });
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'rejected', updatedAt: new Date().toISOString(),
      }));
    });

    it('note-only same-status update succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'open', adminNote: 'Looking into this.', updatedAt: new Date().toISOString(),
      }));
    });

    it('resolved -> open fails', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'complaints', complaintId), {
          status: 'resolved', resolvedAt: new Date().toISOString(),
        });
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'open', updatedAt: new Date().toISOString(),
      }));
    });

    it('resolvedAt can only change when the resulting status is resolved', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'rejected', resolvedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('an existing resolvedAt value is safely preserved across a later transition', async () => {
      const resolvedAt = new Date().toISOString();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'complaints', complaintId), {
          status: 'resolved', resolvedAt,
        });
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'rejected', updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin reply succeeds with the exact real field shape', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        replyText: 'We are looking into this.',
        repliedAt: new Date().toISOString(),
        repliedBy: 'System Admin',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin reply with the wrong repliedBy value fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        replyText: 'We are looking into this.',
        repliedAt: new Date().toISOString(),
        repliedBy: adminUid,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin internal note succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        adminNote: 'Internal note only.', updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin soft delete succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'deleted', isDeleted: true, updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin cannot change identity fields (complainantId/type)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'in_review', complainantId: 'someone_else', updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin cannot change related fields (targetId)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'in_review', targetId: 'someone_else', updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin cannot change priority (no real path calls updateComplaintPriorityInFirestore)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        priority: 'urgent', updatedAt: new Date().toISOString(),
      }));
    });

    it('non-Admin cannot perform an Admin-shaped status update', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        status: 'resolved', updatedAt: new Date().toISOString(),
      }));
    });
  });

  // ── delete ──────────────────────────────────────────────────────────────────
  describe('delete', () => {
    const custA = 'cx_delete_custA';
    const adminUid = 'cx_delete_admin';
    let complaintId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        const ref = doc(collection(db, 'complaints'));
        complaintId = ref.id;
        await setDoc(ref, { id: complaintId, ...generalComplaintData(custA, 'customer') });
      });
    });

    it('owner physical delete fails (no real delete path exists)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(deleteDoc(doc(db, 'complaints', complaintId)));
    });

    it('Admin physical delete fails (no real delete path exists)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(deleteDoc(doc(db, 'complaints', complaintId)));
    });
  });

  // ── legacy documents ────────────────────────────────────────────────────────
  describe('legacy documents (userId/userName only)', () => {
    const custA = 'cx_legacy_custA';
    const adminUid = 'cx_legacy_admin';
    let legacyId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        const ref = doc(collection(db, 'complaints'));
        legacyId = ref.id;
        // Simulates a pre-Phase-5B document using the legacy field names
        // (userId/userName) instead of complainantId/complainantName —
        // proven possible by ComplaintModel.fromFirestore's fallback.
        await setDoc(ref, {
          id: legacyId,
          userId: custA,
          userName: 'Legacy Customer',
          type: 'general_complaint',
          reason: 'Legacy complaint',
          description: 'Filed before Phase 5B.',
          status: 'open',
          priority: 'medium',
          createdAt: new Date().toISOString(),
          isDeleted: false,
        });
      });
    });

    it('Admin can still read a legacy userId/userName-only complaint', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'complaints', legacyId)));
    });

    // Documented limitation, not a bug: the real owner query/rule is keyed
    // on complainantId specifically (per Phase 5A — this is the current,
    // proven field name), so a legacy document that only ever stored the
    // old userId field is not retrievable by its own filer through either
    // the where('complainantId', ...) query or a direct read — only Admin
    // (whose read branch is independent of resource.data) can still reach
    // it. Rules are intentionally not widened to also match on userId,
    // since no real current query proves that fallback is needed.
    it('the original filer cannot read their own legacy userId-only complaint (documented limitation)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(getDoc(doc(db, 'complaints', legacyId)));
    });
  });

  // ── failed writes leave the complaint unchanged ────────────────────────────
  describe('failed writes leave the complaint unchanged', () => {
    const custA = 'cx_noop_custA';
    const otherUid = 'cx_noop_other';
    let complaintId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        const ref = doc(collection(db, 'complaints'));
        complaintId = ref.id;
        await setDoc(ref, { id: complaintId, ...generalComplaintData(custA, 'customer') });
      });
    });

    it('a rejected cross-user edit leaves the complaint unchanged', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(updateDoc(doc(db, 'complaints', complaintId), {
        reason: 'Hijacked', title: 'Hijacked', updatedAt: new Date().toISOString(),
      }));
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const snap = await getDoc(doc(ctx.firestore(), 'complaints', complaintId));
        if (snap.data().reason === 'Hijacked') {
          throw new Error('complaint reason was mutated despite the rejected write');
        }
      });
    });
  });
});
