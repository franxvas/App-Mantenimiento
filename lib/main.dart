import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Base de Datos
import 'package:firebase_auth/firebase_auth.dart' as auth; // Autenticación
import 'package:appmantflutter/firebase_options.dart'; // Configuración generada
import 'package:supabase_flutter/supabase_flutter.dart' hide User; // Storage

// --- IMPORTACIONES DE PANTALLAS ---
// Asegúrate de que las rutas coincidan con tu estructura de carpetas
import 'package:appmantflutter/auth/login_screen.dart';
import 'package:appmantflutter/disciplinas_screen.dart'; 
import 'package:appmantflutter/reportes/reportes_screen.dart';
import 'package:appmantflutter/usuarios/lista_usuarios_screen.dart';
import 'package:appmantflutter/scan/qr_scanner_screen.dart'; // NUEVO: Import del Escáner
import 'package:appmantflutter/dashboard/dashboard_screen.dart';
import 'package:appmantflutter/parametros/parametros_screen.dart';

// 1. PUNTO DE ENTRADA
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // --- A. INICIALIZAR FIREBASE ---
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase inicializado");
  } catch (e) {
    print("Error al inicializar Firebase: $e");
  }

  // --- B. INICIALIZAR SUPABASE ---
  try {
    await Supabase.initialize(
      url: 'https://qtpbivwozdnskjdqstzi.supabase.co',
      anonKey: 'sb_publishable_79mIXMNqVBwOxX94ZDLhEg_YHd2LNzi',
    );
    print("✅ Supabase inicializado");
  } catch (e) {
    print("Error al inicializar Supabase: $e");
  }
  
  runApp(const MiAppMantenimiento());
}

// 2. CONFIGURACIÓN DE LA APP Y AUTH GATE
class MiAppMantenimiento extends StatelessWidget {
  const MiAppMantenimiento({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFF8B1E1E);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mantis',
      theme: ThemeData(
        fontFamily: 'AppUnicode',
        fontFamilyFallback: const ['AppUnicode'],
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryRed,
          primary: primaryRed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryRed,
            foregroundColor: Colors.white,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: primaryRed.withOpacity(0.1),
          selectedColor: primaryRed,
          secondarySelectedColor: primaryRed,
          labelStyle: const TextStyle(color: Color(0xFF2C2C2C)),
          secondaryLabelStyle: const TextStyle(color: Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      ),
      // --- AUTH GATE: DECIDE QUÉ PANTALLA MOSTRAR ---
      home: StreamBuilder<auth.User?>(
        stream: auth.FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          if (snapshot.hasData) {
            return const MainMenuScreen(); // Usuario logueado -> Menú
          }
          
          return const LoginScreen(); // No usuario -> Login
        },
      ),
    );
  }
}

// 3. TU PANTALLA DE MENÚ CON BOTÓN DE ESCÁNER
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Menú Principal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await auth.FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      
      // --- NUEVO: BOTÓN FLOTANTE PARA ESCANEAR ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QRScannerScreen()),
          );
        },
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text("Escanear", style: TextStyle(color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // Centrado abajo

      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _MenuCard(
                      title: "Dashboard",
                      icon: Icons.analytics_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DashboardScreen()),
                        );
                      },
                    ),
                    _MenuCard(
                      title: "Disciplinas",
                      icon: Icons.inventory_2_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DisciplinasScreen(),
                          ),
                        );
                      },
                    ),
                    _MenuCard(
                      title: "Reportes",
                      icon: Icons.description_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportesScreen(),
                          ),
                        );
                      },
                    ),
                    _MenuCard(
                      title: "Parámetros",
                      icon: Icons.tune,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ParametrosScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: _MenuCard(
                      title: "Usuarios",
                      icon: Icons.group_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ListaUsuariosScreen()),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 4. WIDGET REUTILIZABLE
class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.onTap,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42, color: color),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF34495E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
