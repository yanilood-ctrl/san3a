'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  customerData, professionalData, contractorData, adminData,
  conversationDocId, conversationData, textMessageData, chatReportData,
} = require('./fixtures');

describe('chat_reports/{reportId} security rules', function () {
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
    const custA = 'cr_read_custA';
    const proUid = 'cr_read_pro';
    const otherUid = 'cr_read_other';
    const adminUid = 'cr_read_admin';
    const convId = conversationDocId(custA, proUid);
    const reportId = 'cr_read_report';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
        await setDoc(doc(db, 'chat_reports', reportId),
          chatReportData(convId, custA, 'customer', { id: reportId }));
      });
    });

    it('owner single read succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(db, 'chat_reports', reportId)));
    });

    it("owner's real where('reporterId', isEqualTo: uid) query succeeds", async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'chat_reports'), where('reporterId', '==', custA));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 1) throw new Error(`Expected 1 report, got ${snap.size}`);
    });

    it('another user single read fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(getDoc(doc(db, 'chat_reports', reportId)));
    });

    it('unauthenticated read fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'chat_reports', reportId)));
    });

    it('non-Admin unfiltered collection query fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(getDocs(collection(db, 'chat_reports')));
    });

    it('non-Admin filtered query on someone else\'s reporterId fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      const q = query(collection(db, 'chat_reports'), where('reporterId', '==', custA));
      await assertFails(getDocs(q));
    });

    it('Admin single read succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'chat_reports', reportId)));
    });

    it('Admin unfiltered collection query succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const snap = await assertSucceeds(getDocs(collection(db, 'chat_reports')));
      if (snap.size !== 1) throw new Error(`Expected 1 report for Admin, got ${snap.size}`);
    });
  });

  // ── create ──────────────────────────────────────────────────────────────
  describe('create', () => {
    const custA = 'cr_create_custA';
    const proUid = 'cr_create_pro';
    const conUid = 'cr_create_con';
    const otherUid = 'cr_create_other';
    const adminUid = 'cr_create_admin';
    const convCustPro = conversationDocId(custA, proUid);
    const convCustCon = conversationDocId(custA, conUid);
    let messageId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'conversations', convCustPro),
          conversationData(custA, proUid, 'professional'));
        await setDoc(doc(db, 'conversations', convCustCon),
          conversationData(custA, conUid, 'contractor'));
        const msgRef = doc(collection(db, 'conversations', convCustPro, 'messages'));
        messageId = msgRef.id;
        await setDoc(msgRef, { id: messageId, ...textMessageData(convCustPro, custA, proUid) });
      });
    });

    it('valid Customer report creation succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertSucceeds(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: ref.id,
        reportedUserId: proUid,
        reportedUserName: 'Test Provider',
        reportedUserRole: 'professional',
      })));
    });

    it('valid Professional report creation succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertSucceeds(setDoc(ref, chatReportData(convCustPro, proUid, 'professional', {
        id: ref.id,
        reportedUserId: custA,
        reportedUserName: 'Test Customer',
        reportedUserRole: 'customer',
      })));
    });

    it('valid Contractor report creation succeeds', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertSucceeds(setDoc(ref, chatReportData(convCustCon, conUid, 'contractor', {
        id: ref.id,
        reportedUserId: custA,
        reportedUserName: 'Test Customer',
        reportedUserRole: 'customer',
      })));
    });

    it('report creation without reportedUserId/messageId (minimal real shape) succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertSucceeds(setDoc(ref, chatReportData(convCustPro, custA, 'customer', { id: ref.id })));
    });

    it('report creation referencing a real message in the conversation succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertSucceeds(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: ref.id, messageId,
      })));
    });

    it('spoofed reporterId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, proUid, 'professional', { id: ref.id })));
    });

    it('mismatched reporterRole (does not match stored account role) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, custA, 'professional', { id: ref.id })));
    });

    it('Admin role is not a supported reporterRole for creation', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, adminUid, 'admin', { id: ref.id })));
    });

    it('non-participant reporting a conversation they are not part of fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, otherUid, 'customer', { id: ref.id })));
    });

    it('report against a non-existent conversation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref,
        chatReportData('not_a_real_conversation', custA, 'customer', { id: ref.id })));
    });

    it('reportedUserId not a participant of the conversation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: ref.id, reportedUserId: otherUid,
      })));
    });

    it('reportedUserId equal to the reporter (self-report) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: ref.id, reportedUserId: custA,
      })));
    });

    it('messageId not belonging to the conversation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: ref.id, messageId: 'not_a_real_message',
      })));
    });

    it('invalid initial status (not open) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: ref.id, status: 'resolved',
      })));
    });

    it('invalid reason (not one of the 4 real values) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: ref.id, reason: 'Something else entirely',
      })));
    });

    it('privileged adminNote field at creation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: ref.id, adminNote: 'pre-seeded note',
      })));
    });

    it('isSeenByAdmin true at creation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: ref.id, isSeenByAdmin: true,
      })));
    });

    it('non-medium priority at creation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: ref.id, priority: 'high',
      })));
    });

    it('unknown field at creation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: ref.id, extraField: 'nope',
      })));
    });

    it('wrong id field fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'chat_reports'));
      await assertFails(setDoc(ref, chatReportData(convCustPro, custA, 'customer', {
        id: 'not_the_real_id',
      })));
    });
  });

  // ── update ──────────────────────────────────────────────────────────────
  describe('update', () => {
    const custA = 'cr_update_custA';
    const proUid = 'cr_update_pro';
    const otherUid = 'cr_update_other';
    const adminUid = 'cr_update_admin';
    const convId = conversationDocId(custA, proUid);
    const reportId = 'cr_update_report';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
        await setDoc(doc(db, 'chat_reports', reportId),
          chatReportData(convId, custA, 'customer', { id: reportId }));
      });
    });

    it('requester edit (reason/description) while open succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'chat_reports', reportId), {
        reason: 'Edit a Message',
        description: 'More detail about the issue.',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('requester edit fails once the report is no longer open', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'chat_reports', reportId),
          { status: 'in_review' });
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'chat_reports', reportId), {
        reason: 'Other Issue',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('requester edit with an invalid reason fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'chat_reports', reportId), {
        reason: 'Not a real reason',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('an unrelated user cannot update the report', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(updateDoc(doc(db, 'chat_reports', reportId), {
        reason: 'Other Issue',
        updatedAt: new Date().toISOString(),
      }));
    });

    // ── requester self-reject ("Delete Request" — moves to Rejected) ──────
    it('requester self-reject (open -> rejected) succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'chat_reports', reportId), {
        status: 'rejected',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('requester self-reject fails once the report is no longer open', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'chat_reports', reportId),
          { status: 'in_review' });
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'chat_reports', reportId), {
        status: 'rejected',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('requester self-transition to a status other than rejected fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'chat_reports', reportId), {
        status: 'resolved',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('requester self-reject combined with another field change fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'chat_reports', reportId), {
        status: 'rejected',
        reason: 'Other Issue',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('an unrelated user cannot self-reject someone else\'s report', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(updateDoc(doc(db, 'chat_reports', reportId), {
        status: 'rejected',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin valid status update succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'chat_reports', reportId), {
        status: 'in_review',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin note-only save (same status) succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'chat_reports', reportId), {
        status: 'open',
        adminNote: 'Looking into this.',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin setting status back to "open" (not a real transition target) fails', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'chat_reports', reportId),
          { status: 'in_review' });
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'chat_reports', reportId), {
        status: 'open',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin setting an invalid status value fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'chat_reports', reportId), {
        status: 'archived',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin cannot rewrite identity fields (conversationId/reporterId/createdAt)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'chat_reports', reportId), {
        status: 'in_review',
        reporterId: otherUid,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin mark-seen succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'chat_reports', reportId), {
        isSeenByAdmin: true,
      }));
    });

    it('non-Admin cannot mark a report as seen', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'chat_reports', reportId), {
        isSeenByAdmin: true,
      }));
    });
  });

  // ── delete ──────────────────────────────────────────────────────────────
  describe('delete', () => {
    const custA = 'cr_delete_custA';
    const adminUid = 'cr_delete_admin';
    const convId = conversationDocId(custA, 'cr_delete_pro');
    const reportId = 'cr_delete_report';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'chat_reports', reportId),
          chatReportData(convId, custA, 'customer', { id: reportId }));
      });
    });

    it('owner delete fails (no real delete path exists)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(deleteDoc(doc(db, 'chat_reports', reportId)));
    });

    it('Admin delete fails (no real delete path exists)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(deleteDoc(doc(db, 'chat_reports', reportId)));
    });
  });

  // ── recursive wildcard regression ──────────────────────────────────────
  describe('recursive wildcard regression (post wildcard removal)', () => {
    const custA = 'cr_wc_custA';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users', custA), customerData(custA));
      });
    });

    it('a fabricated nested path ending in /chat_reports/{id} denies create', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'conversations', 'some_conv', 'chat_reports'));
      await assertFails(setDoc(ref,
        chatReportData('some_conv', custA, 'customer', { id: ref.id })));
    });

    it('a fabricated nested path ending in /chat_reports/{id} denies update', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const ref = doc(ctx.firestore(), 'conversations', 'some_conv', 'chat_reports', 'nested_report');
        await setDoc(ref, chatReportData('some_conv', custA, 'customer', { id: 'nested_report' }));
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', 'some_conv', 'chat_reports', 'nested_report'),
        { reason: 'Other Issue', updatedAt: new Date().toISOString() }));
    });
  });
});
