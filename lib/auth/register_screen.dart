import 'package:appmantflutter/services/audit_service.dart';
import 'package:appmantflutter/services/auth_user_profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isLoading = false;
  String _cargoSeleccionado = AuthUserProfileService.cargoOptions.first;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dniCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text.trim(),
          );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'No se pudo crear el usuario.',
        );
      }

      await AuthUserProfileService.ensureUserProfile(
        user,
        nombre: _nombreCtrl.text.trim(),
        dni: _dniCtrl.text.trim(),
        cargo: _cargoSeleccionado,
        area: AuthUserProfileService.defaultArea,
      );

      await AuditService.logEvent(
        action: 'auth.register.email',
        message: 'registró una cuenta con correo',
      );

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/menu', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'No se pudo registrar la cuenta.');
    } catch (_) {
      _showError('No se pudo registrar la cuenta.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final userCredential = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider())
          : await _signInWithGoogleNative();
      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'No se pudo autenticar con Google.',
        );
      }

      await AuthUserProfileService.ensureUserProfile(
        user,
        nombre: _nombreCtrl.text.trim(),
        dni: _dniCtrl.text.trim(),
        cargo: _cargoSeleccionado,
        area: AuthUserProfileService.defaultArea,
      );

      await AuditService.logEvent(
        action: 'auth.register.google',
        message: 'ingresó con Google',
      );

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/menu', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Error al autenticar con Google (${e.code}).');
    } catch (_) {
      _showError('Error al autenticar con Google.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<UserCredential> _signInWithGoogleNative() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'google-signin-cancelled',
        message: 'Se canceló el registro con Google.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Registro de técnico',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      controller: _nombreCtrl,
                      label: 'Nombre y apellido',
                      icon: Icons.person_outline,
                      required: true,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _dniCtrl,
                      label: 'DNI (8 dígitos)',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      exactLength: 8,
                      required: true,
                    ),
                    const SizedBox(height: 14),
                    _buildCargoDropdown(),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _emailCtrl,
                      label: 'Correo electrónico',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      isEmail: true,
                      required: true,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _passCtrl,
                      label: 'Contraseña',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      required: true,
                      minLength: 6,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _confirmPassCtrl,
                      label: 'Confirmar contraseña',
                      icon: Icons.lock_reset_outlined,
                      obscureText: true,
                      required: true,
                      minLength: 6,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        if (value.trim() != _passCtrl.text.trim()) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Área: se asigna después por un administrador.',
                      style: TextStyle(color: Color(0xFF6C757D), fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _registerWithEmail,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'REGISTRARSE',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _registerWithGoogle,
                        icon: const Icon(Icons.g_mobiledata, size: 26),
                        label: const Text('Continuar con Google'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCargoDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _cargoSeleccionado,
      items: AuthUserProfileService.cargoOptions
          .map(
            (cargo) =>
                DropdownMenuItem<String>(value: cargo, child: Text(cargo)),
          )
          .toList(),
      onChanged: _isLoading
          ? null
          : (value) {
              if (value == null) {
                return;
              }
              setState(() => _cargoSeleccionado = value);
            },
      decoration: const InputDecoration(
        labelText: 'Cargo',
        prefixIcon: Icon(Icons.work_outline),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool required = false,
    bool isEmail = false,
    int? exactLength,
    int? minLength,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator:
          validator ??
          (value) {
            final text = (value ?? '').trim();
            if (required && text.isEmpty) {
              return 'Este campo es obligatorio';
            }
            if (text.isEmpty) {
              return null;
            }
            if (exactLength != null && text.length != exactLength) {
              return 'Debe tener $exactLength dígitos';
            }
            if (minLength != null && text.length < minLength) {
              return 'Debe tener al menos $minLength caracteres';
            }
            if (isEmail && !_isValidEmail(text)) {
              return 'Correo inválido';
            }
            return null;
          },
    );
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
  }
}
