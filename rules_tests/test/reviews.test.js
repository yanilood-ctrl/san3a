'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  nowIso, customerData, professionalData, contractorData, adminData,
  reviewDocId, reviewData,
} = require('./fixtures');

describe('reviews/{reviewId} security rules', function () {
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
    const custA = 'rev_read_custA';
    const custB = 'rev_read_custB';
    const proUid = 'rev_read_pro';
    const adminUid = 'rev_read_admin';
    const revId = reviewDocId(custA, proUid);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'reviews', revId), reviewData(custA, proUid, 'professional'));
      });
    });

    it('authenticated users can run the real providerId review query successfully', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      const q = query(collection(db, 'reviews'), where('providerId', '==', proUid));
      await assertSucceeds(getDocs(q));
    });

    it('Customer can read their own review', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(db, 'reviews', revId)));
    });

    it('reviewed provider can read it', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'reviews', revId)));
    });

    it('unrelated authenticated user read succeeds (proven broad-read requirement)', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertSucceeds(getDoc(doc(db, 'reviews', revId)));
    });

    it('Admin unfiltered collection query succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDocs(collection(db, 'reviews')));
    });

    it('unauthenticated single-document read fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'reviews', revId)));
    });

    it('unauthenticated collection query fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDocs(collection(db, 'reviews')));
    });
  });

  // ── create ──────────────────────────────────────────────────────────────
  describe('create', () => {
    const custA = 'rev_create_custA';
    const custB = 'rev_create_custB';
    const proUid = 'rev_create_pro';
    const conUid = 'rev_create_con';
    const adminUid = 'rev_create_admin';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
      });
    });

    it('Customer creates a valid Professional review successfully', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = reviewDocId(custA, proUid);
      await assertSucceeds(setDoc(doc(db, 'reviews', id), reviewData(custA, proUid, 'professional')));
    });

    it('Customer creates a valid Contractor review successfully', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = reviewDocId(custA, conUid);
      await assertSucceeds(setDoc(doc(db, 'reviews', id), reviewData(custA, conUid, 'contractor')));
    });

    it('Customer creates a valid order-linked review (3-part id) successfully', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = reviewDocId(custA, proUid, 'order_1');
      await assertSucceeds(setDoc(doc(db, 'reviews', id),
        reviewData(custA, proUid, 'professional', { orderId: 'order_1' })));
    });

    it('Professional creation fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const id = reviewDocId(proUid, conUid);
      await assertFails(setDoc(doc(db, 'reviews', id), reviewData(proUid, conUid, 'contractor')));
    });

    it('Contractor creation fails', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      const id = reviewDocId(conUid, proUid);
      await assertFails(setDoc(doc(db, 'reviews', id), reviewData(conUid, proUid, 'professional')));
    });

    it('Admin creation fails (no real Admin create path proven)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const id = reviewDocId(adminUid, proUid);
      await assertFails(setDoc(doc(db, 'reviews', id), reviewData(adminUid, proUid, 'professional')));
    });

    it('spoofed customerId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = reviewDocId(custB, proUid);
      await assertFails(setDoc(doc(db, 'reviews', id), reviewData(custB, proUid, 'professional')));
    });

    it('self-review fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = reviewDocId(custA, custA);
      await assertFails(setDoc(doc(db, 'reviews', id), reviewData(custA, custA, 'customer')));
    });

    it('targeting another Customer fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = reviewDocId(custA, custB);
      await assertFails(setDoc(doc(db, 'reviews', id), reviewData(custA, custB, 'customer')));
    });

    it('missing provider fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ghost = 'does_not_exist_uid';
      const id = reviewDocId(custA, ghost);
      await assertFails(setDoc(doc(db, 'reviews', id), reviewData(custA, ghost, 'professional')));
    });

    it('unsupported provider role (Admin as target) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = reviewDocId(custA, adminUid);
      await assertFails(setDoc(doc(db, 'reviews', id), reviewData(custA, adminUid, 'admin')));
    });

    it('client provider-role mismatch fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = reviewDocId(custA, proUid);
      // proUid is really 'professional' — client claims 'contractor'.
      await assertFails(setDoc(doc(db, 'reviews', id), reviewData(custA, proUid, 'contractor')));
    });

    it('invalid deterministic document ID fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(doc(db, 'reviews', 'not_the_right_id'),
        reviewData(custA, proUid, 'professional')));
    });

    it('privileged moderation/report fields at creation fail', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = reviewDocId(custA, proUid);
      await assertFails(setDoc(doc(db, 'reviews', id),
        reviewData(custA, proUid, 'professional', {
          isHidden: true, status: 'hidden', reportCount: 3, reportReason: 'spam',
        })));
    });

    it('invalid rating range (negative) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = reviewDocId(custA, proUid);
      await assertFails(setDoc(doc(db, 'reviews', id),
        reviewData(custA, proUid, 'professional', { speedRating: -1 })));
    });

    it('unknown field fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = reviewDocId(custA, proUid);
      await assertFails(setDoc(doc(db, 'reviews', id),
        reviewData(custA, proUid, 'professional', { secretField: true })));
    });
  });

  // ── Customer update / delete ───────────────────────────────────────────
  describe('Customer update and soft-delete', () => {
    const custA = 'rev_upd_custA';
    const custB = 'rev_upd_custB';
    const proUid = 'rev_upd_pro';
    const revId = reviewDocId(custA, proUid);
    const hiddenRevId = reviewDocId(custA, proUid, 'order_hidden');

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'reviews', revId), reviewData(custA, proUid, 'professional'));
        // Seeded already isHidden/status != default, so a "restore" attempt
        // actually changes those values (and is therefore a meaningful test)
        // instead of being a no-op indistinguishable from a content edit.
        await setDoc(doc(db, 'reviews', hiddenRevId), reviewData(custA, proUid, 'professional', {
          orderId: 'order_hidden', isHidden: true, status: 'hidden',
        }));
      });
    });

    it('Customer edits all real allowed review-content fields successfully', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', revId), {
        comment: 'Updated comment',
        speedRating: 5,
        qualityRating: 5,
        communicationRating: 5,
        criteriaRatings: { crit1: 5 },
        relatedService: 'Pipe repair',
        rating: 5,
        updatedAt: nowIso(),
      }));
    });

    it('another Customer edit fails', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), { comment: 'Hacked' }));
    });

    it('reviewed provider content edit fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), { comment: 'Self-serving edit' }));
    });

    it('Customer changing providerId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), { providerId: custB }));
    });

    it('Customer changing customerId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), { customerId: custB }));
    });

    it('Customer changing orderId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), { orderId: 'injected_order' }));
    });

    it('Customer changing isHidden fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), { isHidden: true }));
    });

    it('Customer changing status fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), { status: 'hidden' }));
    });

    it('Customer changing reportCount fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), { reportCount: 99 }));
    });

    it('Customer changing reportReason fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), { reportReason: 'self-injected' }));
    });

    it('unknown-field update fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), { secretField: 'nope' }));
    });

    it('Customer soft-delete succeeds using the exact real map', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', revId), {
        isHidden: true,
        status: 'deleted',
        updatedAt: nowIso(),
      }));
    });

    it('restore by Customer fails (no real Customer-restore flow exists)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      // hiddenRevId is seeded isHidden:true/status:'hidden', so this attempt
      // genuinely changes those values — unlike attempting the same on an
      // already-visible review, which would be a no-op indistinguishable
      // from a legitimate content edit that merely touches updatedAt.
      await assertFails(updateDoc(doc(db, 'reviews', hiddenRevId), {
        isHidden: false,
        status: 'visible',
        updatedAt: nowIso(),
      }));
    });

    it('physical delete fails (no real delete path exists)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(deleteDoc(doc(db, 'reviews', revId)));
    });
  });

  // ── Provider report ─────────────────────────────────────────────────────
  describe('Provider report', () => {
    const custA = 'rev_rpt_custA';
    const proUid = 'rev_rpt_pro';
    const conUid = 'rev_rpt_con';
    const unrelatedProUid = 'rev_rpt_unrelated_pro';
    const proRevId = reviewDocId(custA, proUid);
    const conRevId = reviewDocId(custA, conUid);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', unrelatedProUid), professionalData(unrelatedProUid));
        await setDoc(doc(db, 'reviews', proRevId), reviewData(custA, proUid, 'professional'));
        await setDoc(doc(db, 'reviews', conRevId), reviewData(custA, conUid, 'contractor'));
      });
    });

    it('reviewed Professional reports a review about themselves successfully', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', proRevId), {
        reportCount: 1,
        reportReason: 'Inappropriate content',
        updatedAt: nowIso(),
      }));
    });

    it('reviewed Contractor reports a review about themselves successfully', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', conRevId), {
        reportCount: 1,
        reportReason: 'False claims',
        updatedAt: nowIso(),
      }));
    });

    it('unrelated provider report fails', async () => {
      const db = testEnv.authenticatedContext(unrelatedProUid).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', proRevId), {
        reportCount: 1,
        reportReason: 'Not mine',
        updatedAt: nowIso(),
      }));
    });

    it('Customer cannot use the provider-report branch', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', proRevId), {
        reportCount: 1,
        reportReason: 'Self report attempt',
        updatedAt: nowIso(),
      }));
    });

    it('provider cannot change review content while reporting', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', proRevId), {
        reportCount: 1,
        reportReason: 'Trying to also edit',
        comment: 'Rewritten by provider',
        updatedAt: nowIso(),
      }));
    });

    it('provider cannot hide/change status while reporting', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', proRevId), {
        reportCount: 1,
        reportReason: 'Trying to hide too',
        isHidden: true,
        updatedAt: nowIso(),
      }));
    });

    it('invalid reportCount change (not +1) fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', proRevId), {
        reportCount: 5,
        reportReason: 'Skips ahead',
        updatedAt: nowIso(),
      }));
    });
  });

  // ── Admin moderation ────────────────────────────────────────────────────
  describe('Admin moderation', () => {
    const custA = 'rev_admin_custA';
    const proUid = 'rev_admin_pro';
    const adminUid = 'rev_admin_admin';
    const revId = reviewDocId(custA, proUid);
    const reportedRevId = reviewDocId(custA, proUid, 'order_reported');

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'reviews', revId), reviewData(custA, proUid, 'professional'));
        await setDoc(doc(db, 'reviews', reportedRevId), reviewData(custA, proUid, 'professional', {
          orderId: 'order_reported', reportCount: 2, reportReason: 'Spam', status: 'visible',
        }));
      });
    });

    it('Admin hide succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', revId), {
        isHidden: true, status: 'hidden', updatedAt: nowIso(),
      }));
    });

    it('Admin unhide/restore succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', revId), {
        isHidden: false, status: 'visible', updatedAt: nowIso(),
      }));
    });

    it('Admin soft-delete succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', revId), {
        isHidden: true, status: 'deleted', updatedAt: nowIso(),
      }));
    });

    it('Admin mark-safe succeeds (resets report fields)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', reportedRevId), {
        isHidden: false, status: 'visible', reportCount: 0, reportReason: null, updatedAt: nowIso(),
      }));
    });

    it('Admin Edit Review (comment only) succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', revId), {
        comment: 'Edited by Admin for policy reasons',
        updatedAt: nowIso(),
      }));
    });

    it('Admin cannot change customerId', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), {
        customerId: adminUid, isHidden: true, status: 'hidden', updatedAt: nowIso(),
      }));
    });

    it('Admin cannot change providerId', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), {
        providerId: adminUid, isHidden: true, status: 'hidden', updatedAt: nowIso(),
      }));
    });

    it('Admin cannot change createdAt', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), {
        createdAt: nowIso(), isHidden: true, status: 'hidden', updatedAt: nowIso(),
      }));
    });

    it('invalid moderation status fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', revId), {
        isHidden: true, status: 'archived', updatedAt: nowIso(),
      }));
    });

    it('physical delete fails (no real physical-delete path exists)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(deleteDoc(doc(db, 'reviews', revId)));
    });
  });

  // ── legacy document compatibility ──────────────────────────────────────
  describe('legacy document compatibility', () => {
    const custA = 'rev_legacy_custA';
    const proUid = 'rev_legacy_pro';
    const adminUid = 'rev_legacy_admin';
    // Legacy shape proven from ReviewModel.fromFirestore fallbacks: missing
    // criteriaRatings/reportCount/status/isHidden all parse safely (empty
    // map / 0 / 'visible' / false respectively).
    const legacyRevId = reviewDocId(custA, proUid, 'legacy_order');

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        // Deliberately missing: criteriaRatings, reportCount, status, isHidden.
        await setDoc(doc(db, 'reviews', legacyRevId), {
          customerId: custA,
          customerName: 'Test Customer',
          providerId: proUid,
          providerName: 'Test Provider',
          providerRole: 'professional',
          orderId: 'legacy_order',
          speedRating: 3,
          qualityRating: 3,
          communicationRating: 3,
          comment: 'Legacy review, pre-moderation-fields schema.',
          createdAt: nowIso(),
        });
      });
    });

    it('Customer can still edit content fields on a legacy review', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', legacyRevId), {
        comment: 'Updated legacy comment',
        updatedAt: nowIso(),
      }));
    });

    it('Admin can still hide a legacy review missing isHidden/status', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', legacyRevId), {
        isHidden: true, status: 'hidden', updatedAt: nowIso(),
      }));
    });

    it('provider report handles a missing legacy reportCount safely (treated as 0)', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', legacyRevId), {
        reportCount: 1,
        reportReason: 'First report on a legacy review',
        updatedAt: nowIso(),
      }));
    });

    it('Admin mark-safe works on a legacy review missing reportCount', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', legacyRevId), {
        isHidden: false, status: 'visible', reportCount: 0, reportReason: null, updatedAt: nowIso(),
      }));
    });
  });

  // ── Real Customer → Professional submit payload ─────────────────────────
  // Reproduces byte-for-byte what the app actually sends when a Customer taps
  // "Add Review" on a Professional's profile, so a permission-denied seen on a
  // device can be reproduced (or ruled out) here instead of guessed at.
  //
  // Chain: provider_profile_screen.dart _AddReviewSheet._submit
  //   -> addReviewInFirestore (app_providers.dart)
  //   -> reviews/{reviewDocId(...)}.set(ReviewModel.toMap())
  //
  // The key difference from reviewData() above is that the real payload also
  // carries criteriaRatings (dynamic review criteria) and relatedService, and
  // omits updatedAt/reportReason entirely on a first submit.
  describe('real Customer -> Professional submit payload', () => {
    const cust = 'rev_app_cust';
    const otherCust = 'rev_app_cust2';
    const proUid = 'rev_app_pro';

    // Exactly the key set ReviewModel.toMap() emits for a NEW review:
    // updatedAt and reportReason are absent because they are null, and
    // orderId/criteriaRatings/relatedService appear only when non-empty.
    function appReviewPayload(customerId, providerId, overrides = {}) {
      return {
        customerId,
        customerName: 'Real Customer',
        providerId,
        providerName: 'Real Professional',
        providerRole: 'professional',
        speedRating: 4.0,
        qualityRating: 5.0,
        communicationRating: 3.0,
        criteriaRatings: { speed_crit: 4.0, quality_crit: 5.0, comm_crit: 3.0 },
        rating: 4.0,
        comment: 'Fast, tidy and communicated well.',
        createdAt: nowIso(),
        status: 'visible',
        isHidden: false,
        reportCount: 0,
        ...overrides,
      };
    }

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', cust), customerData(cust));
        await setDoc(doc(db, 'users', otherCust), customerData(otherCust));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
      });
    });

    it('order-less "General Rating" submit succeeds', async () => {
      // widget.order.id starts with 'mock_' -> effectiveOrderId == null ->
      // 2-part deterministic id and no orderId field.
      const db = testEnv.authenticatedContext(cust).firestore();
      const id = reviewDocId(cust, proUid);
      await assertSucceeds(
        setDoc(doc(db, 'reviews', id), appReviewPayload(cust, proUid)));
    });

    it('order-linked submit (criteriaRatings + relatedService + orderId) succeeds', async () => {
      const db = testEnv.authenticatedContext(cust).firestore();
      const id = reviewDocId(cust, proUid, 'order_abc');
      await assertSucceeds(setDoc(doc(db, 'reviews', id),
        appReviewPayload(cust, proUid, {
          orderId: 'order_abc',
          relatedService: 'Kitchen sink replacement',
        })));
    });

    it('submit with every criterion at zero still succeeds', async () => {
      // When no active criterion is named speed/quality/communication the app
      // writes 0.0 into those legacy fields — the rule only requires >= 0.
      const db = testEnv.authenticatedContext(cust).firestore();
      const id = reviewDocId(cust, proUid);
      await assertSucceeds(setDoc(doc(db, 'reviews', id),
        appReviewPayload(cust, proUid, {
          speedRating: 0.0, qualityRating: 0.0, communicationRating: 0.0,
          criteriaRatings: { punctuality: 5.0 }, rating: 5.0,
        })));
    });

    it('unauthenticated submit fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      const id = reviewDocId(cust, proUid);
      await assertFails(
        setDoc(doc(db, 'reviews', id), appReviewPayload(cust, proUid)));
    });

    it('Customer submitting as another Customer fails', async () => {
      const db = testEnv.authenticatedContext(cust).firestore();
      const id = reviewDocId(otherCust, proUid);
      await assertFails(
        setDoc(doc(db, 'reviews', id), appReviewPayload(otherCust, proUid)));
    });

    it('submit whose target Professional has no users document fails', async () => {
      // The rule requires exists(users/{providerId}); this is the denial a
      // device hits when the profile was opened from a non-Firestore
      // (mock/seeded) provider rather than a real signed-up Professional.
      const db = testEnv.authenticatedContext(cust).firestore();
      const ghostPro = 'rev_app_ghost_pro';
      const id = reviewDocId(cust, ghostPro);
      await assertFails(
        setDoc(doc(db, 'reviews', id), appReviewPayload(cust, ghostPro)));
    });

    it('another Customer cannot overwrite this review', async () => {
      const db0 = testEnv.authenticatedContext(cust).firestore();
      const id = reviewDocId(cust, proUid);
      await assertSucceeds(
        setDoc(doc(db0, 'reviews', id), appReviewPayload(cust, proUid)));

      const db = testEnv.authenticatedContext(otherCust).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', id), {
        comment: 'Overwritten by someone else', updatedAt: nowIso(),
      }));
    });

  });

  // ── Real Customer re-submit payload (existing review) ───────────────────
  // Covers the fix for the reproduced device failure:
  //   REVIEW_SAVE_IS_NEW: false -> [cloud_firestore/permission-denied]
  //
  // addReviewInFirestore used to call set(review.toMap()) for BOTH new and
  // existing reviews. On an existing review that rebuilt every field from the
  // ReviewModel constructor defaults — resetting status/isHidden/reportCount
  // and dropping reportReason — so those keys entered diff().affectedKeys(),
  // which the Customer update branch does not allow.
  //
  // It now issues a partial update() carrying only the eight keys that branch
  // permits. appResubmitPayload() below is exactly what the app sends.
  describe('real Customer re-submit payload (existing review)', () => {
    const cust = 'rev_resubmit_cust';
    const otherCust = 'rev_resubmit_cust2';
    const proUid = 'rev_resubmit_pro';
    const id = reviewDocId(cust, proUid);

    // Mirrors addReviewInFirestore's !isNewReview branch key-for-key.
    function appResubmitPayload(overrides = {}) {
      return {
        comment: 'Re-submitted comment',
        speedRating: 5.0,
        qualityRating: 4.0,
        communicationRating: 5.0,
        criteriaRatings: { speed_crit: 5.0, quality_crit: 4.0 },
        rating: 4.5,
        updatedAt: nowIso(),
        ...overrides,
      };
    }

    // Seeds the stored review with whatever moderation state a test needs.
    async function seedReview(overrides = {}) {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'reviews', id),
          reviewData(cust, proUid, 'professional', overrides));
      });
    }

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', cust), customerData(cust));
        await setDoc(doc(db, 'users', otherCust), customerData(otherCust));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
      });
    });

    it('re-submitting a normal review succeeds', async () => {
      await seedReview();
      const db = testEnv.authenticatedContext(cust).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', id), appResubmitPayload()));
    });

    it('re-submitting a review the provider reported succeeds and keeps reportCount', async () => {
      await seedReview({ reportCount: 1, reportReason: 'Offensive language' });
      const db = testEnv.authenticatedContext(cust).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', id), appResubmitPayload()));

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const snap = await getDoc(doc(ctx.firestore(), 'reviews', id));
        if (snap.data().reportCount !== 1) throw new Error('reportCount was reset');
        if (snap.data().reportReason !== 'Offensive language') {
          throw new Error('reportReason was dropped');
        }
      });
    });

    it('re-submitting an admin-hidden review succeeds and keeps isHidden/status', async () => {
      await seedReview({ isHidden: true, status: 'hidden' });
      const db = testEnv.authenticatedContext(cust).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', id), appResubmitPayload()));

      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const snap = await getDoc(doc(ctx.firestore(), 'reviews', id));
        if (snap.data().isHidden !== true) throw new Error('isHidden was reset');
        if (snap.data().status !== 'hidden') throw new Error('status was reset');
      });
    });

    it('re-submit without criteriaRatings/relatedService succeeds', async () => {
      // Both are omitted by the app when null/empty, matching toMap().
      await seedReview();
      const db = testEnv.authenticatedContext(cust).firestore();
      const payload = appResubmitPayload();
      delete payload.criteriaRatings;
      await assertSucceeds(updateDoc(doc(db, 'reviews', id), payload));
    });

    it('re-submit carrying relatedService succeeds', async () => {
      await seedReview();
      const db = testEnv.authenticatedContext(cust).firestore();
      await assertSucceeds(updateDoc(doc(db, 'reviews', id),
        appResubmitPayload({ relatedService: 'Kitchen sink replacement' })));
    });

    // ── Regression guards: the old behaviour must stay denied ────────────
    it('the old full-document set() on a reported review still fails', async () => {
      await seedReview({ reportCount: 1, reportReason: 'Offensive language' });
      const db = testEnv.authenticatedContext(cust).firestore();
      // What addReviewInFirestore used to send: a whole document rebuilt from
      // ReviewModel defaults, wiping reportCount/reportReason.
      await assertFails(setDoc(doc(db, 'reviews', id),
        reviewData(cust, proUid, 'professional', {
          comment: 'Edited after the report', updatedAt: nowIso(),
        })));
    });

    it('re-submit that also resets moderation fields fails', async () => {
      await seedReview({ isHidden: true, status: 'hidden', reportCount: 2 });
      const db = testEnv.authenticatedContext(cust).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', id), appResubmitPayload({
        isHidden: false, status: 'visible', reportCount: 0,
      })));
    });

    it('re-submit that changes immutable identity fields fails', async () => {
      await seedReview();
      const db = testEnv.authenticatedContext(cust).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', id),
        appResubmitPayload({ customerId: otherCust })));
      await assertFails(updateDoc(doc(db, 'reviews', id),
        appResubmitPayload({ providerId: otherCust })));
      await assertFails(updateDoc(doc(db, 'reviews', id),
        appResubmitPayload({ createdAt: nowIso() })));
      await assertFails(updateDoc(doc(db, 'reviews', id),
        appResubmitPayload({ providerRole: 'contractor' })));
    });

    it('re-submit that rewrites display names fails', async () => {
      // customerName/providerName are not customer-editable; the old set()
      // rewrote them from the live UserModel, which broke re-submit whenever
      // a display name had changed since the review was written.
      await seedReview();
      const db = testEnv.authenticatedContext(cust).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', id),
        appResubmitPayload({ customerName: 'Renamed Customer' })));
      await assertFails(updateDoc(doc(db, 'reviews', id),
        appResubmitPayload({ providerName: 'Renamed Provider' })));
    });

    it('another Customer cannot send the re-submit payload', async () => {
      await seedReview();
      const db = testEnv.authenticatedContext(otherCust).firestore();
      await assertFails(updateDoc(doc(db, 'reviews', id), appResubmitPayload()));
    });

    it('unauthenticated re-submit fails', async () => {
      await seedReview();
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(updateDoc(doc(db, 'reviews', id), appResubmitPayload()));
    });
  });
});
