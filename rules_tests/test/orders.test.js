'use strict';

const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc,
  deleteField, arrayUnion, arrayRemove,
} = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const {
  customerData, professionalData, contractorData, adminData,
  orderData, orderDocId, workerData,
} = require('./fixtures');

describe('orders/{orderId} security rules', function () {
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
    const custA = 'ord_read_custA';
    const custB = 'ord_read_custB';
    const proUid = 'ord_read_pro';
    const conUid = 'ord_read_con';
    const otherProUid = 'ord_read_other_pro';
    const adminUid = 'ord_read_admin';
    const orderIdPro = 'ord_read_order_pro';
    const orderIdCon = 'ord_read_order_con';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', otherProUid), professionalData(otherProUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'orders', orderIdPro),
          orderData(custA, proUid, 'professional', orderIdPro));
        await setDoc(doc(db, 'orders', orderIdCon),
          orderData(custA, conUid, 'contractor', orderIdCon));
      });
    });

    it('owning Customer single read succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(db, 'orders', orderIdPro)));
    });

    it("Customer's real where('customerId', isEqualTo: uid) query succeeds", async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const q = query(collection(db, 'orders'), where('customerId', '==', custA));
      const snap = await assertSucceeds(getDocs(q));
      if (snap.size !== 2) throw new Error(`Expected 2 orders, got ${snap.size}`);
    });

    it('assigned Professional single read succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'orders', orderIdPro)));
    });

    it('assigned Contractor single read succeeds', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'orders', orderIdCon)));
    });

    it("Professional/Contractor real where('providerId', isEqualTo: uid) query succeeds", async () => {
      const dbPro = testEnv.authenticatedContext(proUid).firestore();
      const qPro = query(collection(dbPro, 'orders'), where('providerId', '==', proUid));
      const snapPro = await assertSucceeds(getDocs(qPro));
      if (snapPro.size !== 1) throw new Error(`Expected 1 order for pro, got ${snapPro.size}`);

      const dbCon = testEnv.authenticatedContext(conUid).firestore();
      const qCon = query(collection(dbCon, 'orders'), where('providerId', '==', conUid));
      const snapCon = await assertSucceeds(getDocs(qCon));
      if (snapCon.size !== 1) throw new Error(`Expected 1 order for con, got ${snapCon.size}`);
    });

    it('unrelated Customer read fails', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(getDoc(doc(db, 'orders', orderIdPro)));
    });

    it('unrelated Professional read fails', async () => {
      const db = testEnv.authenticatedContext(otherProUid).firestore();
      await assertFails(getDoc(doc(db, 'orders', orderIdPro)));
    });

    it("unrelated Professional's filtered query on someone else's providerId fails", async () => {
      const db = testEnv.authenticatedContext(otherProUid).firestore();
      const q = query(collection(db, 'orders'), where('providerId', '==', proUid));
      await assertFails(getDocs(q));
    });

    it('unauthenticated read fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'orders', orderIdPro)));
    });

    it('Admin single-document read succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(getDoc(doc(db, 'orders', orderIdPro)));
    });

    it('Admin unfiltered collection query succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const snap = await assertSucceeds(getDocs(collection(db, 'orders')));
      if (snap.size !== 2) throw new Error(`Expected 2 orders for admin, got ${snap.size}`);
    });
  });

  // ── create ──────────────────────────────────────────────────────────────
  describe('create', () => {
    const custA = 'ord_create_custA';
    const proUid = 'ord_create_pro';
    const conUid = 'ord_create_con';
    const adminUid = 'ord_create_admin';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
      });
    });

    it('valid selected-service order create succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertSucceeds(setDoc(doc(db, 'orders', id),
        orderData(custA, proUid, 'professional', id)));
    });

    it('valid Custom Request order create (no selectedService* fields) succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      const data = orderData(custA, conUid, 'contractor', id);
      delete data.selectedServiceId;
      delete data.selectedServiceName;
      delete data.selectedServicePrice;
      delete data.selectedServices;
      await assertSucceeds(setDoc(doc(db, 'orders', id), data));
    });

    it('spoofed customerId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData('someone_else', proUid, 'professional', id)));
    });

    it('id not matching the real document id fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, proUid, 'professional', 'wrong_id')));
    });

    it('Professional create fails (only Customers create orders)', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(proUid, conUid, 'contractor', id)));
    });

    it('Contractor create fails', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(conUid, proUid, 'professional', id)));
    });

    it('Admin create fails (no legitimate Admin create path)', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(adminUid, proUid, 'professional', id)));
    });

    it('unauthenticated create fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, proUid, 'professional', id)));
    });

    it('nonexistent providerId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, 'ghost_provider', 'professional', id)));
    });

    it("providerId belonging to a Customer (wrong role) fails", async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, custA, 'customer', id)));
    });

    it('providerRole mismatch (provider is contractor, order claims professional) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, conUid, 'professional', id)));
    });

    it('providerId equal to customerId (self-order) fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, custA, 'professional', id, { customerId: custA, providerId: custA })));
    });

    it('non-pending initial status fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, proUid, 'professional', id, { status: 'inProgress' })));
    });

    it('invalid priority value fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, proUid, 'professional', id, { priority: 'super-urgent' })));
    });

    it('unknown field fails (strict key validation)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, proUid, 'professional', id, { secretField: true })));
    });

    it('pre-populated assignedWorkerId at creation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, conUid, 'contractor', id, { assignedWorkerId: 'w1' })));
    });

    it('pre-populated acceptedBy at creation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, proUid, 'professional', id, { acceptedBy: 'professional' })));
    });

    it('pre-populated editedBy (Admin field) at creation fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      const id = orderDocId();
      await assertFails(setDoc(doc(db, 'orders', id),
        orderData(custA, proUid, 'professional', id, { editedBy: 'admin' })));
    });
  });

  // ── update: Customer branches ────────────────────────────────────────────
  describe('update — Customer', () => {
    const custA = 'ord_updc_custA';
    const custB = 'ord_updc_custB';
    const proUid = 'ord_updc_pro';
    let pendingId, inProgressId, completedId, cancelledId;

    beforeEach(async () => {
      pendingId = orderDocId() + '_p';
      inProgressId = orderDocId() + '_i';
      completedId = orderDocId() + '_c';
      cancelledId = orderDocId() + '_x';
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', custB), customerData(custB));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'orders', pendingId),
          orderData(custA, proUid, 'professional', pendingId, { status: 'pending' }));
        await setDoc(doc(db, 'orders', inProgressId),
          orderData(custA, proUid, 'professional', inProgressId, { status: 'inProgress' }));
        await setDoc(doc(db, 'orders', completedId),
          orderData(custA, proUid, 'professional', completedId, { status: 'completed' }));
        await setDoc(doc(db, 'orders', cancelledId),
          orderData(custA, proUid, 'professional', cancelledId, { status: 'cancelled' }));
      });
    });

    it('content edit while pending succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        title: 'Renamed', description: 'New desc', area: 'Haifa',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('content edit while inProgress succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', inProgressId), {
        title: 'Renamed again', updatedAt: new Date().toISOString(),
      }));
    });

    it('content edit while completed fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', completedId), {
        title: 'Too late', updatedAt: new Date().toISOString(),
      }));
    });

    it('content edit while cancelled fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', cancelledId), {
        title: 'Too late', updatedAt: new Date().toISOString(),
      }));
    });

    it('selectedServices removal (delete) while pending succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        selectedServices: deleteField(),
        selectedServiceName: deleteField(),
        selectedServicePrice: deleteField(),
        selectedServiceId: deleteField(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('image replace shape succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        imageUrls: ['https://example.test/new.jpg'],
        updatedAt: new Date().toISOString(),
      }));
    });

    it('image append (arrayUnion) shape succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        imageUrls: arrayUnion('https://example.test/second.jpg'),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('image remove (arrayRemove) shape succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'orders', pendingId), {
          imageUrls: ['https://example.test/a.jpg'],
        });
      });
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        imageUrls: arrayRemove('https://example.test/a.jpg'),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('cancel while pending succeeds', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        status: 'cancelled', cancelledBy: 'customer',
        cancelledAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('cancel while inProgress fails (real canCancel gate is pending-only)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
        status: 'cancelled', cancelledBy: 'customer',
        cancelledAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('cancel with wrong cancelledBy value fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        status: 'cancelled', cancelledBy: 'admin',
        cancelledAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('another Customer cannot edit', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        title: 'Hacked', updatedAt: new Date().toISOString(),
      }));
    });

    it('Customer cannot approve/accept their own order', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        status: 'inProgress', acceptedBy: 'customer',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('Customer cannot complete their own order', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
        status: 'completed', completedBy: 'customer',
        completedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('Customer cannot assign a worker', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        assignedWorkerId: 'w1', assignedWorkerName: 'W1',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('Customer changing customerId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        customerId: custB, updatedAt: new Date().toISOString(),
      }));
    });

    it('Customer changing providerId fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        providerId: custB, updatedAt: new Date().toISOString(),
      }));
    });

    it('Customer changing createdAt fails', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('failed write leaves the document unchanged', async () => {
      const db = testEnv.authenticatedContext(custB).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        title: 'Hacked', updatedAt: new Date().toISOString(),
      }));
      let snap;
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        snap = await getDoc(doc(ctx.firestore(), 'orders', pendingId));
      });
      if (snap.data().title === 'Hacked') {
        throw new Error('Document was mutated despite a denied write.');
      }
    });
  });

  // ── update: Professional branches ────────────────────────────────────────
  describe('update — Professional', () => {
    const custA = 'ord_updp_cust';
    const proUid = 'ord_updp_pro';
    const otherProUid = 'ord_updp_other_pro';
    const conUid = 'ord_updp_con';
    let pendingId, inProgressId;

    beforeEach(async () => {
      pendingId = orderDocId() + '_p';
      inProgressId = orderDocId() + '_i';
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', otherProUid), professionalData(otherProUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'orders', pendingId),
          orderData(custA, proUid, 'professional', pendingId, { status: 'pending' }));
        await setDoc(doc(db, 'orders', inProgressId),
          orderData(custA, proUid, 'professional', inProgressId, { status: 'inProgress' }));
      });
    });

    it('accept (pending -> inProgress) succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        status: 'inProgress', acceptedBy: 'professional',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('accept with wrong acceptedBy value fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        status: 'inProgress', acceptedBy: 'contractor',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('reject (pending -> cancelled) succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        status: 'cancelled', cancelledBy: 'professional',
        cancelledAt: new Date().toISOString(), rejectReason: 'too busy',
        cancelReason: 'too busy', updatedAt: new Date().toISOString(),
      }));
    });

    it('complete (inProgress -> completed) succeeds', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', inProgressId), {
        status: 'completed', completedBy: 'professional',
        completedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('complete from pending (wrong current status) fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        status: 'completed', completedBy: 'professional',
        completedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('unrelated Professional cannot accept', async () => {
      const db = testEnv.authenticatedContext(otherProUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        status: 'inProgress', acceptedBy: 'professional',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('a Contractor account cannot use the Professional accept shape even on their own order', async () => {
      const db = testEnv.authenticatedContext(conUid).firestore();
      const id = orderDocId();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'orders', id),
          orderData(custA, conUid, 'contractor', id, { status: 'pending' }));
      });
      await assertFails(updateDoc(doc(db, 'orders', id), {
        status: 'inProgress', acceptedBy: 'professional',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('Professional cannot edit content fields', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        title: 'Hacked', updatedAt: new Date().toISOString(),
      }));
    });

    it('Professional cannot assign a worker', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        assignedWorkerId: 'w1', updatedAt: new Date().toISOString(),
      }));
    });

    it('Professional changing providerId fails', async () => {
      const db = testEnv.authenticatedContext(proUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        providerId: otherProUid, status: 'inProgress', acceptedBy: 'professional',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });
  });

  // ── update: Contractor branches (incl. worker assignment) ───────────────
  describe('update — Contractor', () => {
    const custA = 'ord_updk_cust';
    const conA = 'ord_updk_conA';
    const conB = 'ord_updk_conB';
    const workerA1 = 'ord_updk_workerA1';
    const workerA2 = 'ord_updk_workerA2';
    const workerA3 = 'ord_updk_workerA3';
    const workerA4 = 'ord_updk_workerA4';
    const workerA5 = 'ord_updk_workerA5';
    const workerA6 = 'ord_updk_workerA6';
    const workerB1 = 'ord_updk_workerB1';
    let pendingId, inProgressId, completedId, cancelledId;

    beforeEach(async () => {
      pendingId = orderDocId() + '_p';
      inProgressId = orderDocId() + '_i';
      completedId = orderDocId() + '_c';
      cancelledId = orderDocId() + '_x';
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', conA), contractorData(conA));
        await setDoc(doc(db, 'users', conB), contractorData(conB));
        await setDoc(doc(db, 'contractor_workers', workerA1), workerData(conA, workerA1));
        await setDoc(doc(db, 'contractor_workers', workerA2), workerData(conA, workerA2, { fullName: 'Worker A2' }));
        await setDoc(doc(db, 'contractor_workers', workerA3), workerData(conA, workerA3, { fullName: 'Worker A3' }));
        await setDoc(doc(db, 'contractor_workers', workerA4), workerData(conA, workerA4, { fullName: 'Worker A4' }));
        await setDoc(doc(db, 'contractor_workers', workerA5), workerData(conA, workerA5, { fullName: 'Worker A5' }));
        await setDoc(doc(db, 'contractor_workers', workerA6), workerData(conA, workerA6, { fullName: 'Worker A6' }));
        await setDoc(doc(db, 'contractor_workers', workerB1), workerData(conB, workerB1, { fullName: 'Worker B1' }));
        await setDoc(doc(db, 'orders', pendingId),
          orderData(custA, conA, 'contractor', pendingId, { status: 'pending' }));
        await setDoc(doc(db, 'orders', inProgressId),
          orderData(custA, conA, 'contractor', inProgressId, { status: 'inProgress' }));
        await setDoc(doc(db, 'orders', completedId),
          orderData(custA, conA, 'contractor', completedId, { status: 'completed' }));
        await setDoc(doc(db, 'orders', cancelledId),
          orderData(custA, conA, 'contractor', cancelledId, { status: 'cancelled' }));
      });
    });

    function workerEntry(id, name) {
      return { id, name, specialties: [] };
    }

    it('accept (pending -> inProgress) succeeds', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        status: 'inProgress', acceptedBy: 'contractor',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('reject (pending -> cancelled) succeeds', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        status: 'cancelled', cancelledBy: 'contractor',
        cancelledAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('complete (inProgress -> completed) succeeds', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', inProgressId), {
        status: 'completed', completedBy: 'contractor',
        completedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('single-worker assignment while inProgress (own worker) succeeds', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', inProgressId), {
        assignedWorkerId: workerA1, assignedWorkerName: 'Test Worker',
        assignedWorkers: [{ id: workerA1, name: 'Test Worker', specialties: ['plumbing'] }],
        updatedAt: new Date().toISOString(),
      }));
    });

    it('assigning a worker owned by a different Contractor fails', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
        assignedWorkerId: workerB1, assignedWorkerName: 'Worker B1',
        assignedWorkers: [{ id: workerB1, name: 'Worker B1', specialties: [] }],
        updatedAt: new Date().toISOString(),
      }));
    });

    it('assigning a nonexistent worker id fails', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
        assignedWorkerId: 'ghost_worker', assignedWorkerName: 'Ghost',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('assigning while pending flips status to inProgress with acceptedBy=contractor', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        assignedWorkerId: workerA1, assignedWorkerName: 'Test Worker',
        assignedWorkers: [{ id: workerA1, name: 'Test Worker', specialties: ['plumbing'] }],
        status: 'inProgress', acceptedBy: 'contractor',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('reassigning (changing) the worker while inProgress succeeds', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'orders', inProgressId), {
          assignedWorkerId: workerA1, assignedWorkerName: 'Test Worker',
          assignedWorkers: [{ id: workerA1, name: 'Test Worker', specialties: [] }],
        });
      });
      await assertSucceeds(updateDoc(doc(db, 'orders', inProgressId), {
        assignedWorkerId: workerA2, assignedWorkerName: 'Worker A2',
        assignedWorkers: [{ id: workerA2, name: 'Worker A2', specialties: [] }],
        updatedAt: new Date().toISOString(),
      }));
    });

    it('unassign-all-and-return-to-pending succeeds', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'orders', inProgressId), {
          assignedWorkerId: workerA1, assignedWorkerName: 'Test Worker',
          assignedWorkers: [{ id: workerA1, name: 'Test Worker', specialties: [] }],
          acceptedBy: 'contractor', acceptedAt: new Date().toISOString(),
        });
      });
      await assertSucceeds(updateDoc(doc(db, 'orders', inProgressId), {
        status: 'pending',
        assignedWorkers: deleteField(),
        assignedWorkerId: deleteField(),
        assignedWorkerName: deleteField(),
        acceptedBy: deleteField(),
        acceptedAt: deleteField(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('worker assignment on a completed order fails', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', completedId), {
        assignedWorkerId: workerA1, assignedWorkerName: 'Test Worker',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('worker assignment on a cancelled order fails', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', cancelledId), {
        assignedWorkerId: workerA1, assignedWorkerName: 'Test Worker',
        updatedAt: new Date().toISOString(),
      }));
    });

    it('mismatched assignedWorkers[0].id vs assignedWorkerId mirror fails', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
        assignedWorkerId: workerA1,
        assignedWorkers: [{ id: workerA2, name: 'Worker A2', specialties: [] }],
        updatedAt: new Date().toISOString(),
      }));
    });

    // Phase 3B3 closes the Phase 3B1-reported limitation: assignedWorkers[]
    // is now validated at every index up to the approved product maximum
    // (5 workers/order), so an unrelated Contractor's worker anywhere in the
    // list — not just past index 0 — is denied.
    it('Phase 3B3: a second assignedWorkers[] entry owned by an unrelated Contractor is now denied', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
        assignedWorkerId: workerA1,
        assignedWorkerName: 'Test Worker',
        assignedWorkers: [
          workerEntry(workerA1, 'Test Worker'),
          workerEntry(workerB1, 'Worker B1 (unrelated contractor)'),
        ],
        updatedAt: new Date().toISOString(),
      }));
    });

    it('unrelated Contractor cannot accept/assign on someone else\'s order', async () => {
      const db = testEnv.authenticatedContext(conB).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        status: 'inProgress', acceptedBy: 'contractor',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('Contractor cannot edit content fields', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        title: 'Hacked', updatedAt: new Date().toISOString(),
      }));
    });

    // ── Phase 3B3: multi-worker validation (max 5 per order) ───────────────
    describe('Phase 3B3: assignedWorkers[] size/index/ownership validation', () => {
      it('assigning exactly 5 valid owned workers succeeds', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertSucceeds(updateDoc(doc(db, 'orders', inProgressId), {
          assignedWorkerId: workerA1,
          assignedWorkerName: 'Test Worker',
          assignedWorkers: [
            workerEntry(workerA1, 'Test Worker'),
            workerEntry(workerA2, 'Worker A2'),
            workerEntry(workerA3, 'Worker A3'),
            workerEntry(workerA4, 'Worker A4'),
            workerEntry(workerA5, 'Worker A5'),
          ],
          updatedAt: new Date().toISOString(),
        }));
      });

      it('a list of 6 (all owned) workers is denied', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
          assignedWorkerId: workerA1,
          assignedWorkerName: 'Test Worker',
          assignedWorkers: [
            workerEntry(workerA1, 'Test Worker'),
            workerEntry(workerA2, 'Worker A2'),
            workerEntry(workerA3, 'Worker A3'),
            workerEntry(workerA4, 'Worker A4'),
            workerEntry(workerA5, 'Worker A5'),
            workerEntry(workerA6, 'Worker A6'),
          ],
          updatedAt: new Date().toISOString(),
        }));
      });

      it('five valid workers plus an unrelated sixth worker is denied', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
          assignedWorkerId: workerA1,
          assignedWorkerName: 'Test Worker',
          assignedWorkers: [
            workerEntry(workerA1, 'Test Worker'),
            workerEntry(workerA2, 'Worker A2'),
            workerEntry(workerA3, 'Worker A3'),
            workerEntry(workerA4, 'Worker A4'),
            workerEntry(workerB1, 'Worker B1 (unrelated contractor)'),
          ],
          updatedAt: new Date().toISOString(),
        }));
      });

      [1, 2, 3, 4].forEach((idx) => {
        it(`an unrelated Contractor's worker at index ${idx} is denied`, async () => {
          const db = testEnv.authenticatedContext(conA).firestore();
          const entries = [
            workerEntry(workerA1, 'Test Worker'),
            workerEntry(workerA2, 'Worker A2'),
            workerEntry(workerA3, 'Worker A3'),
            workerEntry(workerA4, 'Worker A4'),
            workerEntry(workerA5, 'Worker A5'),
          ];
          entries[idx] = workerEntry(workerB1, 'Worker B1 (unrelated contractor)');
          await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
            assignedWorkerId: workerA1,
            assignedWorkerName: 'Test Worker',
            assignedWorkers: entries,
            updatedAt: new Date().toISOString(),
          }));
        });
      });

      it('a missing worker document at index 2 is denied', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
          assignedWorkerId: workerA1,
          assignedWorkerName: 'Test Worker',
          assignedWorkers: [
            workerEntry(workerA1, 'Test Worker'),
            workerEntry(workerA2, 'Worker A2'),
            workerEntry('ghost_worker_does_not_exist', 'Ghost'),
          ],
          updatedAt: new Date().toISOString(),
        }));
      });

      it('the empty-list unassign flow still succeeds (regression)', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await testEnv.withSecurityRulesDisabled(async (ctx) => {
          await updateDoc(doc(ctx.firestore(), 'orders', inProgressId), {
            assignedWorkerId: workerA1, assignedWorkerName: 'Test Worker',
            assignedWorkers: [workerEntry(workerA1, 'Test Worker')],
          });
        });
        await assertSucceeds(updateDoc(doc(db, 'orders', inProgressId), {
          assignedWorkers: deleteField(),
          assignedWorkerId: deleteField(),
          assignedWorkerName: deleteField(),
          updatedAt: new Date().toISOString(),
        }));
      });

      it('a denied 6-worker write leaves the order document unchanged', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
          assignedWorkerId: workerA1,
          assignedWorkers: [
            workerEntry(workerA1, 'W1'), workerEntry(workerA2, 'W2'),
            workerEntry(workerA3, 'W3'), workerEntry(workerA4, 'W4'),
            workerEntry(workerA5, 'W5'), workerEntry(workerA6, 'W6'),
          ],
          updatedAt: new Date().toISOString(),
        }));
        let snap;
        await testEnv.withSecurityRulesDisabled(async (ctx) => {
          snap = await getDoc(doc(ctx.firestore(), 'orders', inProgressId));
        });
        if ('assignedWorkers' in snap.data()) {
          throw new Error('Order document was mutated despite a denied 6-worker write.');
        }
      });
    });

    // ── Phase 3B3: legacy (>5 workers) compatibility ───────────────────────
    describe('Phase 3B3: legacy order with more than 5 pre-existing workers', () => {
      let legacyManyWorkersId;

      beforeEach(async () => {
        legacyManyWorkersId = orderDocId() + '_legacy6';
        await testEnv.withSecurityRulesDisabled(async (ctx) => {
          await setDoc(doc(ctx.firestore(), 'orders', legacyManyWorkersId),
            orderData(custA, conA, 'contractor', legacyManyWorkersId, {
              status: 'inProgress',
              assignedWorkerId: workerA1,
              assignedWorkerName: 'Test Worker',
              assignedWorkers: [
                workerEntry(workerA1, 'W1'), workerEntry(workerA2, 'W2'),
                workerEntry(workerA3, 'W3'), workerEntry(workerA4, 'W4'),
                workerEntry(workerA5, 'W5'), workerEntry(workerA6, 'W6'),
              ],
            }));
        });
      });

      it('an unrelated valid action (complete) succeeds without touching assignedWorkers', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertSucceeds(updateDoc(doc(db, 'orders', legacyManyWorkersId), {
          status: 'completed', completedBy: 'contractor',
          completedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
        }));
      });

      it('the owning Contractor can still read it', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertSucceeds(getDoc(doc(db, 'orders', legacyManyWorkersId)));
      });

      it('reassigning it while still keeping 6 workers is denied', async () => {
        // Genuinely changes the stored array (different name on one entry —
        // an identical resend wouldn't register as a diff().affectedKeys()
        // change at all, which would trivially and correctly bypass
        // assignedWorkersValid() per the "only when assignment fields
        // change" rule — this must be a real reassignment attempt).
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', legacyManyWorkersId), {
          assignedWorkers: [
            workerEntry(workerA1, 'W1 Renamed'), workerEntry(workerA2, 'W2'),
            workerEntry(workerA3, 'W3'), workerEntry(workerA4, 'W4'),
            workerEntry(workerA5, 'W5'), workerEntry(workerA6, 'W6'),
          ],
          assignedWorkerId: workerA1, assignedWorkerName: 'W1 Renamed',
          updatedAt: new Date().toISOString(),
        }));
      });

      it('reassigning it down to 5 or fewer workers succeeds', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertSucceeds(updateDoc(doc(db, 'orders', legacyManyWorkersId), {
          assignedWorkers: [
            workerEntry(workerA1, 'W1'), workerEntry(workerA2, 'W2'),
          ],
          assignedWorkerId: workerA1, assignedWorkerName: 'W1',
          updatedAt: new Date().toISOString(),
        }));
      });
    });

    // ── Phase 3B3: closing inert cross-transition marker tolerance ─────────
    describe('Phase 3B3: marker-group consistency', () => {
      it('accept plus completedBy/completedAt is denied', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', pendingId), {
          status: 'inProgress', acceptedBy: 'contractor',
          acceptedAt: new Date().toISOString(),
          completedBy: 'contractor', completedAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }));
      });

      it('accept plus cancellation fields is denied', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', pendingId), {
          status: 'inProgress', acceptedBy: 'contractor',
          acceptedAt: new Date().toISOString(),
          cancelledBy: 'contractor', cancelledAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }));
      });

      it('complete plus acceptance fields is denied', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
          status: 'completed', completedBy: 'contractor',
          completedAt: new Date().toISOString(),
          acceptedBy: 'contractor', acceptedAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }));
      });

      it('complete plus cancellation fields is denied', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
          status: 'completed', completedBy: 'contractor',
          completedAt: new Date().toISOString(),
          cancelledBy: 'contractor', cancelledAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }));
      });

      it('cancel plus completion fields is denied', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', pendingId), {
          status: 'cancelled', cancelledBy: 'contractor',
          cancelledAt: new Date().toISOString(),
          completedBy: 'contractor', completedAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }));
      });

      it('reassignment while inProgress cannot inject completion fields', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
          assignedWorkerId: workerA1, assignedWorkerName: 'Test Worker',
          assignedWorkers: [workerEntry(workerA1, 'Test Worker')],
          completedBy: 'contractor', completedAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }));
      });

      it('reassignment while inProgress cannot inject cancellation fields', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
          assignedWorkerId: workerA1, assignedWorkerName: 'Test Worker',
          assignedWorkers: [workerEntry(workerA1, 'Test Worker')],
          cancelledBy: 'contractor', cancelledAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }));
      });

      it('a denied marker-injection write leaves the order document unchanged', async () => {
        const db = testEnv.authenticatedContext(conA).firestore();
        await assertFails(updateDoc(doc(db, 'orders', pendingId), {
          status: 'inProgress', acceptedBy: 'contractor',
          acceptedAt: new Date().toISOString(),
          completedBy: 'contractor', completedAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }));
        let snap;
        await testEnv.withSecurityRulesDisabled(async (ctx) => {
          snap = await getDoc(doc(ctx.firestore(), 'orders', pendingId));
        });
        if (snap.data().status !== 'pending' || 'completedBy' in snap.data()) {
          throw new Error('Order document was mutated despite a denied marker-injection write.');
        }
      });
    });
  });

  // ── update: Admin branches ────────────────────────────────────────────────
  describe('update — Admin', () => {
    const custA = 'ord_upda_cust';
    const conA = 'ord_upda_conA';
    const workerA1 = 'ord_upda_workerA1';
    const workerB1 = 'ord_upda_workerB1';
    const conB = 'ord_upda_conB';
    const adminUid = 'ord_upda_admin';
    let pendingId, inProgressId, completedId;

    beforeEach(async () => {
      pendingId = orderDocId() + '_p';
      inProgressId = orderDocId() + '_i';
      completedId = orderDocId() + '_c';
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', conA), contractorData(conA));
        await setDoc(doc(db, 'users', conB), contractorData(conB));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'contractor_workers', workerA1), workerData(conA, workerA1));
        await setDoc(doc(db, 'contractor_workers', workerB1), workerData(conB, workerB1, { fullName: 'Worker B1' }));
        await setDoc(doc(db, 'orders', pendingId),
          orderData(custA, conA, 'contractor', pendingId, { status: 'pending' }));
        await setDoc(doc(db, 'orders', inProgressId),
          orderData(custA, conA, 'contractor', inProgressId, { status: 'inProgress' }));
        await setDoc(doc(db, 'orders', completedId),
          orderData(custA, conA, 'contractor', completedId, { status: 'completed' }));
      });
    });

    it('approve (pending -> inProgress) succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        status: 'inProgress', acceptedBy: 'admin',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('complete (inProgress -> completed) succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', inProgressId), {
        status: 'completed', completedBy: 'admin',
        completedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('cancel from pending succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        status: 'cancelled', cancelledBy: 'admin',
        cancelledAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('cancel from inProgress succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', inProgressId), {
        status: 'cancelled', cancelledBy: 'admin',
        cancelledAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('edit title/description/area/serviceDate while pending succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', pendingId), {
        title: 'Admin Renamed', description: 'Admin desc', area: 'Admin area',
        serviceDate: new Date().toISOString(), editedBy: 'admin',
        editedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    // ── Phase 3B3: Admin edit cannot inject status-transition markers ──────
    it('Admin edit cannot inject acceptedBy', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        title: 'Admin Renamed', editedBy: 'admin',
        editedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
        acceptedBy: 'admin', acceptedAt: new Date().toISOString(),
      }));
    });

    it('Admin edit cannot inject completedBy', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        title: 'Admin Renamed', editedBy: 'admin',
        editedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
        completedBy: 'admin', completedAt: new Date().toISOString(),
      }));
    });

    it('Admin edit cannot inject cancelledBy', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        title: 'Admin Renamed', editedBy: 'admin',
        editedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
        cancelledBy: 'admin', cancelledAt: new Date().toISOString(),
      }));
    });

    it('a non-Admin cannot cause editedBy/editedAt to change', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        title: 'Hacked', editedBy: 'admin',
        editedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('edit fields while completed fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', completedId), {
        title: 'Too late', editedBy: 'admin',
        editedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('reassign a worker belonging to the order\'s Contractor succeeds', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', inProgressId), {
        assignedWorkerId: workerA1, assignedWorkerName: 'Test Worker',
        editedBy: 'admin', editedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it("reassigning a worker NOT belonging to the order's Contractor fails", async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', inProgressId), {
        assignedWorkerId: workerB1, assignedWorkerName: 'Worker B1',
        editedBy: 'admin', editedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
    });

    it('reassign on a completed order fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', completedId), {
        assignedWorkerId: workerA1, editedBy: 'admin',
        editedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin changing customerId fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        customerId: 'someone_else', status: 'inProgress', acceptedBy: 'admin',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin changing providerId fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        providerId: conB, status: 'inProgress', acceptedBy: 'admin',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin changing createdAt fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(updateDoc(doc(db, 'orders', pendingId), {
        createdAt: new Date().toISOString(), status: 'inProgress', acceptedBy: 'admin',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });
  });

  // ── delete ──────────────────────────────────────────────────────────────
  describe('delete', () => {
    const custA = 'ord_del_cust';
    const conA = 'ord_del_con';
    const conB = 'ord_del_conB';
    const adminUid = 'ord_del_admin';
    let orderId;

    beforeEach(async () => {
      orderId = orderDocId();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', conA), contractorData(conA));
        await setDoc(doc(db, 'users', conB), contractorData(conB));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'orders', orderId),
          orderData(custA, conA, 'contractor', orderId));
      });
    });

    it('owning Customer delete fails (no physical delete path exists)', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertFails(deleteDoc(doc(db, 'orders', orderId)));
    });

    it('owning Contractor delete fails', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertFails(deleteDoc(doc(db, 'orders', orderId)));
    });

    it('unrelated Contractor delete fails', async () => {
      const db = testEnv.authenticatedContext(conB).firestore();
      await assertFails(deleteDoc(doc(db, 'orders', orderId)));
    });

    it('Admin delete fails', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertFails(deleteDoc(doc(db, 'orders', orderId)));
    });

    it('unauthenticated delete fails', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(deleteDoc(doc(db, 'orders', orderId)));
    });
  });

  // ── legacy orders (missing-field fallback compatibility) ─────────────────
  describe('legacy orders (missing providerRole/category/worker/service fields)', () => {
    const custA = 'ord_legacy_cust';
    const conA = 'ord_legacy_con';
    const workerA1 = 'ord_legacy_workerA1';
    const adminUid = 'ord_legacy_admin';
    let legacyId;

    // A pre-Phase-3B2 (even pre-providerRole-field) document: only the bare
    // minimum OrderModel.fromMap() fallbacks assume may exist. No
    // providerRole, categoryId, categoryNameKey, serviceType, photoPath,
    // customerName/Phone, providerName/Phone, or any assignedWorker* field.
    function legacyOrderDoc(status) {
      return {
        customerId: custA,
        providerId: conA,
        title: 'Legacy order',
        description: 'Created before providerRole existed',
        area: 'Haifa',
        serviceDate: new Date().toISOString(),
        status,
        priority: 'normal',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
    }

    beforeEach(async () => {
      legacyId = orderDocId();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custA), customerData(custA));
        await setDoc(doc(db, 'users', conA), contractorData(conA));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'contractor_workers', workerA1), workerData(conA, workerA1));
        await setDoc(doc(db, 'orders', legacyId), legacyOrderDoc('pending'));
      });
    });

    it('owning Customer can still read a legacy order', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(getDoc(doc(db, 'orders', legacyId)));
    });

    it('owning Contractor can still read a legacy order', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(getDoc(doc(db, 'orders', legacyId)));
    });

    it("Contractor can still accept a legacy order missing providerRole (uses stored users/{uid}.role)", async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', legacyId), {
        status: 'inProgress', acceptedBy: 'contractor',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('Contractor can still assign a first-ever worker to a legacy order with no assignedWorker* fields', async () => {
      const db = testEnv.authenticatedContext(conA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', legacyId), {
        assignedWorkerId: workerA1, assignedWorkerName: 'Test Worker',
        assignedWorkers: [{ id: workerA1, name: 'Test Worker', specialties: [] }],
        status: 'inProgress', acceptedBy: 'contractor',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('Customer can still edit a legacy order missing categoryId/serviceType/photoPath', async () => {
      const db = testEnv.authenticatedContext(custA).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', legacyId), {
        title: 'Updated legacy title', updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin can still approve a legacy order', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(updateDoc(doc(db, 'orders', legacyId), {
        status: 'inProgress', acceptedBy: 'admin',
        acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
      }));
    });

    it('Admin unfiltered query still includes legacy orders', async () => {
      const db = testEnv.authenticatedContext(adminUid).firestore();
      const snap = await assertSucceeds(getDocs(collection(db, 'orders')));
      if (snap.size < 1) throw new Error('Expected the legacy order to be visible to Admin.');
    });
  });
});
