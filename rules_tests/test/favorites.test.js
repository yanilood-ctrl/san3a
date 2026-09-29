'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  customerData, professionalData, contractorData, adminData,
  favoriteDocId, favoriteData,
} = require('./fixtures');

describe('favorites/{favoriteId} security rules', function () {
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
    const custA = 'fav_read_custA';
    const custB = 'fav_read_custB';
    const proUid = 'fav_read_pro';
    const conUid = 'fav_read_con';
    const adminUid = 'fav_read_admin';
    const favId = favoriteDocId(custA, proUid);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'favorites', favId),
          favoriteData(custA, proUid, 'professional'));
      });
    });

    it('Customer A reads own Favorite document successfully', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(db, 'favorites', favId)));
    });

    it('Customer A can read (get) a not-yet-favorited provider without error — ' +
      'this is the exact toggleFavoriteInFirestore/isFavoriteProvider existence ' +
      'check for a provider that has never been favorited', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const neverFavoritedId = favoriteDocId(custA, conUid);
      const snap = await assertSucceeds(getDoc(doc(db, 'favorites', neverFavoritedId)));
      if (snap.exists()) {
        throw new Error('Expected the not-yet-created favorite to not exist.');
      }
    });

    it("Customer A runs the real where('customerId', isEqualTo: uid) query successfully", async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'favorites'), where('customerId', '==', custA));
      await assertSucceeds(getDocs(q));
    });

    it("Customer B cannot read Customer A's Favorite", async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(getDoc(doc(db, 'favorites', favId)));
    });

    it('Professional cannot read a Customer Favorite (no real app path)', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(getDoc(doc(db, 'favorites', favId)));
    });

    it('Contractor cannot read a Customer Favorite (no real app path)', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      await assertFails(getDoc(doc(db, 'favorites', favId)));
    });

    it('unauthenticated read fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'favorites', favId)));
    });

    it('non-admin unfiltered collection query fails', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(getDocs(collection(db, 'favorites')));
    });

    it('Admin single-document read fails (no real Admin read path proven)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(getDoc(doc(db, 'favorites', favId)));
    });

    it('Admin unfiltered collection query fails (no real Admin read path proven)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(getDocs(collection(db, 'favorites')));
    });
  });

  // ── create ──────────────────────────────────────────────────────────────
  describe('create', () => {
    const custA = 'fav_create_custA';
    const custB = 'fav_create_custB';
    const proUid = 'fav_create_pro';
    const conUid = 'fav_create_con';
    const adminUid = 'fav_create_admin';

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

    it('Customer creates valid Favorite for a Professional successfully', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = favoriteDocId(custA, proUid);
      await assertSucceeds(setDoc(doc(db, 'favorites', id),
        favoriteData(custA, proUid, 'professional')));
    });

    it('Customer creates valid Favorite for a Contractor successfully', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = favoriteDocId(custA, conUid);
      await assertSucceeds(setDoc(doc(db, 'favorites', id),
        favoriteData(custA, conUid, 'contractor')));
    });

    it('spoofed customerId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = favoriteDocId(custB, proUid);
      await assertFails(setDoc(doc(db, 'favorites', id),
        favoriteData(custB, proUid, 'professional')));
    });

    it('wrong deterministic document ID fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(setDoc(doc(db, 'favorites', 'not_the_right_id'),
        favoriteData(custA, proUid, 'professional')));
    });

    it('Professional creating a Favorite fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const id = favoriteDocId(proUid, conUid);
      await assertFails(setDoc(doc(db, 'favorites', id),
        favoriteData(proUid, conUid, 'contractor')));
    });

    it('Contractor creating a Favorite fails', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      const id = favoriteDocId(conUid, proUid);
      await assertFails(setDoc(doc(db, 'favorites', id),
        favoriteData(conUid, proUid, 'professional')));
    });

    it('Admin creating a Favorite fails (no real Admin create path proven)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const id = favoriteDocId(adminUid, proUid);
      await assertFails(setDoc(doc(db, 'favorites', id),
        favoriteData(adminUid, proUid, 'professional')));
    });

    it('Customer favoriting themselves fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = favoriteDocId(custA, custA);
      await assertFails(setDoc(doc(db, 'favorites', id),
        favoriteData(custA, custA, 'customer')));
    });

    it('Customer favoriting another Customer fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = favoriteDocId(custA, custB);
      await assertFails(setDoc(doc(db, 'favorites', id),
        favoriteData(custA, custB, 'customer')));
    });

    it('missing provider document fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const ghostId = 'does_not_exist_uid';
      const id = favoriteDocId(custA, ghostId);
      await assertFails(setDoc(doc(db, 'favorites', id),
        favoriteData(custA, ghostId, 'professional')));
    });

    it('unsupported provider role (Admin as target) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = favoriteDocId(custA, adminUid);
      await assertFails(setDoc(doc(db, 'favorites', id),
        favoriteData(custA, adminUid, 'admin')));
    });

    it('unknown/privileged field fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = favoriteDocId(custA, proUid);
      await assertFails(setDoc(doc(db, 'favorites', id),
        favoriteData(custA, proUid, 'professional', { secretField: true })));
    });
  });

  // ── update ──────────────────────────────────────────────────────────────
  describe('update (no legitimate update path exists in the app)', () => {
    const custA = 'fav_upd_custA';
    const custB = 'fav_upd_custB';
    const proUid = 'fav_upd_pro';
    const adminUid = 'fav_upd_admin';
    const favId = favoriteDocId(custA, proUid);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'favorites', favId),
          favoriteData(custA, proUid, 'professional'));
      });
    });

    it('update denied for the owning Customer (no real update path exists)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'favorites', favId), { providerName: 'Renamed' }));
    });

    it('update denied for another user', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(updateDoc(doc(db, 'favorites', favId), { providerName: 'Hacked' }));
    });

    it('update denied for the favorited Professional', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'favorites', favId), { providerName: 'Self-edit' }));
    });

    it('update denied for Admin', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'favorites', favId), { providerName: 'Admin-edit' }));
    });
  });

  // ── delete ──────────────────────────────────────────────────────────────
  describe('delete', () => {
    const custA = 'fav_del_custA';
    const custB = 'fav_del_custB';
    const proUid = 'fav_del_pro';
    const conUid = 'fav_del_con';
    const adminUid = 'fav_del_admin';
    const favIdPro = favoriteDocId(custA, proUid);
    const favIdCon = favoriteDocId(custA, conUid);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'favorites', favIdPro),
          favoriteData(custA, proUid, 'professional'));
        await setDoc(doc(db, 'favorites', favIdCon),
          favoriteData(custA, conUid, 'contractor'));
      });
    });

    it('owning Customer deletes successfully', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(deleteDoc(doc(db, 'favorites', favIdPro)));
    });

    it('another Customer delete fails', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(deleteDoc(doc(db, 'favorites', favIdPro)));
    });

    it('the favorited Professional delete fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(deleteDoc(doc(db, 'favorites', favIdPro)));
    });

    it('the favorited Contractor delete fails', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      await assertFails(deleteDoc(doc(db, 'favorites', favIdCon)));
    });

    it('Admin delete fails (no real Admin delete path exists)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(deleteDoc(doc(db, 'favorites', favIdPro)));
    });

    it('unauthenticated delete fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(deleteDoc(doc(db, 'favorites', favIdPro)));
    });
  });

  // ── real toggle-flow compatibility ─────────────────────────────────────
  describe('real toggleFavoriteInFirestore flow compatibility', () => {
    const custA = 'fav_toggle_custA';
    const proUid = 'fav_toggle_pro';
    const favId = favoriteDocId(custA, proUid);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
      });
    });

    it('create -> read -> delete -> confirmed gone, using the real id/shape', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();

      // addFavoriteInFirestore()
      await assertSucceeds(setDoc(doc(db, 'favorites', favId),
        favoriteData(custA, proUid, 'professional')));

      // customerFavoritesProvider / isFavoriteProvider read
      const readBack = await assertSucceeds(getDoc(doc(db, 'favorites', favId)));
      if (!readBack.exists()) {
        throw new Error('Expected the just-created favorite to exist on read-back.');
      }

      // removeFavoriteInFirestore()
      await assertSucceeds(deleteDoc(doc(db, 'favorites', favId)));

      // Confirmed gone — read under REAL security rules (not bypassed). The
      // `resource == null || ...` clause on `allow read` is what makes this
      // a meaningful, rules-respecting way to prove absence; before that fix
      // this same read failed with permission-denied instead of exists:false.
      const goneSnap = await assertSucceeds(getDoc(doc(db, 'favorites', favId)));
      if (goneSnap.exists()) {
        throw new Error('Favorite document still exists after delete.');
      }
    });

    // The real toggleFavoriteInFirestore() always checks existence first and
    // calls delete() (never set()) on an already-existing favorite — so a
    // repeated set() on an existing doc is not a real app path. But Firestore
    // itself treats set() on an existing document as an `update`, not a
    // `create` — so this is denied by `allow update: if false;`, which is
    // safe and does not affect the real flow.
    it('a repeated set() on an already-existing favorite is denied (treated as update)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(setDoc(doc(db, 'favorites', favId),
        favoriteData(custA, proUid, 'professional')));
      await assertFails(setDoc(doc(db, 'favorites', favId),
        favoriteData(custA, proUid, 'professional', { providerName: 'Renamed Again' })));
    });
  });
});
