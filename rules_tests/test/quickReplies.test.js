'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, setDoc, updateDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  customerData, professionalData, contractorData, adminData, quickReplyData,
} = require('./fixtures');

describe('quick_replies/{replyId} security rules', function () {
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
    const custUid = 'qr_read_cust';
    const proUid = 'qr_read_pro';
    const conUid = 'qr_read_con';
    const adminUid = 'qr_read_admin';
    const activeId = 'qr_read_active';
    const inactiveId = 'qr_read_inactive';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custUid), customerData(custUid));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'quick_replies', activeId),
          quickReplyData({ id: activeId }));
        await setDoc(doc(db, 'quick_replies', inactiveId),
          quickReplyData({ id: inactiveId, isActive: false }));
      });
    });

    it('Customer unfiltered collection read succeeds (client filters isActive/role itself)', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      const snap = await assertSucceeds(getDocs(collection(db, 'quick_replies')));
      if (snap.size !== 2) throw new Error(`Expected 2 docs for Customer, got ${snap.size}`);
    });

    it('Professional read succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(getDocs(collection(db, 'quick_replies')));
    });

    it('Contractor read succeeds', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      await assertSucceeds(getDocs(collection(db, 'quick_replies')));
    });

    it('Admin read succeeds and includes inactive replies', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const snap = await assertSucceeds(getDocs(collection(db, 'quick_replies')));
      if (snap.size !== 2) throw new Error(`Expected 2 docs for Admin, got ${snap.size}`);
    });

    it('single-document read succeeds for any signed-in role', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'quick_replies', activeId)));
    });

    it('unauthenticated read fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDocs(collection(db, 'quick_replies')));
    });
  });

  // ── create ──────────────────────────────────────────────────────────────
  describe('create', () => {
    const custUid = 'qr_create_cust';
    const proUid = 'qr_create_pro';
    const conUid = 'qr_create_con';
    const adminUid = 'qr_create_admin';
    const otherAdminUid = 'qr_create_other_admin';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custUid), customerData(custUid));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'users', otherAdminUid), adminData(otherAdminUid));
      });
    });

    it('Admin valid create succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'quick_replies'));
      await assertSucceeds(setDoc(ref,
        quickReplyData({ id: ref.id, createdBy: adminUid })));
    });

    it('Admin valid create without createdBy succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'quick_replies'));
      await assertSucceeds(setDoc(ref, quickReplyData({ id: ref.id })));
    });

    it('Customer cannot create a quick reply', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      const ref = doc(collection(db, 'quick_replies'));
      await assertFails(setDoc(ref, quickReplyData({ id: ref.id })));
    });

    it('Professional cannot create a quick reply', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'quick_replies'));
      await assertFails(setDoc(ref, quickReplyData({ id: ref.id })));
    });

    it('Contractor cannot create a quick reply', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      const ref = doc(collection(db, 'quick_replies'));
      await assertFails(setDoc(ref, quickReplyData({ id: ref.id })));
    });

    it('spoofed createdBy (another admin\'s uid) fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'quick_replies'));
      await assertFails(setDoc(ref,
        quickReplyData({ id: ref.id, createdBy: otherAdminUid })));
    });

    it('wrong id field fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'quick_replies'));
      await assertFails(setDoc(ref, quickReplyData({ id: 'not_the_real_id' })));
    });

    it('isActive false at create fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'quick_replies'));
      await assertFails(setDoc(ref,
        quickReplyData({ id: ref.id, isActive: false })));
    });

    it('empty text at create fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'quick_replies'));
      await assertFails(setDoc(ref, quickReplyData({ id: ref.id, text: '' })));
    });

    it('unknown field at create fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'quick_replies'));
      await assertFails(setDoc(ref,
        quickReplyData({ id: ref.id, sortOrder: 1 })));
    });
  });

  // ── update ──────────────────────────────────────────────────────────────
  describe('update', () => {
    const custUid = 'qr_update_cust';
    const adminUid = 'qr_update_admin';
    const replyId = 'qr_update_reply';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custUid), customerData(custUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'quick_replies', replyId),
          quickReplyData({ id: replyId, createdBy: adminUid }));
      });
    });

    it('Admin text edit succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'quick_replies', replyId), {
        text: 'Updated reply text',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin deactivate (soft delete) succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'quick_replies', replyId), {
        isActive: false,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin reactivate succeeds', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'quick_replies', replyId),
          { isActive: false });
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'quick_replies', replyId), {
        isActive: true,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Customer cannot update a quick reply', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      await assertFails(updateDoc(doc(db, 'quick_replies', replyId), {
        text: 'hijacked',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin cannot rewrite createdAt', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'quick_replies', replyId), {
        text: 'Updated text',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin cannot rewrite createdBy', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'quick_replies', replyId), {
        createdBy: custUid,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin cannot write an unknown field', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'quick_replies', replyId), {
        sortOrder: 3,
        updatedAt: new Date().toISOString(),
      }));
    });
  });

  // ── delete ──────────────────────────────────────────────────────────────
  describe('delete', () => {
    const adminUid = 'qr_delete_admin';
    const replyId = 'qr_delete_reply';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'quick_replies', replyId), quickReplyData({ id: replyId }));
      });
    });

    it('Admin physical delete fails (no real delete path exists)', async () => {
      const { deleteDoc } = require('firebase/firestore');
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(deleteDoc(doc(db, 'quick_replies', replyId)));
    });
  });

  // ── legacy compatibility ────────────────────────────────────────────────
  describe('legacy compatibility', () => {
    const adminUid = 'qr_legacy_admin';
    const replyId = 'qr_legacy_reply';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        // Legacy doc: no isActive/roles/createdBy at all — mirrors
        // QuickReplyModel.fromMap's tolerant fallbacks (isActive defaults to
        // true, roles defaults to []) for documents written before those
        // fields existed.
        const legacy = quickReplyData({ id: replyId });
        delete legacy.isActive;
        delete legacy.roles;
        await setDoc(doc(db, 'quick_replies', replyId), legacy);
      });
    });

    it('a legacy document missing isActive/roles can still be read', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'quick_replies', replyId)));
    });

    it('Admin can still edit a legacy document missing isActive/roles', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'quick_replies', replyId), {
        text: 'Edited legacy reply',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin can still set isActive on a legacy document that never had it', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'quick_replies', replyId), {
        isActive: false,
        updatedAt: new Date().toISOString(),
      }));
    });
  });

  // ── recursive wildcard regression ──────────────────────────────────────
  describe('recursive wildcard regression (post wildcard removal)', () => {
    const custUid = 'qr_wc_cust';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users', custUid), customerData(custUid));
      });
    });

    it('a non-Admin cannot create via a nested quick_replies path that the old wildcard used to allow', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      const ref = doc(collection(db, 'conversations', 'some_conv', 'quick_replies'));
      await assertFails(setDoc(ref, quickReplyData({ id: ref.id })));
    });

    it('a non-Admin cannot update via a nested quick_replies path that the old wildcard used to allow', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const ref = doc(ctx.firestore(), 'conversations', 'some_conv', 'quick_replies', 'nested_reply');
        await setDoc(ref, quickReplyData({ id: 'nested_reply' }));
      });
      const db = testEnv.authenticatedContext(custUid).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', 'some_conv', 'quick_replies', 'nested_reply'),
        { text: 'hijacked', updatedAt: new Date().toISOString() }));
    });
  });
});
