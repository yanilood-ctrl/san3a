'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  customerData, professionalData, contractorData, adminData, workerData,
} = require('./fixtures');

describe('contractor_workers/{workerId} security rules', function () {
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
    const conA = 'cw_read_conA';
    const conB = 'cw_read_conB';
    const custUid = 'cw_read_cust';
    const proUid = 'cw_read_pro';
    const adminUid = 'cw_read_admin';
    const workerId = 'cw_read_worker1';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', conA), contractorData(conA));
        await setDoc(doc(db, 'users', conB), contractorData(conB));
        await setDoc(doc(db, 'users', custUid), customerData(custUid));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'contractor_workers', workerId),
          workerData(conA, workerId));
      });
    });

    it('owning Contractor single read succeeds', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(getDoc(doc(db, 'contractor_workers', workerId)));
    });

    it("owning Contractor's real where('contractorId', isEqualTo: uid) query succeeds", async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      const q = query(collection(db, 'contractor_workers'), where('contractorId', '==', conA));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 1) {
        throw new Error(`Expected 1 worker for conA, got ${snap.size}`);
      }
    });

    it('another Contractor read fails', async () => {
      const db = testEnv.authenticatedContext(conB).firestore();
      await assertFails(getDoc(doc(db, 'contractor_workers', workerId)));
    });

    it("another Contractor's filtered query on someone else's contractorId fails", async () => {
      const db = testEnv.authenticatedContext(conB).firestore();
      const q = query(collection(db, 'contractor_workers'), where('contractorId', '==', conA));
      await assertFails(getDocs(q));
    });

    it('Customer read succeeds (real ProviderProfileScreen worker-roster path)', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'contractor_workers', workerId)));
    });

    it("Customer's real contractorWorkersByIdProvider query succeeds", async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      const q = query(collection(db, 'contractor_workers'), where('contractorId', '==', conA));
      await assertSucceeds(getDocs(q));
    });

    it('Professional read fails (no real app path)', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(getDoc(doc(db, 'contractor_workers', workerId)));
    });

    it('unauthenticated read fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'contractor_workers', workerId)));
    });

    it('Admin single-document read succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'contractor_workers', workerId)));
    });

    it('Admin unfiltered collection query succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDocs(collection(db, 'contractor_workers')));
    });
  });

  // ── create ──────────────────────────────────────────────────────────────
  describe('create', () => {
    const conA = 'cw_create_conA';
    const conB = 'cw_create_conB';
    const custUid = 'cw_create_cust';
    const proUid = 'cw_create_pro';
    const adminUid = 'cw_create_admin';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', conA), contractorData(conA));
        await setDoc(doc(db, 'users', conB), contractorData(conB));
        await setDoc(doc(db, 'users', custUid), customerData(custUid));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
      });
    });

    it('valid Contractor worker create succeeds (real ContractorWorkersService.add shape)', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertSucceeds(setDoc(ref, workerData(conA, ref.id)));
    });

    // Reproduces ContractorWorkersService.add() byte-for-byte, in the exact
    // order the real Dart code builds it (app_providers.dart):
    //   final docRef = worker.id.isEmpty ? _col.doc() : _col.doc(worker.id);
    //   await docRef.set({
    //     ...worker.toFirestoreMap(...),   // id: worker.id, which is '' here
    //     'id': docRef.id,                 // <- LAST key wins: overrides the
    //     'createdAt': FieldValue.serverTimestamp(),   //    '' from the spread
    //     'updatedAt': FieldValue.serverTimestamp(),
    //   });
    // The real Add Worker form always constructs a new WorkerModel with
    // `id: existing?.id ?? ''` when adding (existing == null), so
    // worker.id.isEmpty is always true on create and _col.doc() (an
    // auto-generated ref) is always used. The map spread alone would write
    // id: '', but the explicit 'id': docRef.id entry that follows it in the
    // same map literal overwrites that — so the document Firestore actually
    // receives always has id === docRef.id, never ''. This test builds the
    // payload the same two-step way (spread, then override) instead of
    // assuming that end result via a fixture convenience param.
    it("reproduces the real add() two-step id override byte-for-byte (spread '' then override with docRef.id)", async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      const docRef = doc(collection(db, 'contractor_workers'));

      // Step 1 — worker.toFirestoreMap(...) called on the pre-write
      // WorkerModel, whose id is still '' at this point.
      const preOverrideMap = workerData(conA, '');
      if (preOverrideMap.id !== '') {
        throw new Error('Test setup drifted: expected the pre-override map to have id === "".');
      }

      // Step 2 — the same map literal then overrides 'id' with docRef.id
      // (Dart: last duplicate key in a map literal wins), alongside the two
      // serverTimestamp() fields.
      const realAddPayload = {
        ...preOverrideMap,
        id: docRef.id,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      if (realAddPayload.id !== docRef.id || realAddPayload.id === '') {
        throw new Error('Test setup does not reproduce the real add() override semantics.');
      }

      await assertSucceeds(setDoc(docRef, realAddPayload));
    });

    it('spoofed contractorId fails', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertFails(setDoc(ref, workerData(conB, ref.id)));
    });

    it("id field not matching the real document id fails", async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertFails(setDoc(ref, workerData(conA, 'some_other_id')));
    });

    it('another Contractor creating under someone else\'s contractorId fails', async () => {
      const db = testEnv.authenticatedContext(conB).firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertFails(setDoc(ref, workerData(conA, ref.id)));
    });

    it('Customer create fails (no legitimate Customer create path)', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertFails(setDoc(ref, workerData(custUid, ref.id)));
    });

    it('Professional create fails (no legitimate Professional create path)', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertFails(setDoc(ref, workerData(proUid, ref.id)));
    });

    it('Admin create fails (no legitimate Admin create path proven)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertFails(setDoc(ref, workerData(adminUid, ref.id)));
    });

    it('unauthenticated create fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertFails(setDoc(ref, workerData(conA, ref.id)));
    });

    it('unknown field fails (strict key validation)', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertFails(setDoc(ref, workerData(conA, ref.id, { secretField: true })));
    });

    it('non-zero initial rating fails', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertFails(setDoc(ref, workerData(conA, ref.id, { rating: 4.5 })));
    });

    it('non-zero initial completedJobs fails', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertFails(setDoc(ref, workerData(conA, ref.id, { completedJobs: 10 })));
    });

    it('invalid status value fails', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      const ref = doc(collection(db, 'contractor_workers'));
      await assertFails(setDoc(ref, workerData(conA, ref.id, { status: 'on_vacation' })));
    });
  });

  // ── update ──────────────────────────────────────────────────────────────
  describe('update', () => {
    const conA = 'cw_upd_conA';
    const conB = 'cw_upd_conB';
    const custUid = 'cw_upd_cust';
    const proUid = 'cw_upd_pro';
    const adminUid = 'cw_upd_admin';
    const workerId = 'cw_upd_worker1';
    // Built once and reused for both the initial doc and the "real edit"
    // full-map re-send below, so createdAt (and every other untouched field)
    // stays byte-identical — exactly what ContractorWorkersService.update()
    // does (it always resends the whole toFirestoreMap, but createdAt is
    // never part of that map to begin with, so its stored value never
    // moves).
    const baseWorker = workerData(conA, workerId);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', conA), contractorData(conA));
        await setDoc(doc(db, 'users', conB), contractorData(conB));
        await setDoc(doc(db, 'users', custUid), customerData(custUid));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'contractor_workers', workerId), baseWorker);
      });
    });

    it("owning Contractor's real edit (ContractorWorkersService.update shape) succeeds", async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(setDoc(doc(db, 'contractor_workers', workerId), {
        ...baseWorker,
        fullName: 'Renamed Worker',
        phone: '0500000111',
        status: 'busy',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('another Contractor edit fails', async () => {
      const db = testEnv.authenticatedContext(conB).firestore();
      await assertFails(updateDoc(doc(db, 'contractor_workers', workerId), {
        fullName: 'Hacked', updatedAt: new Date().toISOString(),
      }));
    });

    it('Customer edit fails', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      await assertFails(updateDoc(doc(db, 'contractor_workers', workerId), {
        fullName: 'Hacked', updatedAt: new Date().toISOString(),
      }));
    });

    it('Professional edit fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'contractor_workers', workerId), {
        fullName: 'Hacked', updatedAt: new Date().toISOString(),
      }));
    });

    it('unauthenticated edit fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(updateDoc(doc(db, 'contractor_workers', workerId), {
        fullName: 'Hacked',
      }));
    });

    it("owning Contractor changing contractorId fails", async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(updateDoc(doc(db, 'contractor_workers', workerId), {
        contractorId: conB, updatedAt: new Date().toISOString(),
      }));
    });

    it("owning Contractor changing createdAt fails", async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(updateDoc(doc(db, 'contractor_workers', workerId), {
        createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it("owning Contractor changing an unknown/protected field (rating) fails", async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(updateDoc(doc(db, 'contractor_workers', workerId), {
        rating: 5, updatedAt: new Date().toISOString(),
      }));
    });

    it("owning Contractor sending an unrecognized field fails", async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(updateDoc(doc(db, 'contractor_workers', workerId), {
        secretField: true, updatedAt: new Date().toISOString(),
      }));
    });

    it("real Admin edit (ContractorWorkersService.updateFields shape) succeeds", async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'contractor_workers', workerId), {
        fullName: 'Admin Renamed', status: 'offline',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin changing contractorId fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'contractor_workers', workerId), {
        contractorId: conB, updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin changing createdAt fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'contractor_workers', workerId), {
        createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it("Admin sending a contractorName change fails (not part of the real Admin edit dialog)", async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'contractor_workers', workerId), {
        contractorName: 'Admin Hacked Co', updatedAt: new Date().toISOString(),
      }));
    });
  });

  // ── delete ──────────────────────────────────────────────────────────────
  describe('delete', () => {
    const conA = 'cw_del_conA';
    const conB = 'cw_del_conB';
    const custUid = 'cw_del_cust';
    const proUid = 'cw_del_pro';
    const adminUid = 'cw_del_admin';
    const workerId = 'cw_del_worker1';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', conA), contractorData(conA));
        await setDoc(doc(db, 'users', conB), contractorData(conB));
        await setDoc(doc(db, 'users', custUid), customerData(custUid));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'contractor_workers', workerId),
          workerData(conA, workerId));
      });
    });

    it('owning Contractor delete succeeds', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(deleteDoc(doc(db, 'contractor_workers', workerId)));
    });

    it('another Contractor delete fails', async () => {
      const db = testEnv.authenticatedContext(conB).firestore();
      await assertFails(deleteDoc(doc(db, 'contractor_workers', workerId)));
    });

    it('Customer delete fails', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      await assertFails(deleteDoc(doc(db, 'contractor_workers', workerId)));
    });

    it('Professional delete fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(deleteDoc(doc(db, 'contractor_workers', workerId)));
    });

    it('unauthenticated delete fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(deleteDoc(doc(db, 'contractor_workers', workerId)));
    });

    it('Admin delete fails (no real Admin delete path exists)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(deleteDoc(doc(db, 'contractor_workers', workerId)));
    });
  });

  // ── legacy document compatibility ───────────────────────────────────────
  // WorkerModel.fromFirestore() falls back defensively for phone/email/city/
  // workArea/rating/completedJobs/experienceYears/workHours/workStartTime/
  // workEndTime/status/skills/description/contractorId/id when missing —
  // proving older worker documents may lack these fields entirely. The
  // rules must not hard-fail (runtime error) on such documents.
  describe('legacy worker documents (missing-field fallback compatibility)', () => {
    const conA = 'cw_legacy_conA';
    const custUid = 'cw_legacy_cust';
    const adminUid = 'cw_legacy_admin';
    const workerId = 'cw_legacy_worker1';

    // A pre-Phase-3A document: only the fields the very first version of the
    // Add Worker form would have written. No 'id', 'contractorName',
    // 'createdAt', 'workArea', 'workStartTime', 'workEndTime', 'description'.
    const legacyDoc = {
      contractorId: conA,
      fullName: 'Legacy Worker',
      specialty: 'plumbing',
      specialties: ['plumbing'],
      phone: '0500000222',
      email: 'legacy@test.san3a',
      city: 'Haifa',
      languages: ['ar'],
      experienceYears: 2,
      workHours: '09:00 – 17:00',
      status: 'available',
      rating: 0,
      completedJobs: 0,
      skills: [],
    };

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', conA), contractorData(conA));
        await setDoc(doc(db, 'users', custUid), customerData(custUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'contractor_workers', workerId), legacyDoc);
      });
    });

    it('owning Contractor can still read a legacy worker document', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(getDoc(doc(db, 'contractor_workers', workerId)));
    });

    it("owning Contractor's real filtered query still returns a legacy worker document", async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      const q = query(collection(db, 'contractor_workers'), where('contractorId', '==', conA));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 1) {
        throw new Error(`Expected 1 legacy worker for conA, got ${snap.size}`);
      }
    });

    it('Customer can still read a legacy worker document', async () => {
      const db = testEnv.authenticatedContext(custUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'contractor_workers', workerId)));
    });

    it('Admin can still read a legacy worker document', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'contractor_workers', workerId)));
    });

    it('owning Contractor can still edit a legacy worker document via the real edit shape', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(setDoc(doc(db, 'contractor_workers', workerId), {
        ...legacyDoc,
        id: workerId,
        contractorName: 'Test Contracting Co',
        workArea: 'Haifa',
        fullName: 'Legacy Worker Renamed',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin can still edit a legacy worker document via the real Admin edit shape', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'contractor_workers', workerId), {
        fullName: 'Legacy Worker Admin-Renamed',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('owning Contractor can still delete a legacy worker document', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(deleteDoc(doc(db, 'contractor_workers', workerId)));
    });
  });
});
