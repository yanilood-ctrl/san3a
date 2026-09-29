'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, addDoc, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  customerData, professionalData, contractorData, adminData, reviewCriteriaData,
} = require('./fixtures');

describe('review_criteria/{criteriaId} security rules', function () {
  this.timeout(20000);
  let testEnv;

  const custUid = 'crit_customer';
  const proUid = 'crit_pro';
  const conUid = 'crit_con';
  const adminUid = 'crit_admin';
  const seededId = 'speed_criterion';

  before(async () => {
    testEnv = await getTestEnv();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', custUid), customerData(custUid));
      await setDoc(doc(db, 'users', proUid), professionalData(proUid));
      await setDoc(doc(db, 'users', conUid), contractorData(conUid));
      await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
      await setDoc(doc(db, 'review_criteria', seededId), reviewCriteriaData());
    });
  });

  describe('reads', () => {
    it('authenticated Customer read succeeds', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'review_criteria', seededId)));
      await assertSucceeds(getDocs(collection(db, 'review_criteria')));
    });

    it('authenticated Professional read succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'review_criteria', seededId)));
      await assertSucceeds(getDocs(collection(db, 'review_criteria')));
    });

    it('authenticated Contractor read succeeds', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'review_criteria', seededId)));
      await assertSucceeds(getDocs(collection(db, 'review_criteria')));
    });

    it('authenticated Admin read succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'review_criteria', seededId)));
      await assertSucceeds(getDocs(collection(db, 'review_criteria')));
    });

    it('unauthenticated read fails (no real pre-auth need proven)', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'review_criteria', seededId)));
      await assertFails(getDocs(collection(db, 'review_criteria')));
    });
  });

  describe('non-admin writes are denied', () => {
    const roles = [
      ['Customer', () => testEnv.authenticatedContext(custUid).firestore()],
      ['Professional', () => testEnv.authenticatedContext(proUid).firestore()],
      ['Contractor', () => testEnv.authenticatedContext(conUid).firestore()],
      ['Unauthenticated', () => testEnv.unauthenticatedContext().firestore()],
    ];

    roles.forEach(([label, getDb]) => {
      it(`${label} create denied`, async () => {
        const db = getDb();
        await assertFails(addDoc(collection(db, 'review_criteria'), reviewCriteriaData({
          title: `New by ${label}`,
        })));
      });

      it(`${label} update denied`, async () => {
        const db = getDb();
        await assertFails(updateDoc(doc(db, 'review_criteria', seededId), { isActive: false }));
      });

      it(`${label} delete denied`, async () => {
        const db = getDb();
        await assertFails(deleteDoc(doc(db, 'review_criteria', seededId)));
      });
    });

    // Proven real risk: seedDefaultReviewCriteriaIfEmpty() (app_providers.dart)
    // is triggered by ReviewCriteriaNotifier.setCriteria() whenever the live
    // stream emits an empty list — reachable from Customer/Professional/
    // Contractor screens (provider_profile_screen.dart, professional_home_
    // screen.dart, contractor_profile_screen.dart), not just Admin. This
    // proves that exact seeding shape is now denied for a non-admin caller.
    it('non-admin default-criteria seeding batch is denied (proven real risk)', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        // Start from a genuinely empty collection, matching the real
        // seedDefaultReviewCriteriaIfEmpty() precondition.
        await deleteDoc(doc(ctx.firestore(), 'review_criteria', seededId));
      });
      const db = testEnv.authenticatedContext(custUid).firestore();
      await assertFails(addDoc(collection(db, 'review_criteria'), reviewCriteriaData({
        title: 'Speed', order: 0,
      })));
    });
  });

  describe('Admin writes succeed', () => {
    it('Admin create succeeds (real Add Criteria shape)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(addDoc(collection(db, 'review_criteria'), reviewCriteriaData({
        title: 'Punctuality', order: 3,
      })));
    });

    it('Admin update succeeds (toggleActive shape)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'review_criteria', seededId), {
        isActive: false,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin update succeeds (reorder shape)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'review_criteria', seededId), {
        order: 2,
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin delete succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(deleteDoc(doc(db, 'review_criteria', seededId)));
    });

    it('Admin default-criteria seeding batch succeeds (same shape a fresh install would need)', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await deleteDoc(doc(ctx.firestore(), 'review_criteria', seededId));
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(addDoc(collection(db, 'review_criteria'),
        reviewCriteriaData({ title: 'Speed', order: 0 })));
      await assertSucceeds(addDoc(collection(db, 'review_criteria'),
        reviewCriteriaData({ title: 'Quality', order: 1 })));
      await assertSucceeds(addDoc(collection(db, 'review_criteria'),
        reviewCriteriaData({ title: 'Communication', order: 2 })));
    });
  });
});
