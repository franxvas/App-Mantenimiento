import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:appmantflutter/auth/register_screen.dart';
import 'package:appmantflutter/services/audit_service.dart';
import 'package:appmantflutter/services/auth_user_profile_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await AuthUserProfileService.ensureUserProfile(currentUser);
      }
      await AuditService.logEvent(
        action: 'auth.login',
        message: 'inició sesión',
      );
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/menu', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Error de autenticación")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final userCredential = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider())
          : await _signInWithGoogleNative();
      final user = userCredential.user;
      if (user != null) {
        await AuthUserProfileService.ensureUserProfile(user);
      }

      await AuditService.logEvent(
        action: 'auth.login.google',
        message: 'inició sesión con Google',
      );
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/menu', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Error de autenticación (${e.code})"),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo iniciar con Google")),
      );
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
        message: 'Se canceló el inicio con Google.',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Bienvenido",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: "Correo Electrónico",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(
                    labelText: "Contraseña",
                    prefixIcon: Icon(Icons.key),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "INICIAR SESIÓN",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                    child: const Text("¿Cuenta nueva? Regístrate"),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text(
                      "INICIAR CON GOOGLE",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
