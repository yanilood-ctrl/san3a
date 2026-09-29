'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, collectionGroup, query, where, setDoc,
  updateDoc, writeBatch,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  customerData, professionalData, contractorData, adminData,
  conversationDocId, conversationData,
  textMessageData, imageMessageData, voiceMessageData, adminWarningMessageData,
} = require('./fixtures');

describe('conversations/{conversationId} and nested messages security rules', function () {
  this.timeout(20000);
  let testEnv;

  before(async () => {
    testEnv = await getTestEnv();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  // ── conversations: reads ──────────────────────────────────────────────────
  describe('conversations reads', () => {
    const custA = 'conv_read_custA';
    const proUid = 'conv_read_pro';
    const otherUid = 'conv_read_other';
    const adminUid = 'conv_read_admin';
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

    it('participant (customer) single read succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(db, 'conversations', convId)));
    });

    it('participant (provider) single read succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'conversations', convId)));
    });

    it("participant's real where('participantIds', arrayContains: uid) query succeeds", async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'conversations'),
        where('participantIds', 'array-contains', custA));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 1) throw new Error(`Expected 1 conversation, got ${snap.size}`);
    });

    it('unrelated authenticated user read fails', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(getDoc(doc(db, 'conversations', convId)));
    });

    it('unauthenticated read fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'conversations', convId)));
    });

    it('Admin single read succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'conversations', convId)));
    });

    it('Admin unfiltered collection query succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const snap = await assertSucceeds(getDocs(collection(db, 'conversations')));
      if (snap.size !== 1) throw new Error(`Expected 1 conversation for admin, got ${snap.size}`);
    });
  });

  // ── conversations: create ─────────────────────────────────────────────────
  describe('conversations create', () => {
    const custA = 'conv_create_custA';
    const proUid = 'conv_create_pro';
    const conUid = 'conv_create_con';
    const custB = 'conv_create_custB';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
      });
    });

    it('Customer<->Professional conversation create succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = conversationDocId(custA, proUid);
      await assertSucceeds(setDoc(doc(db, 'conversations', id),
        conversationData(custA, proUid, 'professional')));
    });

    it('Customer<->Contractor conversation create succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = conversationDocId(custA, conUid);
      await assertSucceeds(setDoc(doc(db, 'conversations', id),
        conversationData(custA, conUid, 'contractor')));
    });

    it('reversed deterministic id order (participantIds[1]_participantIds[0]) succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      // Force the "other" acceptable ordering instead of the sorted one.
      const reversedId = `${proUid}_${custA}`;
      await assertSucceeds(setDoc(doc(db, 'conversations', reversedId),
        conversationData(custA, proUid, 'professional', { id: reversedId })));
    });

    it('invalid role pairing (customer<->customer) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = conversationDocId(custA, custB);
      await assertFails(setDoc(doc(db, 'conversations', id),
        conversationData(custA, custB, 'customer')));
    });

    it('spoofed participant (creator not in participantIds) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = conversationDocId(custB, proUid);
      await assertFails(setDoc(doc(db, 'conversations', id),
        conversationData(custB, proUid, 'professional')));
    });

    it('wrong (non-deterministic) conversation id fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(doc(db, 'conversations', 'totally_wrong_id'),
        conversationData(custA, proUid, 'professional', { id: 'totally_wrong_id' })));
    });

    it('participantRoles not matching stored roles fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = conversationDocId(custA, proUid);
      await assertFails(setDoc(doc(db, 'conversations', id),
        conversationData(custA, proUid, 'professional', {
          participantRoles: { [custA]: 'customer', [proUid]: 'contractor' },
        })));
    });

    it('isBlocked true at create fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = conversationDocId(custA, proUid);
      await assertFails(setDoc(doc(db, 'conversations', id),
        conversationData(custA, proUid, 'professional', { isBlocked: true })));
    });

    it('privileged admin block field at create fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = conversationDocId(custA, proUid);
      await assertFails(setDoc(doc(db, 'conversations', id),
        conversationData(custA, proUid, 'professional', { blockedByRole: 'admin' })));
    });

    it('non-zero unreadCount at create fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = conversationDocId(custA, proUid);
      await assertFails(setDoc(doc(db, 'conversations', id),
        conversationData(custA, proUid, 'professional', {
          unreadCount: { [custA]: 0, [proUid]: 3 },
        })));
    });
  });

  // ── conversations: update — participant branches ──────────────────────────
  describe('conversations update — participant branches', () => {
    const custA = 'conv_upd_custA';
    const proUid = 'conv_upd_pro';
    const otherUid = 'conv_upd_other';
    const convId = conversationDocId(custA, proUid);
    let seededConv;

    beforeEach(async () => {
      // Captured once and reused verbatim below (rather than calling
      // conversationData() again) — a fresh call regenerates createdAt/
      // lastMessageTime with new timestamps, which would make a
      // set(merge:true) using that fresh object look like it's also
      // rewriting createdAt, tripping conversationIdentityUnchanged()
      // for reasons unrelated to what the test is actually checking.
      seededConv = conversationData(custA, proUid, 'professional');
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'conversations', convId), seededConv);
      });
    });

    it('participant last-message update succeeds (full merge-set shape)', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(setDoc(doc(db, 'conversations', convId), {
        ...seededConv,
        lastMessage: 'New message',
        lastMessageSenderId: proUid,
        updatedAt: new Date().toISOString(),
      }, { merge: true }));
    });

    it('last-message update with lastMessageSenderId != caller fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        lastMessage: 'Spoofed',
        lastMessageTime: new Date().toISOString(),
        lastMessageSenderId: custA,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('sender unread increment: other participant +1, sender unchanged', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'conversations', convId), {
        [`unreadCount.${proUid}`]: 1,
        [`unreadCount.${custA}`]: 0,
      }));
    });

    it('unread increment on own counter (not the other participant) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        [`unreadCount.${custA}`]: 1,
      }));
    });

    it('unread increment inserting an arbitrary uid key fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        [`unreadCount.${proUid}`]: 1,
        'unreadCount.some_random_uid': 1,
      }));
    });

    it('reader unread reset: own counter to 0, other unchanged', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations', convId), {
          [`unreadCount.${proUid}`]: 3,
        });
      });
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'conversations', convId), {
        [`unreadCount.${proUid}`]: 0,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('unread reset changing the OTHER participant counter fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        [`unreadCount.${proUid}`]: 0,
        [`unreadCount.${custA}`]: 5,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('participant block succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'conversations', convId), {
        isBlocked: true,
        blockedBy: custA,
        blockedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('same blocker can unblock', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations', convId), {
          isBlocked: true, blockedBy: custA,
        });
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'conversations', convId), {
        isBlocked: false,
        unblockedBy: custA,
        unblockedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('the OTHER participant cannot unblock a block they did not create', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations', convId), {
          isBlocked: true, blockedBy: custA,
        });
      });
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        isBlocked: false,
        unblockedBy: proUid,
        unblockedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('a participant cannot unblock an Admin-issued block', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations', convId), {
          isBlocked: true, blockedBy: 'some_admin_uid', blockedByRole: 'admin',
        });
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        isBlocked: false,
        unblockedBy: custA,
        unblockedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('unrelated user cannot block someone else\'s conversation', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        isBlocked: true,
        blockedBy: otherUid,
        blockedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('participant cannot rewrite participantIds via an otherwise-valid update', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        participantIds: [custA, otherUid],
        lastMessage: 'hijack',
        lastMessageTime: new Date().toISOString(),
        lastMessageSenderId: custA,
        updatedAt: new Date().toISOString(),
      }));
    });
  });

  // ── conversations: update — admin branches ────────────────────────────────
  describe('conversations update — admin branches', () => {
    const custA = 'conv_admin_custA';
    const proUid = 'conv_admin_pro';
    const adminUid = 'conv_admin_admin';
    const convId = conversationDocId(custA, proUid);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
      });
    });

    it('Admin block succeeds with real field shape', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'conversations', convId), {
        isBlocked: true,
        blockedBy: adminUid,
        blockedByName: 'Test Admin',
        blockedByRole: 'admin',
        blockedAt: new Date().toISOString(),
        blockReason: 'Reported by user',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin unblock succeeds with real field shape', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations', convId), {
          isBlocked: true, blockedBy: adminUid, blockedByRole: 'admin',
        });
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'conversations', convId), {
        isBlocked: false,
        unblockedBy: adminUid,
        unblockedByName: 'Test Admin',
        unblockedByRole: 'admin',
        unblockedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin block missing blockedByRole:"admin" fails (non-admin-shaped write)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        isBlocked: true,
        blockedBy: adminUid,
        blockedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('non-Admin performing an Admin-shaped block write fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        isBlocked: true,
        blockedBy: custA,
        blockedByRole: 'admin',
        blockedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin cannot rewrite participantIds/participantNames/participantRoles/createdAt', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        isBlocked: true,
        blockedBy: adminUid,
        blockedByRole: 'admin',
        blockedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        participantNames: { [custA]: 'Hacked Name', [proUid]: 'Test Provider' },
      }));
    });
  });

  // ── conversations: legacy compatibility ───────────────────────────────────
  describe('conversations legacy compatibility', () => {
    const custA = 'conv_legacy_custA';
    const proUid = 'conv_legacy_pro';
    const convId = conversationDocId(custA, proUid);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        // Legacy doc: no participantNames/participantRoles/unreadCount at all.
        const legacy = conversationData(custA, proUid, 'professional');
        delete legacy.participantNames;
        delete legacy.participantRoles;
        delete legacy.unreadCount;
        await setDoc(doc(db, 'conversations', convId), legacy);
      });
    });

    it('a participant can still read a legacy conversation document', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(db, 'conversations', convId)));
    });

    it('a participant can still send an unread-reset update on a legacy document', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'conversations', convId), {
        [`unreadCount.${custA}`]: 0,
        updatedAt: new Date().toISOString(),
      }));
    });
  });

  // ── messages: reads ────────────────────────────────────────────────────────
  describe('messages reads', () => {
    const custA = 'msg_read_custA';
    const proUid = 'msg_read_pro';
    const otherUid = 'msg_read_other';
    const adminUid = 'msg_read_admin';
    const convId = conversationDocId(custA, proUid);
    let messageId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
        const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
        messageId = msgRef.id;
        await setDoc(msgRef, { id: messageId, ...textMessageData(convId, custA, proUid) });
      });
    });

    it('parent participant (sender side) can read the message', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(db, 'conversations', convId, 'messages', messageId)));
    });

    it('parent participant (receiver side) can read the message', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'conversations', convId, 'messages', messageId)));
    });

    it('unrelated authenticated user cannot read the message', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(getDoc(doc(db, 'conversations', convId, 'messages', messageId)));
    });

    it('Admin can read the message regardless of participancy', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'conversations', convId, 'messages', messageId)));
    });

    it('Admin unfiltered messages-subcollection query succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const snap = await assertSucceeds(
        getDocs(collection(db, 'conversations', convId, 'messages')));
      if (snap.size !== 1) throw new Error(`Expected 1 message for admin, got ${snap.size}`);
    });

    // Phase 4D2: the real messagesForConversationProvider query — Firestore
    // can prove every document this exact query could ever return satisfies
    // isNormalMessageType(), which is what makes this participant-side list
    // query provable (unlike an unfiltered one, see next test).
    it("participant's real where('type', whereIn: [...]) filtered query succeeds", async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'conversations', convId, 'messages'),
        where('type', 'in', ['text', 'image', 'voice']));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 1) throw new Error(`Expected 1 message, got ${snap.size}`);
    });

    it('participant unfiltered messages-subcollection query fails (not provable — Firestore Rules are not post-query filters)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(getDocs(collection(db, 'conversations', convId, 'messages')));
    });
  });

  // ── messages: legacy adminWarning documents (Phase 4D2 §6b) ──────────────
  // Simulates a type=='adminWarning' document that was already sitting
  // inside messages before this phase (never migrated, per the Phase 4D1
  // 6b decision) — Admin retains full read/hide access to it in place;
  // participants (targeted or not) can no longer read it at all, and it is
  // structurally excluded from the real filtered participant query.
  describe('messages legacy adminWarning documents (Phase 4D2 6b)', () => {
    const custA = 'msg_legacy_warn_custA';
    const proUid = 'msg_legacy_warn_pro';
    const adminUid = 'msg_legacy_warn_admin';
    const convId = conversationDocId(custA, proUid);
    let legacyWarningId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
        // Seeded directly (bypassing rules) to simulate a document already
        // in production from before Phase 4D2 — targeting custA, exactly
        // like a real legacy write would have.
        const legacyRef = doc(collection(db, 'conversations', convId, 'messages'));
        legacyWarningId = legacyRef.id;
        await setDoc(legacyRef, {
          id: legacyWarningId, ...adminWarningMessageData(convId, adminUid, [custA]),
        });
      });
    });

    it('Admin can still read the legacy adminWarning document directly', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(
        getDoc(doc(db, 'conversations', convId, 'messages', legacyWarningId)));
    });

    it('Admin unfiltered messages query still includes the legacy adminWarning document', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const snap = await assertSucceeds(
        getDocs(collection(db, 'conversations', convId, 'messages')));
      if (snap.size !== 1) throw new Error(`Expected 1 legacy doc for admin, got ${snap.size}`);
    });

    it('the targeted participant can no longer read the legacy adminWarning document', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(
        getDoc(doc(db, 'conversations', convId, 'messages', legacyWarningId)));
    });

    it('the other (untargeted) participant can no longer read the legacy adminWarning document', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(
        getDoc(doc(db, 'conversations', convId, 'messages', legacyWarningId)));
    });

    it("the targeted participant's real filtered messages query does not return the legacy adminWarning document", async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'conversations', convId, 'messages'),
        where('type', 'in', ['text', 'image', 'voice']));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 0) throw new Error(`Expected 0 normal messages, got ${snap.size}`);
    });

    it('Admin can still hide the legacy adminWarning document', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'conversations', convId, 'messages', legacyWarningId), {
          isDeleted: true,
          text: '',
          deletedBy: adminUid,
          deletedByName: 'Test Admin',
          deletedByRole: 'admin',
          adminDeleted: true,
          deletedAt: new Date().toISOString(),
        }));
    });

    it('the targeted participant cannot hide/update the legacy adminWarning document', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'messages', legacyWarningId), {
          isDeleted: true,
          text: '',
          deletedBy: custA,
          deletedAt: new Date().toISOString(),
        }));
    });
  });

  // ── messages: create — existing parent conversation ───────────────────────
  describe('messages create — existing parent', () => {
    const custA = 'msg_create_custA';
    const proUid = 'msg_create_pro';
    const otherUid = 'msg_create_other';
    const convId = conversationDocId(custA, proUid);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
      });
    });

    async function sendAs(uid, receiverId, dataFactory) {
      const db = testEnv.authenticatedContext(uid).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = { id: msgRef.id, ...dataFactory(convId, uid, receiverId) };
      return { promise: setDoc(msgRef, data), msgRef, data };
    }

    it('text message send succeeds', async () => {
      const { promise } = await sendAs(custA, proUid, textMessageData);
      await assertSucceeds(promise);
    });

    it('image message send succeeds', async () => {
      const { promise } = await sendAs(proUid, custA, imageMessageData);
      await assertSucceeds(promise);
    });

    it('voice message send succeeds', async () => {
      const { promise } = await sendAs(custA, proUid, voiceMessageData);
      await assertSucceeds(promise);
    });

    it('spoofed senderId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = { id: msgRef.id, ...textMessageData(convId, proUid, custA) }; // senderId = proUid, caller = custA
      await assertFails(setDoc(msgRef, data));
    });

    it('spoofed receiverId (not the real other participant) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = { id: msgRef.id, ...textMessageData(convId, custA, otherUid) };
      await assertFails(setDoc(msgRef, data));
    });

    it('non-participant cannot send into someone else\'s conversation', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = { id: msgRef.id, ...textMessageData(convId, otherUid, custA) };
      await assertFails(setDoc(msgRef, data));
    });

    it('send while conversation is blocked fails', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations', convId), { isBlocked: true });
      });
      const { promise } = await sendAs(custA, proUid, textMessageData);
      await assertFails(promise);
    });
  });

  // ── messages: create — standalone missing-parent create now denied ───────
  // Phase 4E: firstMessageCreateAllowed() (the old "missing parent" branch)
  // was removed entirely — sendTextMessageToUser/sendImageMessageToUser/
  // sendVoiceMessageToUser now always write the first message and its
  // parent conversation together in one atomic WriteBatch (see the
  // "atomic first-message batch" describe block below). A standalone
  // message create with no accompanying conversation write in the same
  // atomic operation is therefore denied unconditionally now, regardless of
  // how "valid" the message itself would otherwise look, because
  // normalMessageCreateAllowed()'s getAfter() lookup on the conversation
  // resolves to "does not exist" when nothing in the current
  // batch/transaction created it.
  describe('messages create — standalone missing-parent create now denied (Phase 4E)', () => {
    const custA = 'msg_first_custA';
    const proUid = 'msg_first_pro';
    const conUid = 'msg_first_con';
    const otherUid = 'msg_first_other';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
      });
    });

    it('standalone first text message with no parent conversation document now fails', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = { id: msgRef.id, ...textMessageData(convId, custA, proUid) };
      await assertFails(setDoc(msgRef, data));
    });

    it('standalone first image message with no parent conversation document now fails', async () => {
      const convId = conversationDocId(custA, conUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = { id: msgRef.id, ...imageMessageData(convId, custA, conUid) };
      await assertFails(setDoc(msgRef, data));
    });

    it('standalone first voice message with no parent conversation document now fails', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = { id: msgRef.id, ...voiceMessageData(convId, custA, proUid) };
      await assertFails(setDoc(msgRef, data));
    });

    it('standalone message create with wrong conversationId path still fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const wrongConvId = 'not_the_real_id';
      const msgRef = doc(collection(db, 'conversations', wrongConvId, 'messages'));
      const data = { id: msgRef.id, ...textMessageData(wrongConvId, custA, proUid) };
      await assertFails(setDoc(msgRef, data));
    });

    it('adminWarning type still cannot use any missing-parent path', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = {
        id: msgRef.id,
        ...adminWarningMessageData(convId, custA, [custA, proUid]),
      };
      await assertFails(setDoc(msgRef, data));
    });
  });

  // ── messages: create — atomic first-message batch (Phase 4E) ─────────────
  // Mirrors the real sendTextMessageToUser/sendImageMessageToUser/
  // sendVoiceMessageToUser Flutter functions exactly: one atomic
  // WriteBatch containing (1) the new message document and (2) the parent
  // conversation create-or-merge (lastMessage/lastMessageTime/
  // lastMessageSenderId/participant names+roles/timestamps), committed
  // together — proving an orphan message can no longer exist, and that an
  // invalid document anywhere in the batch fails the whole commit, leaving
  // neither document behind.
  describe('messages create — atomic first-message batch (Phase 4E)', () => {
    const custA = 'msg_atomic_custA';
    const proUid = 'msg_atomic_pro';
    const conUid = 'msg_atomic_con';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
      });
    });

    async function assertBothDocumentsAbsent(convId, msgId) {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const msgSnap = await getDoc(
          doc(ctx.firestore(), 'conversations', convId, 'messages', msgId));
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        if (msgSnap.exists()) {
          throw new Error('message document should not exist after a failed atomic batch');
        }
        if (convSnap.exists()) {
          throw new Error('conversation document should not exist after a failed atomic batch');
        }
      });
    }

    it('first text message creates both conversation and message atomically', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hello there', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now,
      }), { merge: true });

      await assertSucceeds(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const msgSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId, 'messages', msgRef.id));
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        if (!msgSnap.exists()) throw new Error('message document missing after a successful atomic batch');
        if (!convSnap.exists()) throw new Error('conversation document missing after a successful atomic batch');
      });
    });

    it('first image message creates both conversation and message atomically', async () => {
      const convId = conversationDocId(custA, conUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...imageMessageData(convId, custA, conUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, conUid, 'contractor', {
        lastMessage: '[Image]', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now,
      }), { merge: true });

      await assertSucceeds(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const msgSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId, 'messages', msgRef.id));
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        if (!msgSnap.exists()) throw new Error('message document missing after a successful atomic batch');
        if (!convSnap.exists()) throw new Error('conversation document missing after a successful atomic batch');
      });
    });

    it('first voice message creates both conversation and message atomically', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...voiceMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: '[Voice]', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now,
      }), { merge: true });

      await assertSucceeds(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const msgSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId, 'messages', msgRef.id));
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        if (!msgSnap.exists()) throw new Error('message document missing after a successful atomic batch');
        if (!convSnap.exists()) throw new Error('conversation document missing after a successful atomic batch');
      });
    });

    it('an invalid message document in the batch fails the whole batch, leaving neither document', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      // Spoofed senderId (proUid) while the caller is custA — invalid.
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, proUid, custA, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hello', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now,
      }), { merge: true });

      await assertFails(batch.commit());
      await assertBothDocumentsAbsent(convId, msgRef.id);
    });

    it('an invalid conversation document in the batch fails the whole batch, leaving neither document', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, proUid, { sentAt: now }) });
      // Spoofed lastMessageSenderId (not the caller) — invalid.
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hello', lastMessageTime: now, lastMessageSenderId: proUid,
        createdAt: now, updatedAt: now,
      }), { merge: true });

      await assertFails(batch.commit());
      await assertBothDocumentsAbsent(convId, msgRef.id);
    });

    it('first message to an existing blocked conversation fails atomically', async () => {
      const convId = conversationDocId(custA, proUid);
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'conversations', convId),
          conversationData(custA, proUid, 'professional', { isBlocked: true, blockedBy: proUid }));
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      // Real code never includes createdAt in the merge payload for an
      // existing conversation (only isNew ? 'createdAt': ... does) —
      // omitted here too, so this test fails only because of isBlocked,
      // not an unrelated createdAt-immutability mismatch.
      const convMergePayload = conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hello', lastMessageTime: now, lastMessageSenderId: custA,
        isBlocked: true, updatedAt: now,
      });
      delete convMergePayload.createdAt;

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, convMergePayload, { merge: true });

      await assertFails(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const msgSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId, 'messages', msgRef.id));
        if (msgSnap.exists()) throw new Error('message should not exist after a rejected send to a blocked conversation');
      });
    });

    it('existing-conversation sends still work via the same atomic batch pattern', async () => {
      const convId = conversationDocId(custA, proUid);
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
      });
      const db = testEnv.authenticatedContext(proUid).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      // Same createdAt-omission reasoning as above — this is an existing
      // conversation, so the real merge payload never includes createdAt.
      const convMergePayload = conversationData(custA, proUid, 'professional', {
        lastMessage: 'A reply', lastMessageTime: now, lastMessageSenderId: proUid, updatedAt: now,
      });
      delete convMergePayload.createdAt;

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, proUid, custA, { sentAt: now }) });
      batch.set(convRef, convMergePayload, { merge: true });

      await assertSucceeds(batch.commit());
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const msgSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId, 'messages', msgRef.id));
        if (!msgSnap.exists()) throw new Error('message document missing after a successful existing-conversation batch send');
      });
    });
  });

  // ── messages: create — admin warning now denied entirely (Phase 4D2) ─────
  // New Admin Warnings are written exclusively to the sibling adminWarnings
  // subcollection now (see adminWarnings.test.js) — creating a
  // type=='adminWarning' document inside messages must fail for every
  // actor, Admin included, so that a participant's server-side-filtered
  // messages query (where('type','in',['text','image','voice'])) can never
  // be bypassed by a fresh warning landing back in this collection.
  describe('messages create — admin warning now denied entirely (Phase 4D2)', () => {
    const custA = 'msg_warn_custA';
    const proUid = 'msg_warn_pro';
    const otherUid = 'msg_warn_other';
    const adminUid = 'msg_warn_admin';
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

    it('Admin creating a fully valid adminWarning-shaped message inside messages fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = { id: msgRef.id, ...adminWarningMessageData(convId, adminUid, [custA]) };
      await assertFails(setDoc(msgRef, data));
    });

    it('Admin creating an adminWarning inside messages fails even while the conversation is blocked', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations', convId), { isBlocked: true });
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = { id: msgRef.id, ...adminWarningMessageData(convId, adminUid, [proUid]) };
      await assertFails(setDoc(msgRef, data));
    });

    it('Admin warning targeting a non-participant uid fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = { id: msgRef.id, ...adminWarningMessageData(convId, adminUid, [otherUid]) };
      await assertFails(setDoc(msgRef, data));
    });

    it('non-Admin sending an adminWarning-shaped message fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const data = { id: msgRef.id, ...adminWarningMessageData(convId, custA, [proUid]) };
      await assertFails(setDoc(msgRef, data));
    });
  });

  // ── messages: update — sender edit/delete ─────────────────────────────────
  describe('messages update — sender edit/delete', () => {
    const custA = 'msg_edit_custA';
    const proUid = 'msg_edit_pro';
    const convId = conversationDocId(custA, proUid);
    let messageId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
        const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
        messageId = msgRef.id;
        await setDoc(msgRef, { id: messageId, ...textMessageData(convId, custA, proUid) });
      });
    });

    it('sender can edit their own text message', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), {
          text: 'edited text',
          isEdited: true,
          editedAt: new Date().toISOString(),
        }));
    });

    it('sender can soft-delete their own message', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), {
          isDeleted: true,
          text: '',
          deletedBy: custA,
          deletedAt: new Date().toISOString(),
        }));
    });

    it('another participant editing the sender\'s message fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), {
          text: 'hijacked',
          isEdited: true,
          editedAt: new Date().toISOString(),
        }));
    });

    it('another participant deleting the sender\'s message fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), {
          isDeleted: true,
          text: '',
          deletedBy: proUid,
          deletedAt: new Date().toISOString(),
        }));
    });

    it('sender cannot change immutable fields (senderId/conversationId/sentAt/type)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), {
          text: 'edited text',
          isEdited: true,
          senderId: proUid,
        }));
    });
  });

  // ── messages: update — receiver mark-read ─────────────────────────────────
  describe('messages update — receiver mark-read', () => {
    const custA = 'msg_read_flag_custA';
    const proUid = 'msg_read_flag_pro';
    const otherUid = 'msg_read_flag_other';
    const convId = conversationDocId(custA, proUid);
    let messageId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
        const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
        messageId = msgRef.id;
        await setDoc(msgRef, { id: messageId, ...textMessageData(convId, custA, proUid) });
      });
    });

    it('the real receiver can mark the message read', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), { isRead: true }));
    });

    it('the sender cannot mark their own sent message read', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), { isRead: true }));
    });

    it('an unrelated user cannot mark the message read', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), { isRead: true }));
    });
  });

  // ── messages: update — admin hide ─────────────────────────────────────────
  describe('messages update — admin hide', () => {
    const custA = 'msg_hide_custA';
    const proUid = 'msg_hide_pro';
    const adminUid = 'msg_hide_admin';
    const convId = conversationDocId(custA, proUid);
    let messageId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
        const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
        messageId = msgRef.id;
        await setDoc(msgRef, { id: messageId, ...textMessageData(convId, custA, proUid) });
      });
    });

    it('Admin hide succeeds with the exact real field shape', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), {
          isDeleted: true,
          text: '',
          deletedBy: adminUid,
          deletedByName: 'Test Admin',
          deletedByRole: 'admin',
          adminDeleted: true,
          deletedAt: new Date().toISOString(),
        }));
    });

    it('non-Admin performing an Admin-hide-shaped write fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), {
          isDeleted: true,
          text: '',
          deletedBy: custA,
          deletedByName: 'Test Customer',
          deletedByRole: 'admin',
          adminDeleted: true,
          deletedAt: new Date().toISOString(),
        }));
    });
  });

  // ── messages: legacy compatibility ────────────────────────────────────────
  describe('messages legacy compatibility', () => {
    const custA = 'msg_legacy_custA';
    const proUid = 'msg_legacy_pro';
    const convId = conversationDocId(custA, proUid);
    let messageId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
        const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
        messageId = msgRef.id;
        // Legacy doc: no isRead/isEdited/isDeleted at all.
        const legacyMsg = textMessageData(convId, custA, proUid);
        delete legacyMsg.isRead;
        delete legacyMsg.isEdited;
        delete legacyMsg.isDeleted;
        await setDoc(msgRef, { id: messageId, ...legacyMsg });
      });
    });

    it('sender can still edit a legacy message missing isEdited/isDeleted', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), {
          text: 'edited legacy text',
          isEdited: true,
          editedAt: new Date().toISOString(),
        }));
    });

    it('receiver can still mark a legacy message (missing isRead) as read', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), { isRead: true }));
    });
  });

  // ── recursive wildcard regression ──────────────────────────────────────────
  describe('recursive wildcard regression (post wildcard removal)', () => {
    const custA = 'wc_custA';
    const proUid = 'wc_pro';
    const otherUid = 'wc_other';
    const convId = conversationDocId(custA, proUid);
    let messageId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
        const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
        messageId = msgRef.id;
        await setDoc(msgRef, { id: messageId, ...textMessageData(convId, custA, proUid) });
      });
    });

    it('unrelated user cannot read via collectionGroup("messages")', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(getDocs(collectionGroup(db, 'messages')));
    });

    it('unrelated user cannot read via collectionGroup("conversations")', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(getDocs(collectionGroup(db, 'conversations')));
    });

    // Documented Firestore limitation, not a security gap: an unfiltered
    // collectionGroup('messages') list request fails for EVERY caller,
    // participant included — Firestore rejects list/query requests up front
    // unless it can statically prove every possible result satisfies the
    // rule, and our messages read rule authorizes via get() on each
    // document's own specific parent conversation, which varies per result
    // and isn't something an unfiltered collectionGroup query can pin down.
    // This matches Phase 4A: the real app never issues a collectionGroup
    // query for messages/conversations, only
    // .collection('conversations').doc(id).collection('messages') (already
    // proven to succeed for participants in the "messages reads" describe
    // block above) and .collection('conversations') directly for Admin.
    it('collectionGroup("messages") fails even for a real participant (Firestore query-validation limit, not an auth gap)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(getDocs(collectionGroup(db, 'messages')));
    });
  });

  // ── failed writes leave documents unchanged ───────────────────────────────
  describe('failed writes leave documents unchanged', () => {
    const custA = 'fail_noop_custA';
    const proUid = 'fail_noop_pro';
    const otherUid = 'fail_noop_other';
    const convId = conversationDocId(custA, proUid);
    let messageId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));
        const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
        messageId = msgRef.id;
        await setDoc(msgRef, { id: messageId, ...textMessageData(convId, custA, proUid) });
      });
    });

    it('a rejected unread-increment leaves unreadCount unchanged', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        [`unreadCount.${custA}`]: 99,
      }));
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const snap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        const unread = snap.data().unreadCount || {};
        if (unread[custA] === 99) {
          throw new Error('unreadCount was mutated despite the rejected write');
        }
      });
    });

    it('a rejected cross-sender edit leaves the message text unchanged', async () => {
      const db = testEnv.authenticatedContext(otherUid).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'messages', messageId), {
          text: 'hijacked by unrelated user',
          isEdited: true,
        }));
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const snap = await getDoc(
          doc(ctx.firestore(), 'conversations', convId, 'messages', messageId));
        if (snap.data().text === 'hijacked by unrelated user') {
          throw new Error('message text was mutated despite the rejected write');
        }
      });
    });
  });

  // ── HOTFIX (chat-production-before) ───────────────────────────────────────
  // Regression coverage for the emergency production hotfix: chat was
  // permission-denied both for a brand-new conversation and for a reply into
  // an existing one, plus mark-read. firestore.rules itself is UNCHANGED —
  // every fix below is a Flutter-side call-shape fix; these tests pin down
  // the exact Rules-level proof each fix now relies on (and, for the
  // "(proven bug)"/"(proven, accepted limitation)" tests, the exact failure
  // shapes that motivated it).

  // ── hotfix: new-conversation existence check ──────────────────────────────
  // Production symptom: opening a brand-new (never-messaged) conversation
  // failed with permission-denied on conversationById/messages/adminWarnings,
  // and the first send failed too. Root cause: the Dart app used to call
  // convRef.get() directly on conversations/{conversationId} to decide
  // whether the conversation already existed — but for a document that
  // doesn't exist yet, isParticipant() reads resource.data.participantIds on
  // a null resource (errors) while isAdmin() alone is false for a normal
  // participant, so `error || false` denies the read outright. The fix
  // (_findExistingConversationDoc in app_providers.dart) uses a
  // `participantIds arrayContains myUid` query instead — the same proof
  // shape currentUserConversationsProvider already relies on — which is
  // provably safe whether or not the target document exists.
  describe('hotfix: new-conversation existence check', () => {
    const custA = 'hotfix_new_custA';
    const proUid = 'hotfix_new_pro';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
      });
    });

    it('(proven bug) a direct get() on a conversation that does not exist yet is denied for a normal participant', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(getDoc(doc(db, 'conversations', convId)));
    });

    it('(fix) the participant-conversations query succeeds (empty) before any conversation exists', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'conversations'),
        where('participantIds', 'array-contains', custA));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 0) throw new Error(`Expected 0 conversations, got ${snap.size}`);
    });

    it('(fix) the same query finds the conversation immediately after the first message creates it, and a direct read then succeeds too', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hi', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now,
      }), { merge: true });
      await assertSucceeds(batch.commit());

      const q = query(collection(db, 'conversations'),
        where('participantIds', 'array-contains', custA));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 1) throw new Error(`Expected 1 conversation after creation, got ${snap.size}`);

      // conversationByIdProvider's Admin branch (and any post-creation direct
      // read) — the document is no longer "possibly nonexistent" now.
      await assertSucceeds(getDoc(convRef));
    });
  });

  // ── hotfix: messages/adminWarnings query under a nonexistent parent ──────
  // Production symptom: the new-conversation chat screen issued the
  // messages/adminWarnings listeners immediately, before any message had
  // ever been sent — both subcollection queries were denied outright because
  // isParentParticipant()/parentConversation() call get() on a conversation
  // document that doesn't exist yet. The fix gates these two listeners in
  // the three chat screens (customer/professional/contractor) behind
  // "conversation is known to exist" (conversationByIdProvider != null)
  // instead of changing the Rules — these tests document exactly why that
  // gate is necessary: both queries below are denied, not merely empty.
  describe('hotfix: messages/adminWarnings query under a nonexistent parent', () => {
    const custA = 'hotfix_noparent_custA';
    const proUid = 'hotfix_noparent_pro';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
      });
    });

    it('(proven bug) the real filtered messages query fails under a nonexistent parent conversation', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'conversations', convId, 'messages'),
        where('type', 'in', ['text', 'image', 'voice']));
      await assertFails(getDocs(q));
    });

    it('(proven bug) the adminWarnings query fails under a nonexistent parent conversation', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'conversations', convId, 'adminWarnings'),
        where('targetUserIds', 'array-contains', custA));
      await assertFails(getDocs(q));
    });
  });

  // ── hotfix: existing-conversation send writes only mutable fields ────────
  // Production symptom: a reply from whichever participant did NOT create
  // the conversation failed with permission-denied. Root cause: the old
  // Dart code re-wrote participantIds/participantNames/participantRoles/
  // isBlocked/createdAt on every send via set(merge:true), with
  // participantIds always written as [senderId, receiverId] literally —
  // the *other* participant's reply wrote that ordered list in the reverse
  // of what's already stored, and firestore.rules'
  // conversationIdentityUnchanged() requires exact list equality, denying
  // the whole update. The fix (sendTextMessageToUser/sendImageMessageToUser/
  // sendVoiceMessageToUser) writes only lastMessage/lastMessageTime/
  // lastMessageSenderId/updatedAt (+ a separate unreadCount increment) for
  // an existing conversation, leaving participantIds/participantNames/
  // participantRoles/isBlocked/createdAt completely untouched.
  describe('hotfix: existing-conversation send writes only mutable fields', () => {
    const custA = 'hotfix_reply_custA';
    const proUid = 'hotfix_reply_pro';
    let seededConv;

    beforeEach(async () => {
      seededConv = conversationData(custA, proUid, 'professional');
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'conversations', conversationDocId(custA, proUid)), seededConv);
      });
    });

    it('(proven bug) the OTHER participant replying with the old [senderId, receiverId]-ordered full-identity payload is denied', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(proUid).firestore();
      // Exactly what the old sendTextMessageToUser wrote: full identity
      // payload, participantIds always [senderId, receiverId] — here proUid
      // is senderId, so the list is [proUid, custA], the reverse of the
      // stored [custA, proUid].
      await assertFails(setDoc(doc(db, 'conversations', convId), {
        id: convId,
        participantIds: [proUid, custA],
        participantNames: seededConv.participantNames,
        participantRoles: seededConv.participantRoles,
        lastMessage: 'A reply',
        lastMessageTime: new Date().toISOString(),
        lastMessageSenderId: proUid,
        isBlocked: false,
        updatedAt: new Date().toISOString(),
      }, { merge: true }));
    });

    it('(proven bug) a drifted participantNames value (e.g. a changed display name since creation) is also denied', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(setDoc(doc(db, 'conversations', convId), {
        id: convId,
        participantIds: seededConv.participantIds,
        participantNames: { ...seededConv.participantNames, [proUid]: 'New Display Name' },
        participantRoles: seededConv.participantRoles,
        lastMessage: 'A reply',
        lastMessageTime: new Date().toISOString(),
        lastMessageSenderId: proUid,
        isBlocked: false,
        updatedAt: new Date().toISOString(),
      }, { merge: true }));
    });

    it('(fix) the OTHER participant replying with only the real mutable fields succeeds', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'conversations', convId), {
        lastMessage: 'A reply',
        lastMessageTime: new Date().toISOString(),
        lastMessageSenderId: proUid,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('(fix) identity fields remain byte-for-byte unchanged after the minimal-field reply', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'conversations', convId), {
        lastMessage: 'A reply',
        lastMessageTime: new Date().toISOString(),
        lastMessageSenderId: proUid,
        updatedAt: new Date().toISOString(),
      }));
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const snap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        const data = snap.data();
        if (JSON.stringify(data.participantIds) !== JSON.stringify(seededConv.participantIds)) {
          throw new Error('participantIds changed after a minimal-field reply');
        }
        if (JSON.stringify(data.participantNames) !== JSON.stringify(seededConv.participantNames)) {
          throw new Error('participantNames changed after a minimal-field reply');
        }
        if (JSON.stringify(data.participantRoles) !== JSON.stringify(seededConv.participantRoles)) {
          throw new Error('participantRoles changed after a minimal-field reply');
        }
        if (data.createdAt !== seededConv.createdAt) {
          throw new Error('createdAt changed after a minimal-field reply');
        }
      });
    });

    it('(fix) minimal-field reply into a legacy conversation missing participantNames/participantRoles still succeeds', async () => {
      const custB = 'hotfix_reply_legacy_custB';
      const proUid2 = 'hotfix_reply_legacy_pro2';
      const convId = conversationDocId(custB, proUid2);
      const legacy = conversationData(custB, proUid2, 'professional');
      delete legacy.participantNames;
      delete legacy.participantRoles;
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', proUid2), professionalData(proUid2));
        await setDoc(doc(db, 'conversations', convId), legacy);
      });
      const db = testEnv.authenticatedContext(proUid2).firestore();
      await assertSucceeds(updateDoc(doc(db, 'conversations', convId), {
        lastMessage: 'A reply into a legacy conversation',
        lastMessageTime: new Date().toISOString(),
        lastMessageSenderId: proUid2,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('(fix) a reply\'s message create still fails while the conversation is blocked (block enforcement unaffected by the minimal-update change)', async () => {
      const convId = conversationDocId(custA, proUid);
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations', convId), {
          isBlocked: true, blockedBy: custA,
        });
      });
      const db = testEnv.authenticatedContext(proUid).firestore();
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      await assertFails(setDoc(msgRef, {
        id: msgRef.id, ...textMessageData(convId, proUid, custA),
      }));
    });
  });

  // ── hotfix: mark-read — legacy unreadCount shapes ─────────────────────────
  // markConversationAsReadInFirestore resets `unreadCount.$myUid` to 0 via a
  // dot-path update(). This is safe for a map missing the current uid's key
  // entirely, or missing unreadCount altogether (Firestore's dot-path
  // update creates the missing map/key — also covered by the existing
  // "conversations legacy compatibility" describe block above) — but NOT
  // for a legacy conversation where unreadCount was stored as a bare scalar
  // instead of a per-participant map: resource.data.get('unreadCount', {})
  // returns that scalar as-is (the key exists, so the {} default is never
  // used), and calling .get() on a number inside unreadResetBranch() errors.
  // This is a proven, ACCEPTED limitation, not fixed here: the Flutter side
  // now catches exactly this failure as non-fatal (see
  // markConversationAsReadInFirestore's hotfix comment in app_providers.dart)
  // rather than the Rules attempting to coerce/guess what a bare legacy
  // number meant per-participant.
  describe('hotfix: mark-read — legacy unreadCount shapes', () => {
    const custA = 'hotfix_unread_custA';
    const proUid = 'hotfix_unread_pro';
    const convId = conversationDocId(custA, proUid);

    it('(fix) unread-reset succeeds when unreadCount is missing the current uid key entirely', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional', {
            unreadCount: { [proUid]: 2 }, // no custA key at all yet
          }));
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'conversations', convId), {
        [`unreadCount.${custA}`]: 0,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('(proven, accepted limitation) unread-reset fails when unreadCount is a legacy bare scalar, not a map', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional', { unreadCount: 3 }));
      });
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'conversations', convId), {
        [`unreadCount.${custA}`]: 0,
        updatedAt: new Date().toISOString(),
      }));
    });
  });

  // ── hotfix: mark-read — malformed legacy message doesn't block siblings ──
  // markConversationAsReadInFirestore now issues one update() per unread
  // message instead of a single atomic batch, specifically so a malformed
  // legacy message failing receiverMarkReadBranch (e.g. a non-boolean legacy
  // isRead value) only skips that message — it can no longer fail the whole
  // batch and leave every other real unread message in the conversation
  // stuck unread.
  describe('hotfix: mark-read — malformed legacy message does not block siblings', () => {
    const custA = 'hotfix_malformed_custA';
    const proUid = 'hotfix_malformed_pro';
    const convId = conversationDocId(custA, proUid);
    let goodMessageId;
    let malformedMessageId;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'conversations', convId),
          conversationData(custA, proUid, 'professional'));

        const goodRef = doc(collection(db, 'conversations', convId, 'messages'));
        goodMessageId = goodRef.id;
        await setDoc(goodRef, { id: goodMessageId, ...textMessageData(convId, proUid, custA) });

        // Legacy/malformed: isRead stored as a string, not a boolean —
        // resource.data.get('isRead', false) == false compares "false"
        // (string) to false (bool), which never matches.
        const badRef = doc(collection(db, 'conversations', convId, 'messages'));
        malformedMessageId = badRef.id;
        await setDoc(badRef, {
          id: malformedMessageId,
          ...textMessageData(convId, proUid, custA, { isRead: 'false' }),
        });
      });
    });

    it('(proven, accepted limitation) the malformed message isRead update fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(
        doc(db, 'conversations', convId, 'messages', malformedMessageId), { isRead: true }));
    });

    it('(fix) the sibling well-formed message isRead update still succeeds independently', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(
        doc(db, 'conversations', convId, 'messages', goodMessageId), { isRead: true }));
    });
  });

  // ── HOTFIX 2 (single convRef write per batch) ─────────────────────────────
  // Proven via a throwaway rules_tests probe (see PR/incident notes — not
  // checked in): writing convRef TWICE within one atomic batch — e.g.
  // batch.set(convRef, creationPayload) followed by a separate
  // batch.update(convRef, {'unreadCount...': increment(1)}) on the very same
  // document in the very same commit — was denied by firestore.rules even
  // though each half looked individually valid. sendTextMessageToUser/
  // sendImageMessageToUser/sendVoiceMessageToUser now write convRef exactly
  // ONCE per batch: for a new conversation, the receiver's initial unread
  // bump is embedded directly in the create payload; for an existing
  // conversation, lastMessage* and the unread increment are written together
  // in one update() call. Both required a narrow, additive Rules change:
  // unreadCountSafeAtCreate() gained a sender:0/receiver:1 branch, and a new
  // lastMessageAndUnreadIncrementBranch() combines what used to be two
  // separate update branches.
  describe('hotfix 2: new-conversation single-write batch (embedded unreadCount)', () => {
    const custA = 'hf2_new_custA';
    const proUid = 'hf2_new_pro';
    const conUid = 'hf2_new_con';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
      });
    });

    // Exactly 2 writes total in the batch (msgRef.set + convRef.set) — no
    // second operation against convRef — proving the fix's core claim.
    it('(fix) first text message: a single-write (2-operation-total) batch creates conversation + message atomically, with sender:0/receiver:1 unreadCount', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hello there', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now, unreadCount: { [custA]: 0, [proUid]: 1 },
      }));
      await assertSucceeds(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const msgSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId, 'messages', msgRef.id));
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        if (!msgSnap.exists()) throw new Error('message missing after successful single-write batch');
        if (!convSnap.exists()) throw new Error('conversation missing after successful single-write batch');
        const unread = convSnap.data().unreadCount;
        if (unread[custA] !== 0) throw new Error(`expected sender unread 0, got ${unread[custA]}`);
        if (unread[proUid] !== 1) throw new Error(`expected receiver unread 1, got ${unread[proUid]}`);
      });
    });

    it('(fix) first image message: single-write batch creates conversation + message atomically', async () => {
      const convId = conversationDocId(custA, conUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...imageMessageData(convId, custA, conUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, conUid, 'contractor', {
        lastMessage: '[Image]', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now, unreadCount: { [custA]: 0, [conUid]: 1 },
      }));
      await assertSucceeds(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const msgSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId, 'messages', msgRef.id));
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        if (!msgSnap.exists()) throw new Error('message missing after successful single-write batch');
        if (!convSnap.exists()) throw new Error('conversation missing after successful single-write batch');
      });
    });

    it('(fix) first voice message: single-write batch creates conversation + message atomically', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...voiceMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: '[Voice]', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now, unreadCount: { [custA]: 0, [proUid]: 1 },
      }));
      await assertSucceeds(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const msgSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId, 'messages', msgRef.id));
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        if (!msgSnap.exists()) throw new Error('message missing after successful single-write batch');
        if (!convSnap.exists()) throw new Error('conversation missing after successful single-write batch');
      });
    });

    it('(proven bug, still guarded) an invalid message in the single-write batch rejects the whole batch, leaving neither document', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      // Spoofed senderId (proUid) while the caller is custA.
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, proUid, custA, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hello', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now, unreadCount: { [custA]: 0, [proUid]: 1 },
      }));
      await assertFails(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const msgSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId, 'messages', msgRef.id));
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        if (msgSnap.exists()) throw new Error('message should not exist after a rejected batch');
        if (convSnap.exists()) throw new Error('conversation should not exist after a rejected batch');
      });
    });

    it('an invalid participant role pairing (customer<->customer) rejects the whole single-write batch', async () => {
      const custB = 'hf2_new_custB';
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users', custB), customerData(custB));
      });
      const convId = conversationDocId(custA, custB);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, custB, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, custB, 'customer', {
        lastMessage: 'Hello', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now, unreadCount: { [custA]: 0, [custB]: 1 },
      }));
      await assertFails(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        if (convSnap.exists()) throw new Error('conversation should not exist after a rejected batch');
      });
    });

    it('a participantRoles map not matching the stored roles rejects the whole single-write batch', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        // proUid's real stored role is 'professional', not 'contractor'.
        participantRoles: { [custA]: 'customer', [proUid]: 'contractor' },
        lastMessage: 'Hello', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now, unreadCount: { [custA]: 0, [proUid]: 1 },
      }));
      await assertFails(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        if (convSnap.exists()) throw new Error('conversation should not exist after a rejected batch');
      });
    });

    it('sender initial unread must be exactly 0 at creation — 1 is rejected', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hello', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now, unreadCount: { [custA]: 1, [proUid]: 1 },
      }));
      await assertFails(batch.commit());
    });

    // {0, 0} deliberately remains valid — it is the ORIGINAL, still-untouched
    // "no unread bump" branch of unreadCountSafeAtCreate() (e.g. for any
    // hypothetical future creation path that doesn't bump unread at all).
    // Hotfix 2 only ADDED the {sender:0, receiver:1} branch alongside it —
    // it did not remove or narrow this one.
    it('(unchanged) both-zero unreadCount at creation remains valid, distinct from the new sender:0/receiver:1 branch', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hello', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now, unreadCount: { [custA]: 0, [proUid]: 0 },
      }));
      await assertSucceeds(batch.commit());
    });

    it('receiver initial unread must be exactly 1 at creation — 2 is rejected', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hello', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now, unreadCount: { [custA]: 0, [proUid]: 2 },
      }));
      await assertFails(batch.commit());
    });

    it('no third uid may appear in unreadCount at creation', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hello', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now,
        unreadCount: { [custA]: 0, [proUid]: 1, some_random_uid: 0 },
      }));
      await assertFails(batch.commit());
    });

    it('no arbitrary create field is accepted alongside a valid sender:0/receiver:1 unreadCount', async () => {
      const convId = conversationDocId(custA, proUid);
      const db = testEnv.authenticatedContext(custA).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, custA, proUid, { sentAt: now }) });
      batch.set(convRef, conversationData(custA, proUid, 'professional', {
        lastMessage: 'Hello', lastMessageTime: now, lastMessageSenderId: custA,
        createdAt: now, updatedAt: now, unreadCount: { [custA]: 0, [proUid]: 1 },
        adminOnlyField: 'should not be accepted',
      }));
      await assertFails(batch.commit());
    });
  });

  describe('hotfix 2: existing-conversation single-write batch (combined update)', () => {
    const custA = 'hf2_existing_custA';
    const proUid = 'hf2_existing_pro';
    const convId = conversationDocId(custA, proUid);
    let seededConv;

    beforeEach(async () => {
      seededConv = conversationData(custA, proUid, 'professional', {
        unreadCount: { [custA]: 0, [proUid]: 0 },
      });
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'conversations', convId), seededConv);
      });
    });

    it('(fix) a single combined update() (lastMessage* + unreadCount together) succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, proUid, custA, { sentAt: now }) });
      batch.update(convRef, {
        lastMessage: 'A reply', lastMessageTime: now, lastMessageSenderId: proUid, updatedAt: now,
        [`unreadCount.${custA}`]: 1,
      });
      await assertSucceeds(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        const data = convSnap.data();
        if (data.lastMessage !== 'A reply') throw new Error('lastMessage was not updated');
        if (data.unreadCount[custA] !== 1) throw new Error(`expected custA unread 1, got ${data.unreadCount[custA]}`);
        if (data.unreadCount[proUid] !== 0) throw new Error('sender unread should remain 0');
      });
    });

    it('(fix) identity fields remain unchanged after the combined update', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, proUid, custA, { sentAt: now }) });
      batch.update(convRef, {
        lastMessage: 'A reply', lastMessageTime: now, lastMessageSenderId: proUid, updatedAt: now,
        [`unreadCount.${custA}`]: 1,
      });
      await assertSucceeds(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const convSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId));
        const data = convSnap.data();
        if (JSON.stringify(data.participantIds) !== JSON.stringify(seededConv.participantIds)) {
          throw new Error('participantIds changed after the combined update');
        }
        if (JSON.stringify(data.participantNames) !== JSON.stringify(seededConv.participantNames)) {
          throw new Error('participantNames changed after the combined update');
        }
        if (JSON.stringify(data.participantRoles) !== JSON.stringify(seededConv.participantRoles)) {
          throw new Error('participantRoles changed after the combined update');
        }
        if (data.createdAt !== seededConv.createdAt) {
          throw new Error('createdAt changed after the combined update');
        }
      });
    });

    it('a combined update() cannot also change the OTHER participant\'s unread count', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, proUid, custA, { sentAt: now }) });
      batch.update(convRef, {
        lastMessage: 'A reply', lastMessageTime: now, lastMessageSenderId: proUid, updatedAt: now,
        unreadCount: { [custA]: 1, [proUid]: 5 },
      });
      await assertFails(batch.commit());
    });

    it('blocked conversation: message create still fails even attempted alongside the new combined conversation update', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations', convId), {
          isBlocked: true, blockedBy: custA,
        });
      });
      const db = testEnv.authenticatedContext(proUid).firestore();
      const convRef = doc(db, 'conversations', convId);
      const msgRef = doc(collection(db, 'conversations', convId, 'messages'));
      const now = new Date().toISOString();

      const batch = writeBatch(db);
      batch.set(msgRef, { id: msgRef.id, ...textMessageData(convId, proUid, custA, { sentAt: now }) });
      batch.update(convRef, {
        lastMessage: 'A reply', lastMessageTime: now, lastMessageSenderId: proUid, updatedAt: now,
        [`unreadCount.${custA}`]: 1,
      });
      await assertFails(batch.commit());

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const msgSnap = await getDoc(doc(ctx.firestore(), 'conversations', convId, 'messages', msgRef.id));
        if (msgSnap.exists()) throw new Error('message should not exist after a rejected send to a blocked conversation');
      });
    });
  });
});
