'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  customerData, professionalData, contractorData, adminData,
  conversationDocId, conversationData, adminWarningMessageData,
} = require('./fixtures');

describe('conversations/{conversationId}/adminWarnings/{warningId} security rules', function () {
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
    const custA = 'aw_read_custA';
    const proUid = 'aw_read_pro';
    const conUid = 'aw_read_con';
    const otherUid = 'aw_read_other';
    const adminUid = 'aw_read_admin';
    const convCustPro = conversationDocId(custA, proUid);
    const convCustCon = conversationDocId(custA, conUid);
    let warningTargetingCustId;
    let warningTargetingProId;
    let warningTargetingConId;

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

        const custRef = doc(collection(db, 'conversations', convCustPro, 'adminWarnings'));
        warningTargetingCustId = custRef.id;
        await setDoc(custRef,
          { id: warningTargetingCustId, ...adminWarningMessageData(convCustPro, adminUid, [custA]) });

        const proRef = doc(collection(db, 'conversations', convCustPro, 'adminWarnings'));
        warningTargetingProId = proRef.id;
        await setDoc(proRef,
          { id: warningTargetingProId, ...adminWarningMessageData(convCustPro, adminUid, [proUid]) });

        const conRef = doc(collection(db, 'conversations', convCustCon, 'adminWarnings'));
        warningTargetingConId = conRef.id;
        await setDoc(conRef,
          { id: warningTargetingConId, ...adminWarningMessageData(convCustCon, adminUid, [conUid]) });
      });
    });

    it('targeted Customer direct read succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(
        getDoc(doc(db, 'conversations', convCustPro, 'adminWarnings', warningTargetingCustId)));
    });

    it('targeted Professional direct read succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(
        getDoc(doc(db, 'conversations', convCustPro, 'adminWarnings', warningTargetingProId)));
    });

    it('targeted Contractor direct read succeeds', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      await assertSucceeds(
        getDoc(doc(db, 'conversations', convCustCon, 'adminWarnings', warningTargetingConId)));
    });

    it("the target's real where('targetUserIds', arrayContains: uid) query succeeds", async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'conversations', convCustPro, 'adminWarnings'),
        where('targetUserIds', 'array-contains', custA));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 1) throw new Error(`Expected 1 warning, got ${snap.size}`);
    });

    it('untargeted participant direct read fails', async () => {
      // proUid is a real participant of convCustPro but is not targeted by
      // warningTargetingCustId.
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(
        getDoc(doc(db, 'conversations', convCustPro, 'adminWarnings', warningTargetingCustId)));
    });

    it('untargeted participant unfiltered query fails (not provable)', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(getDocs(collection(db, 'conversations', convCustPro, 'adminWarnings')));
    });

    it("untargeted participant's incorrectly-filtered query (someone else's uid) fails", async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const q = query(collection(db, 'conversations', convCustPro, 'adminWarnings'),
        where('targetUserIds', 'array-contains', custA));
      await assertFails(getDocs(q));
    });

    it('a non-participant, non-target authenticated user cannot read', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(
        getDoc(doc(db, 'conversations', convCustPro, 'adminWarnings', warningTargetingCustId)));
    });

    it('unauthenticated read fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(
        getDoc(doc(db, 'conversations', convCustPro, 'adminWarnings', warningTargetingCustId)));
    });

    it('Admin unfiltered query succeeds and includes every warning', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const snap = await assertSucceeds(
        getDocs(collection(db, 'conversations', convCustPro, 'adminWarnings')));
      if (snap.size !== 2) throw new Error(`Expected 2 warnings for admin, got ${snap.size}`);
    });

    it('Admin single-document read succeeds regardless of target', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(
        getDoc(doc(db, 'conversations', convCustPro, 'adminWarnings', warningTargetingProId)));
    });
  });

  // ── create ──────────────────────────────────────────────────────────────
  describe('create', () => {
    const custA = 'aw_create_custA';
    const proUid = 'aw_create_pro';
    const otherUid = 'aw_create_other';
    const adminUid = 'aw_create_admin';
    const convId = conversationDocId(custA, proUid);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
      });
    });

    it('Admin creates a warning for one participant succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertSucceeds(setDoc(ref,
        { id: ref.id, ...adminWarningMessageData(convId, adminUid, [custA]) }));
    });

    it('Admin creates a warning for both participants succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertSucceeds(setDoc(ref,
        { id: ref.id, ...adminWarningMessageData(convId, adminUid, [custA, proUid]) }));
    });

    it('warning creation succeeds while the conversation is blocked', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations', convId), { isBlocked: true });
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertSucceeds(setDoc(ref,
        { id: ref.id, ...adminWarningMessageData(convId, adminUid, [proUid]) }));
    });

    it('non-Admin create fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref,
        { id: ref.id, ...adminWarningMessageData(convId, custA, [proUid]) }));
    });

    it('target UID outside participantIds fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref,
        { id: ref.id, ...adminWarningMessageData(convId, adminUid, [otherUid]) }));
    });

    it('empty targetUserIds fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref,
        { id: ref.id, ...adminWarningMessageData(convId, adminUid, []) }));
    });

    it('more than 2 targets fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref,
        { id: ref.id, ...adminWarningMessageData(convId, adminUid, [custA, proUid, otherUid]) }));
    });

    it('duplicate uid repeated twice in targetUserIds fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref,
        { id: ref.id, ...adminWarningMessageData(convId, adminUid, [custA, custA]) }));
    });

    it('wrong conversationId field fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...adminWarningMessageData(convId, adminUid, [custA], { conversationId: 'not_the_real_id' }),
      }));
    });

    it('wrong id field fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref,
        { id: 'not_the_real_id', ...adminWarningMessageData(convId, adminUid, [custA]) }));
    });

    it('wrong type field fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...adminWarningMessageData(convId, adminUid, [custA], { type: 'text' }),
      }));
    });

    it('spoofed senderId (not the calling admin) fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...adminWarningMessageData(convId, adminUid, [custA], { senderId: 'someone_else' }),
      }));
    });

    it('non-empty receiverId fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...adminWarningMessageData(convId, adminUid, [custA], { receiverId: custA }),
      }));
    });

    it('empty text fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...adminWarningMessageData(convId, adminUid, [custA], { text: '' }),
      }));
    });

    it('privileged field (isSeenByAdmin-style) at creation fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...adminWarningMessageData(convId, adminUid, [custA]),
        deletedBy: adminUid,
      }));
    });

    it('unknown field at creation fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...adminWarningMessageData(convId, adminUid, [custA]),
        extraField: 'nope',
      }));
    });

    it('isRead true at creation fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...adminWarningMessageData(convId, adminUid, [custA], { isRead: true }),
      }));
    });

    it('warning against a non-existent conversation fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'conversations', 'not_a_real_conversation', 'adminWarnings'));
      await assertFails(setDoc(ref, {
        id: ref.id,
        ...adminWarningMessageData('not_a_real_conversation', adminUid, [custA]),
      }));
    });
  });

  // ── update (admin hide) ────────────────────────────────────────────────
  describe('update — admin hide', () => {
    const custA = 'aw_hide_custA';
    const proUid = 'aw_hide_pro';
    const adminUid = 'aw_hide_admin';
    const convId = conversationDocId(custA, proUid);
    let warningId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
        const ref = doc(collection(db, 'conversations', convId, 'adminWarnings'));
        warningId = ref.id;
        await setDoc(ref, { id: warningId, ...adminWarningMessageData(convId, adminUid, [custA]) });
      });
    });

    it('Admin hide succeeds with the exact real field shape', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'conversations', convId, 'adminWarnings', warningId), {
          isDeleted: true,
          text: '',
          deletedBy: adminUid,
          deletedByName: 'Test Admin',
          deletedByRole: 'admin',
          adminDeleted: true,
          deletedAt: new Date().toISOString(),
        }));
    });

    it('non-Admin hide fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'adminWarnings', warningId), {
          isDeleted: true,
          text: '',
          deletedBy: custA,
          deletedByRole: 'admin',
          adminDeleted: true,
          deletedAt: new Date().toISOString(),
        }));
    });

    it('identity/target fields cannot change during hide', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'adminWarnings', warningId), {
          isDeleted: true,
          text: '',
          deletedBy: adminUid,
          deletedByRole: 'admin',
          adminDeleted: true,
          deletedAt: new Date().toISOString(),
          targetUserIds: [proUid],
        }));
    });

    it('senderId cannot change during hide', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'adminWarnings', warningId), {
          isDeleted: true,
          text: '',
          deletedBy: adminUid,
          deletedByRole: 'admin',
          adminDeleted: true,
          senderId: custA,
        }));
    });

    it('physical delete fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(
        deleteDoc(doc(db, 'conversations', convId, 'adminWarnings', warningId)));
    });

    it('Admin cannot "unhide" a hidden warning', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations', convId, 'adminWarnings', warningId), {
          isDeleted: true, text: '', deletedBy: adminUid, deletedByRole: 'admin', adminDeleted: true,
        });
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'adminWarnings', warningId), {
          isDeleted: false,
        }));
    });
  });
});
