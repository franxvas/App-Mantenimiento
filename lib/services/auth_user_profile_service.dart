import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthUserProfileService {
  AuthUserProfileService._();

  static const String defaultRol = 'tecnico';
  static const String defaultArea = 'Por asignar';
  static const String defaultCargo = 'Técnico Electricista';

  static const List<String> cargoOptions = <String>[
    'Técnico Electricista',
    'Técnico Electromecánico',
    'Técnico Biomédico',
    'Técnico de Refrigeración',
    'Técnico de Infraestructura',
    'Supervisor de Mantenimiento',
    'Coordinador de Mantenimiento',
  ];

  static Future<void> ensureUserProfile(
    User user, {
    String? nombre,
    String? dni,
    String? cargo,
    String? area,
    String? celular,
  }) async {
    final rawEmail = user.email?.trim().toLowerCase();
    if (rawEmail == null || rawEmail.isEmpty) {
      return;
    }

    final usuariosRef = FirebaseFirestore.instance.collection('usuarios');
    final existingSnapshot = await usuariosRef
        .where('email', isEqualTo: rawEmail)
        .limit(1)
        .get();

    final resolvedNombre = _firstNonEmpty([
      nombre,
      user.displayName,
      _nameFromEmail(rawEmail),
    ]);
    final resolvedDni = (dni ?? '').trim();
    final resolvedCargo = _firstNonEmpty([cargo, defaultCargo]);
    final resolvedArea = _firstNonEmpty([area, defaultArea]);
    final resolvedCelular = (celular ?? '').trim();
    final resolvedAvatarUrl = (user.photoURL ?? '').trim();

    if (existingSnapshot.docs.isEmpty) {
      await usuariosRef.doc(user.uid).set({
        'uid': user.uid,
        'nombre': resolvedNombre,
        'dni': resolvedDni,
        'cargo': resolvedCargo,
        'area': resolvedArea,
        'celular': resolvedCelular,
        'email': rawEmail,
        'rol': defaultRol,
        'fechaRegistro': FieldValue.serverTimestamp(),
        'avatarUrl': resolvedAvatarUrl,
        'firmaUrl': '',
      });
      return;
    }

    final doc = existingSnapshot.docs.first;
    final data = doc.data();
    final updates = <String, dynamic>{'uid': user.uid};

    if (_isBlank(data['nombre']) && resolvedNombre.isNotEmpty) {
      updates['nombre'] = resolvedNombre;
    }
    if (_isBlank(data['dni']) && resolvedDni.isNotEmpty) {
      updates['dni'] = resolvedDni;
    }
    if (_isBlank(data['cargo']) && resolvedCargo.isNotEmpty) {
      updates['cargo'] = resolvedCargo;
    }
    if (_isBlank(data['area']) && resolvedArea.isNotEmpty) {
      updates['area'] = resolvedArea;
    }
    if (_isBlank(data['celular']) && resolvedCelular.isNotEmpty) {
      updates['celular'] = resolvedCelular;
    }
    if (_isBlank(data['rol'])) {
      updates['rol'] = defaultRol;
    }
    if (_isBlank(data['avatarUrl']) && resolvedAvatarUrl.isNotEmpty) {
      updates['avatarUrl'] = resolvedAvatarUrl;
    }
    if (_isBlank(data['firmaUrl'])) {
      updates['firmaUrl'] = '';
    }
    if (!data.containsKey('fechaRegistro')) {
      updates['fechaRegistro'] = FieldValue.serverTimestamp();
    }

    if (updates.length > 1) {
      await doc.reference.update(updates);
    }
  }

  static bool _isBlank(dynamic value) {
    return value == null || value.toString().trim().isEmpty;
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value == null) {
        continue;
      }
      final text = value.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  static String _nameFromEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) {
      return email;
    }
    return email.substring(0, atIndex);
  }
}
