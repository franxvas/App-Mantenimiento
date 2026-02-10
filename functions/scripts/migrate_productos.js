#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

function exitWith(msg) {
  console.error(msg);
  process.exit(1);
}

const serviceAccountPath = process.argv[2];
if (!serviceAccountPath) {
  exitWith("Usage: node migrate_productos.js /path/to/service-account.json");
}

const resolvedPath = path.resolve(serviceAccountPath);
if (!fs.existsSync(resolvedPath)) {
  exitWith(`Service account JSON not found: ${resolvedPath}`);
}

const serviceAccount = require(resolvedPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const DELETE_FIELDS = [
  "codigoQR",
  "idActivo",
  "estadoOperativo",
  "nombreProducto",
  "tipoActivo",
  "tipoMantenimiento",
  "impactoFalla",
];

async function run() {
  let lastDoc = null;
  let scanned = 0;
  let updated = 0;

  while (true) {
    let query = db.collection("productos")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(300);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    let batchWrites = 0;

    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() || {};
      const updates = {};
      let needsUpdate = false;

      if (!data.nombre) {
        const candidate = data.nombreProducto || data.tipoActivo;
        if (candidate) {
          updates.nombre = candidate;
          needsUpdate = true;
        }
      }

      if (!data.estado && data.estadoOperativo) {
        updates.estado = data.estadoOperativo;
        needsUpdate = true;
      }

      for (const field of DELETE_FIELDS) {
        if (Object.prototype.hasOwnProperty.call(data, field)) {
          updates[field] = admin.firestore.FieldValue.delete();
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        batch.update(doc.ref, updates);
        updated += 1;
        batchWrites += 1;
      }
    }

    if (batchWrites > 0) {
      await batch.commit();
    }

    lastDoc = snap.docs[snap.docs.length - 1];
  }

  console.log(`Done. Scanned: ${scanned}, Updated: ${updated}`);
}

run().catch((err) => {
  console.error("Migration failed:", err);
  process.exit(1);
});
