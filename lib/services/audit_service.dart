import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class AuditService {
  AuditService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Map<String, String> _nameCache = {};

  static Future<void> logEvent({
    required String action,
    required String message,
    String? disciplina,
    String? categoria,
    String? productDocId,
    String? idActivo,
    String? reportId,
    String? reportNro,
    List<String>? changes,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final user = _auth.currentUser;
      final uid = user?.uid ?? '';
      final email = user?.email;
      final actorName = await _resolveActorName(email, user?.displayName);

      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);

      final data = <String, dynamic>{
        'createdAt': FieldValue.serverTimestamp(),
        'dateKey': dateKey,
        'action': action,
        'message': message,
        'actorUid': uid,
        if (email != null) 'actorEmail': email,
        if (actorName != null && actorName.isNotEmpty) 'actorName': actorName,
        if (disciplina != null && disciplina.isNotEmpty) 'disciplina': disciplina,
        if (categoria != null && categoria.isNotEmpty) 'categoria': categoria,
        if (productDocId != null && productDocId.isNotEmpty) 'productDocId': productDocId,
        if (idActivo != null && idActivo.isNotEmpty) 'idActivo': idActivo,
        if (reportId != null && reportId.isNotEmpty) 'reportId': reportId,
        if (reportNro != null && reportNro.isNotEmpty) 'reportNro': reportNro,
        if (changes != null && changes.isNotEmpty) 'changes': changes,
        if (meta != null && meta.isNotEmpty) 'meta': meta,
      };

      await _firestore.collection('auditoria').add(data);
    } catch (e) {
      debugPrint('Error registrando auditoría: $e');
    }
  }

  static Future<String?> _resolveActorName(String? email, String? displayName) async {
    if (email != null && email.isNotEmpty) {
      final cached = _nameCache[email];
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      try {
        final snapshot = await _firestore
            .collection('usuarios')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) {
          final nombre = snapshot.docs.first.data()['nombre']?.toString().trim();
          if (nombre != null && nombre.isNotEmpty) {
            _nameCache[email] = nombre;
            return nombre;
          }
        }
      } catch (_) {}
    }
    return displayName ?? email;
  }
}
