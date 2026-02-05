import 'package:cloud_firestore/cloud_firestore.dart';

class UsuariosCacheService {
  UsuariosCacheService._();

  static final UsuariosCacheService instance = UsuariosCacheService._();

  final Map<String, String> _idToNombre = {};
  final Map<String, String> _emailToNombre = {};
  final Map<String, String> _idToFirmaUrl = {};
  final Map<String, String> _emailToFirmaUrl = {};
  final Map<String, String> _nombreToFirmaUrl = {};
  Future<void>? _loadingFuture;

  Future<void> preload({bool force = false}) {
    if (!force && _loadingFuture != null) {
      return _loadingFuture!;
    }
    _loadingFuture = _loadUsuarios();
    return _loadingFuture!;
  }

  String resolveResponsableName(Map<String, dynamic> reporte) {
    final idCandidate = _firstNonEmpty([
      reporte['responsableId'],
      reporte['responsableUid'],
      reporte['responsableUID'],
      reporte['usuarioId'],
      reporte['userId'],
    ]);
    if (idCandidate != null) {
      final resolved = _lookupById(idCandidate);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }

    final nombreField = _firstNonEmpty([
      reporte['responsableNombre'],
      reporte['responsable'],
      reporte['encargado'],
    ]);
    if (nombreField != null && nombreField.isNotEmpty && !_looksLikeEmail(nombreField)) {
      return nombreField;
    }

    final emailCandidate = _firstNonEmpty([
      reporte['responsableEmail'],
      reporte['email'],
      nombreField,
    ]);
    if (emailCandidate != null && _looksLikeEmail(emailCandidate)) {
      final resolvedByEmail = _lookupByEmail(emailCandidate);
      if (resolvedByEmail != null && resolvedByEmail.isNotEmpty) {
        return resolvedByEmail;
      }
      return emailCandidate;
    }

    if (nombreField != null && nombreField.isNotEmpty) {
      return nombreField;
    }

    return '--';
  }

  String? resolveResponsableFirmaUrl(Map<String, dynamic> reporte) {
    final idCandidate = _firstNonEmpty([
      reporte['responsableId'],
      reporte['responsableUid'],
      reporte['responsableUID'],
      reporte['usuarioId'],
      reporte['userId'],
    ]);
    if (idCandidate != null) {
      final resolved = _lookupFirmaById(idCandidate);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }

    final nombreField = _firstNonEmpty([
      reporte['responsableNombre'],
      reporte['responsable'],
      reporte['encargado'],
    ]);
    if (nombreField != null) {
      final resolvedByNombre = _lookupFirmaByNombre(nombreField);
      if (resolvedByNombre != null && resolvedByNombre.isNotEmpty) {
        return resolvedByNombre;
      }
    }

    final emailCandidate = _firstNonEmpty([
      reporte['responsableEmail'],
      reporte['email'],
      nombreField,
    ]);
    if (emailCandidate != null && _looksLikeEmail(emailCandidate)) {
      final resolvedByEmail = _lookupFirmaByEmail(emailCandidate);
      if (resolvedByEmail != null && resolvedByEmail.isNotEmpty) {
        return resolvedByEmail;
      }
    }

    return null;
  }

  Future<void> _loadUsuarios() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final nombre = data['nombre']?.toString().trim();
      if (nombre == null || nombre.isEmpty) {
        continue;
      }
      final firmaUrl = data['firmaUrl']?.toString().trim();
      final nombreKey = nombre.toLowerCase();
      if (firmaUrl != null && firmaUrl.isNotEmpty) {
        _nombreToFirmaUrl[nombreKey] = firmaUrl;
      }

      final docId = doc.id.trim();
      if (docId.isNotEmpty) {
        _idToNombre[docId] = nombre;
        if (firmaUrl != null && firmaUrl.isNotEmpty) {
          _idToFirmaUrl[docId] = firmaUrl;
        }
      }

      final uid = data['uid']?.toString().trim() ??
          data['usuarioId']?.toString().trim() ??
          data['userId']?.toString().trim();
      if (uid != null && uid.isNotEmpty) {
        _idToNombre[uid] = nombre;
        if (firmaUrl != null && firmaUrl.isNotEmpty) {
          _idToFirmaUrl[uid] = firmaUrl;
        }
      }

      final email = data['email']?.toString().trim().toLowerCase();
      if (email != null && email.isNotEmpty) {
        _emailToNombre[email] = nombre;
        if (firmaUrl != null && firmaUrl.isNotEmpty) {
          _emailToFirmaUrl[email] = firmaUrl;
        }
      }
    }
  }

  String? _lookupById(String rawId) {
    final id = rawId.trim();
    if (id.isEmpty) {
      return null;
    }
    return _idToNombre[id];
  }

  String? _lookupByEmail(String rawEmail) {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty) {
      return null;
    }
    return _emailToNombre[email];
  }

  String? _lookupFirmaById(String rawId) {
    final id = rawId.trim();
    if (id.isEmpty) {
      return null;
    }
    return _idToFirmaUrl[id];
  }

  String? _lookupFirmaByEmail(String rawEmail) {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty) {
      return null;
    }
    return _emailToFirmaUrl[email];
  }

  String? _lookupFirmaByNombre(String rawNombre) {
    final nombre = rawNombre.trim().toLowerCase();
    if (nombre.isEmpty) {
      return null;
    }
    return _nombreToFirmaUrl[nombre];
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  bool _looksLikeEmail(String value) {
    return value.contains('@');
  }
}
