'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  adminData, customerData, professionalData, contractorData,
} = require('./fixtures');

describe('categories/{categoryId} security rules', function () {
  this.timeout(20000);
  let testEnv;

  const seededCatId = 'plumbing';
  const adminUid = 'cat_admin';
  const customerUid = 'cat_customer';
  const proUid = 'cat_pro';
  const conUid = 'cat_contractor';

  before(async () => {
    testEnv = await getTestEnv();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'categories', seededCatId), {
        nameKey: 'plumbing',
        icon: '🔧',
        providerCount: 0,
        isActive: true,
      });
      await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
      await setDoc(doc(db, 'users', customerUid), customerData(customerUid));
      await setDoc(doc(db, 'users', proUid), professionalData(proUid));
      await setDoc(doc(db, 'users', conUid), contractorData(conUid));
    });
  });

  describe('reads', () => {
    it('unauthenticated single-document read succeeds', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertSucceeds(getDoc(doc(db, 'categories', seededCatId)));
    });

    it('unauthenticated collection query succeeds', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertSucceeds(getDocs(collection(db, 'categories')));
    });

    it('Customer read succeeds', async () => {
      const db = testEnv.authenticatedContext(customerUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'categories', seededCatId)));
    });

    it('Professional read succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'categories', seededCatId)));
    });

    it('Contractor read succeeds', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'categories', seededCatId)));
    });

    it('Admin read succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'categories', seededCatId)));
    });
  });

  describe('non-admin writes are denied', () => {
    const roles = [
      ['Customer', () => testEnv.authenticatedContext(customerUid).firestore()],
      ['Professional', () => testEnv.authenticatedContext(proUid).firestore()],
      ['Contractor', () => testEnv.authenticatedContext(conUid).firestore()],
      ['Unauthenticated', () => testEnv.unauthenticatedContext().firestore()],
    ];

    roles.forEach(([label, getDb]) => {
      it(`${label} create denied`, async () => {
        const db = getDb();
        await assertFails(setDoc(doc(db, 'categories', `new_cat_by_${label.toLowerCase()}`), {
          nameKey: 'new', icon: '✨', providerCount: 0, isActive: true,
        }));
      });

      it(`${label} update denied`, async () => {
        const db = getDb();
        await assertFails(updateDoc(doc(db, 'categories', seededCatId), { icon: '🚫' }));
      });

      it(`${label} delete denied`, async () => {
        const db = getDb();
        await assertFails(deleteDoc(doc(db, 'categories', seededCatId)));
      });
    });
  });

  describe('admin writes succeed', () => {
    it('Admin create succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(setDoc(doc(db, 'categories', 'admin_new_cat'), {
        nameKey: 'carpentry', icon: '🪚', providerCount: 0, isActive: true,
      }));
    });

    it('Admin update succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'categories', seededCatId), { icon: '🛠️' }));
    });

    it('Admin delete succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(deleteDoc(doc(db, 'categories', seededCatId)));
    });
  });
});
