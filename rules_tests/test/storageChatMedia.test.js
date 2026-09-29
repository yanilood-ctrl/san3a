'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { getStorageTestEnv, STORAGE_BUCKET } = require('./storageHelpers');
const { customerData, professionalData, contractorData, adminData } = require('./fixtures');

const TINY_JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x01, 0x02, 0x03]);
const TINY_AUDIO = Buffer.from([0x1a, 0x45, 0xdf, 0xa3, 0x00, 0x01, 0x02, 0x03]);
const OVERSIZED_IMAGE = Buffer.alloc(11 * 1024 * 1024, 1); // > 10 MiB
const OVERSIZED_VOICE = Buffer.alloc(26 * 1024 * 1024, 1); // > 25 MiB

describe('chat_images / chat_voice security rules (new + legacy paths)', function () {
  this.timeout(20000);
  let testEnv;

  const CUSTOMER = 'chat_customer_uid';
  const PROFESSIONAL = 'chat_professional_uid';
  const CONTRACTOR = 'chat_contractor_uid';
  const ADMIN = 'chat_admin_uid';
  const OTHER_CUSTOMER = 'chat_other_customer_uid';
  const UNREGISTERED = 'chat_unregistered_uid';

  before(async () => {
    testEnv = await getStorageTestEnv();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection('users').doc(CUSTOMER).set(customerData(CUSTOMER));
      await db.collection('users').doc(PROFESSIONAL).set(professionalData(PROFESSIONAL));
      await db.collection('users').doc(CONTRACTOR).set(contractorData(CONTRACTOR));
      await db.collection('users').doc(ADMIN).set(adminData(ADMIN));
      await db.collection('users').doc(OTHER_CUSTOMER).set(customerData(OTHER_CUSTOMER));
      // UNREGISTERED intentionally has no users/{uid} document.
    });
  });

  beforeEach(async () => {
    await testEnv.clearStorage();
  });

  describe('new path create', () => {
    it('A. Customer -> Professional image create succeeds', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertSucceeds(
        storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/msg1/photo.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('B. Professional -> Customer create succeeds', async () => {
      const storage = testEnv.authenticatedContext(PROFESSIONAL).storage(STORAGE_BUCKET);
      await assertSucceeds(
        storage.ref(`chat_images/${PROFESSIONAL}/${CUSTOMER}/msg2/photo.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('B2. Contractor -> Customer create succeeds', async () => {
      const storage = testEnv.authenticatedContext(CONTRACTOR).storage(STORAGE_BUCKET);
      await assertSucceeds(
        storage.ref(`chat_images/${CONTRACTOR}/${CUSTOMER}/msg3/photo.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('C. same-role pair (Customer -> Customer) fails', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${CUSTOMER}/${OTHER_CUSTOMER}/msg4/photo.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('C2. same-role pair (Professional -> Contractor) fails', async () => {
      const storage = testEnv.authenticatedContext(PROFESSIONAL).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${PROFESSIONAL}/${CONTRACTOR}/msg5/photo.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('D. Admin uploader fails (Admin is never a chat-media uploader)', async () => {
      const storage = testEnv.authenticatedContext(ADMIN).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${ADMIN}/${CUSTOMER}/msg6/photo.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('E. nonexistent receiver fails', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${CUSTOMER}/${UNREGISTERED}/msg7/photo.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('F. another user cannot create under a senderUid that is not their own', async () => {
      const storage = testEnv.authenticatedContext(OTHER_CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/msg_spoof/photo.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('G. invalid MIME fails', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/msg8/photo.svg`)
          .put(TINY_JPEG, { contentType: 'image/svg+xml' })
      );
    });

    it('H. oversized image fails', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/msg9/photo.jpg`)
          .put(OVERSIZED_IMAGE, { contentType: 'image/jpeg' })
      );
    });
  });

  describe('new path read', () => {
    async function seedImage(msgId) {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.storage(STORAGE_BUCKET)
          .ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/${msgId}/photo.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' });
      });
    }

    it('I. sender can read', async () => {
      await seedImage('read1');
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertSucceeds(
        storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/read1/photo.jpg`).getDownloadURL()
      );
    });

    it('J. receiver can read', async () => {
      await seedImage('read2');
      const storage = testEnv.authenticatedContext(PROFESSIONAL).storage(STORAGE_BUCKET);
      await assertSucceeds(
        storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/read2/photo.jpg`).getDownloadURL()
      );
    });

    it('K. unrelated user read fails', async () => {
      await seedImage('read3');
      const storage = testEnv.authenticatedContext(OTHER_CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/read3/photo.jpg`).getDownloadURL()
      );
    });

    it('K2. unrelated user list fails', async () => {
      await seedImage('read4');
      const storage = testEnv.authenticatedContext(OTHER_CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}`).listAll());
    });

    it('L. Admin can read', async () => {
      await seedImage('read5');
      const storage = testEnv.authenticatedContext(ADMIN).storage(STORAGE_BUCKET);
      await assertSucceeds(
        storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/read5/photo.jpg`).getDownloadURL()
      );
    });
  });

  describe('new path overwrite/delete', () => {
    it('M. overwrite fails', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      const ref = storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/msg_ow/photo.jpg`);
      await assertSucceeds(ref.put(TINY_JPEG, { contentType: 'image/jpeg' }));
      await assertFails(ref.put(TINY_JPEG, { contentType: 'image/jpeg' }));
    });

    it('N. delete fails for sender (no chat-media delete path exists)', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.storage(STORAGE_BUCKET)
          .ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/msg_del/photo.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' });
      });
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/msg_del/photo.jpg`).delete()
      );
    });

    it('O. delete fails for Admin too', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.storage(STORAGE_BUCKET)
          .ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/msg_del2/photo.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' });
      });
      const storage = testEnv.authenticatedContext(ADMIN).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_images/${CUSTOMER}/${PROFESSIONAL}/msg_del2/photo.jpg`).delete()
      );
    });
  });

  describe('new path voice', () => {
    it('P. audio/mp4 create succeeds', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertSucceeds(
        storage.ref(`chat_voice/${CUSTOMER}/${PROFESSIONAL}/v1/voice.m4a`)
          .put(TINY_AUDIO, { contentType: 'audio/mp4' })
      );
    });

    it('Q. audio/webm create succeeds', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertSucceeds(
        storage.ref(`chat_voice/${CUSTOMER}/${PROFESSIONAL}/v2/voice.webm`)
          .put(TINY_AUDIO, { contentType: 'audio/webm' })
      );
    });

    it('R. unsupported voice MIME (audio/wav) fails', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_voice/${CUSTOMER}/${PROFESSIONAL}/v3/voice.wav`)
          .put(TINY_AUDIO, { contentType: 'audio/wav' })
      );
    });

    it('S. oversized voice fails', async () => {
      const storage = testEnv.authenticatedContext(CUSTOMER).storage(STORAGE_BUCKET);
      await assertFails(
        storage.ref(`chat_voice/${CUSTOMER}/${PROFESSIONAL}/v4/voice.m4a`)
          .put(OVERSIZED_VOICE, { contentType: 'audio/mp4' })
      );
    });
  });

  // ── Emergency Storage Hotfix incident regression ────────────────────────
  // Pinned to the exact real uids/roles from the incident (sender:
  // customer, receiver: professional — read from Production via the public
  // `users/{uid}` read rule, not modified). Diagnosis: validChatPair()/
  // validChatRolePair()/validChatImage()/validVoice() all already accept
  // this exact combination — reproduced successfully against the emulator
  // with these exact uids, exact paths, and exact content types before any
  // change was made here. No storage.rules change and no Flutter path
  // change were found to be necessary or were made. This test locks that
  // proof in permanently so a future regression here is caught immediately.
  describe('incident regression: exact real sender/receiver uids and roles', () => {
    const SENDER_UID = 'Fv9TW3c8gwbFueXlWS8lF5QHI6o1'; // real Production role: customer
    const RECEIVER_UID = 'Xs9cnV2cetOk8rMAVtf8haWCm5K2'; // real Production role: professional

    before(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        // Real Production field shape: sender has isDeleted/isBlocked
        // present (false); receiver's document is missing those optional
        // fields entirely (older/legacy doc) — neither field is read by
        // storage.rules, which only ever checks `role`.
        await db.collection('users').doc(SENDER_UID).set({
          ...customerData(SENDER_UID), isDeleted: false, isBlocked: false,
        });
        const receiverData = professionalData(RECEIVER_UID);
        delete receiverData.isDeleted;
        delete receiverData.isBlocked;
        await db.collection('users').doc(RECEIVER_UID).set(receiverData);
      });
    });

    it('exact incident image path/contentType succeeds', async () => {
      const storage = testEnv.authenticatedContext(SENDER_UID).storage(STORAGE_BUCKET);
      await assertSucceeds(
        storage.ref(`chat_images/${SENDER_UID}/${RECEIVER_UID}/incidentMsg1/image.jpg`)
          .put(TINY_JPEG, { contentType: 'image/jpeg' })
      );
    });

    it('exact incident voice path/contentType (audio/webm) succeeds', async () => {
      const storage = testEnv.authenticatedContext(SENDER_UID).storage(STORAGE_BUCKET);
      await assertSucceeds(
        storage.ref(`chat_voice/${SENDER_UID}/${RECEIVER_UID}/incidentMsg2/voice.webm`)
          .put(TINY_AUDIO, { contentType: 'audio/webm' })
      );
    });

    it('exact incident voice path/contentType (audio/mp4, mobile) succeeds', async () => {
      const storage = testEnv.authenticatedContext(SENDER_UID).storage(STORAGE_BUCKET);
      await assertSucceeds(
        storage.ref(`chat_voice/${SENDER_UID}/${RECEIVER_UID}/incidentMsg3/voice.m4a`)
          .put(TINY_AUDIO, { contentType: 'audio/mp4' })
      );
    });
  });
});

// Legacy chat_images/{conversationId}/{fileName} and
// chat_voice/{conversationId}/{fileName} paths are covered by
// storageLegacyPaths.test.js, alongside legacy order images, so all
// "no uid/customer segment in the path" behavior lives in one file.
