'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  nowIso, customerData, professionalData, contractorData, adminData,
} = require('./fixtures');

describe('users/{userId} security rules', function () {
  this.timeout(20000);
  let testEnv;

  before(async () => {
    testEnv = await getTestEnv();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  // ── create ──────────────────────────────────────────────────────────────
  describe('create', () => {
    it('A. Customer signup succeeds with real signup fields', async () => {
      const uid = 'customer_ok';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertSucceeds(setDoc(doc(db, 'users', uid), customerData(uid)));
    });

    it('B. Professional signup succeeds with real role-specific fields', async () => {
      const uid = 'professional_ok';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertSucceeds(setDoc(doc(db, 'users', uid), professionalData(uid)));
    });

    it('C. Contractor signup succeeds with real role-specific fields', async () => {
      const uid = 'contractor_ok';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertSucceeds(setDoc(doc(db, 'users', uid), contractorData(uid)));
    });

    it('D1. denied when authenticated uid differs from document id', async () => {
      // auth uid 'userA' writes to users/userB — request.auth.uid == userId fails
      // regardless of the id field's own value.
      const db = testEnv.authenticatedContext('userA').firestore();
      await assertFails(setDoc(doc(db, 'users', 'userB'), customerData('userA')));
    });

    // NOTE: because "request.auth.uid == userId" is already required, the two
    // remaining checks "id == userId" and "id == request.auth.uid" become the
    // same boolean condition whenever auth.uid == userId (as in every other
    // scenario below) — there is no way to violate one without violating the
    // other in that case. This single test therefore exercises both clauses
    // together; see report item J for the full explanation.
    it('D2/D3. denied when the internal id field does not match userId/auth.uid', async () => {
      const uid = 'customer_badid';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(setDoc(doc(db, 'users', uid), customerData(uid, { id: 'someone_else' })));
    });

    it('D4. denied when role == admin', async () => {
      const uid = 'customer_admin_role';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(setDoc(doc(db, 'users', uid), customerData(uid, { role: 'admin' })));
    });

    it('D5. denied when role is unsupported', async () => {
      const uid = 'customer_bad_role';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(setDoc(doc(db, 'users', uid), customerData(uid, { role: 'superuser' })));
    });

    it('D6. denied when isBlocked == true', async () => {
      const uid = 'customer_blocked';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(setDoc(doc(db, 'users', uid), customerData(uid, { isBlocked: true })));
    });

    it('D7. denied when isDeleted == true', async () => {
      const uid = 'customer_deleted';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(setDoc(doc(db, 'users', uid), customerData(uid, { isDeleted: true })));
    });

    it('D8. denied when suspendedUntil is non-null', async () => {
      const uid = 'customer_suspended';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(setDoc(doc(db, 'users', uid), customerData(uid, { suspendedUntil: nowIso() })));
    });

    it('D9. denied when warnings is non-empty', async () => {
      const uid = 'customer_warned';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(setDoc(doc(db, 'users', uid), customerData(uid, { warnings: ['strike 1'] })));
    });

    it('D10. denied when rating is non-zero', async () => {
      const uid = 'customer_rated';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(setDoc(doc(db, 'users', uid), customerData(uid, { rating: 4.5 })));
    });

    it('D11. denied when totalJobs is non-zero', async () => {
      const uid = 'customer_jobs';
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(setDoc(doc(db, 'users', uid), customerData(uid, { totalJobs: 3 })));
    });
  });

  // ── self-update ─────────────────────────────────────────────────────────
  describe('self-update', () => {
    const custUid = 'self_customer';
    const proUid = 'self_pro';
    const conUid = 'self_contractor';
    const otherUid = 'self_other_customer';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custUid), customerData(custUid));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));
      });
    });

    it('Customer can update every allow-listed field', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'users', custUid), {
        fullName: 'New Name',
        phone: '0500000099',
        city: 'Haifa',
        streetNumber: '99',
        languages: ['en', 'ar'],
        preferredContactHours: ['morning'],
        favoriteServices: ['svc1'],
        avatar: 'https://example.com/a.png',
        ordersLastSeenAt: nowIso(),
      }));
    });

    it('Professional can update every allow-listed field', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'users', proUid), {
        fullName: 'New Pro Name',
        phone: '0500000098',
        workArea: 'south_country',
        city: 'south_country',
        experienceYears: 9,
        serviceDescription: 'Updated bio',
        languages: ['en'],
        workingDays: ['sunday', 'monday'],
        workStartTime: '08:00',
        workEndTime: '17:00',
        avatar: 'https://example.com/p.png',
        servicesList: [{ id: 's1', name: 'Fix', description: 'x', price: 50 }],
        specialties: ['plumbing', 'electric'],
        specialty: 'plumbing',
      }));
    });

    it('Contractor can update every Professional field plus companyName', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'users', conUid), {
        fullName: 'New Contractor Name',
        phone: '0500000097',
        workArea: 'haifa',
        city: 'haifa',
        experienceYears: 12,
        serviceDescription: 'Updated contractor bio',
        languages: ['ar'],
        workingDays: ['tuesday'],
        workStartTime: '09:00',
        workEndTime: '18:00',
        avatar: 'https://example.com/c.png',
        servicesList: [{ id: 's2', name: 'Build', description: 'y', price: 500 }],
        specialties: ['construction'],
        specialty: 'construction',
        companyName: 'Updated Co',
      }));
    });

    const protectedFieldCases = [
      ['role', 'professional'],
      ['id', 'someone_else'],
      ['isBlocked', true],
      ['isDeleted', true],
      ['suspendedUntil', nowIso()],
      ['warnings', ['strike']],
      ['rating', 4.9],
      ['totalJobs', 5],
      ['joinDate', nowIso()],
      ['secretAdminFlag', true], // synthetic unknown field — not in any allow-list
    ];

    protectedFieldCases.forEach(([field, value]) => {
      it(`Customer self-update denied when changing protected field "${field}"`, async () => {
        const db = testEnv.authenticatedContext(custUid).firestore();
        await assertFails(updateDoc(doc(db, 'users', custUid), { [field]: value }));
      });
    });

    it("a user cannot update another user's document", async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      await assertFails(updateDoc(doc(db, 'users', otherUid), { fullName: 'Hacked' }));
    });
  });

  // ── admin update ────────────────────────────────────────────────────────
  describe('admin update', () => {
    const adminUid = 'admin_1';
    const targetUid = 'admin_target_customer';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'users', targetUid), customerData(targetUid));
      });
    });

    it('Admin can update currently-used Admin-managed fields on another user', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'users', targetUid), {
        fullName: 'Admin Edited Name',
        phone: '0500000090',
        city: 'Jerusalem',
      }));
      await assertSucceeds(updateDoc(doc(db, 'users', targetUid), { isBlocked: true }));
      await assertSucceeds(updateDoc(doc(db, 'users', targetUid), { suspendedUntil: nowIso() }));
      await assertSucceeds(updateDoc(doc(db, 'users', targetUid), {
        isDeleted: true,
        deletedAt: nowIso(),
      }));
    });

    it('Admin can update Professional/Contractor-managed fields on a provider target', async () => {
      const provUid = 'admin_target_provider';
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users', provUid), contractorData(provUid));
      });
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'users', provUid), {
        workArea: 'jerusalem',
        specialties: ['electric'],
        servicesList: [{ id: 's3', name: 'Wiring', description: 'z', price: 200 }],
        companyName: 'Admin Updated Co',
      }));
    });

    it("Admin cannot change the target user's role (immutable)", async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'users', targetUid), { role: 'professional' }));
    });

    it('document delete is denied for a regular user (self-delete)', async () => {
      const db = testEnv.authenticatedContext(targetUid).firestore();
      await assertFails(deleteDoc(doc(db, 'users', targetUid)));
    });

    it('document delete is denied for Admin', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(deleteDoc(doc(db, 'users', targetUid)));
    });
  });

  // ── read compatibility ──────────────────────────────────────────────────
  describe('read compatibility', () => {
    const uid = 'read_customer';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users', uid), customerData(uid));
      });
    });

    it('unauthenticated get of users/{uid} succeeds', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertSucceeds(getDoc(doc(db, 'users', uid)));
    });

    it('unauthenticated collection read of users succeeds', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertSucceeds(getDocs(collection(db, 'users')));
    });

    // allow read: if true — the rule does not branch on the reader's own
    // role, so these four labeled cases all exercise the same universal
    // read grant under four different authenticated identities.
    ['customer', 'professional', 'contractor', 'admin'].forEach((role) => {
      it(`authenticated ${role} read of users/{uid} succeeds`, async () => {
        const readerUid = `reader_${role}`;
        const db = testEnv.authenticatedContext(readerUid).firestore();
        await assertSucceeds(getDoc(doc(db, 'users', uid)));
        await assertSucceeds(getDocs(collection(db, 'users')));
      });
    });
  });
});
