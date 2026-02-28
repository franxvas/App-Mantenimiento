# App-Mantenimiento (AppMant) 🛠️📱

Aplicación móvil desarrollada con **Flutter/Dart** para la gestión de mantenimiento y activos.  
Utiliza **Firebase** para autenticación y base de datos, y **Supabase Storage** para el almacenamiento de imágenes (las URLs se guardan en Firebase).

---

## 🚀 Funcionalidades principales

- Inicio de sesión con Firebase Authentication  
- Gestión de activos/equipos (CRUD en Cloud Firestore)  
- Reportes de mantenimiento e inspección  
- Carga de imágenes a Supabase Storage  
- Escaneo de códigos QR por cámara y desde galería  
- Auditoría y trazabilidad de acciones  

---

## 🧰 Tecnologías utilizadas

- Flutter + Dart  
- Firebase (Authentication y Cloud Firestore)  
- Supabase Storage  
- Visual Studio Code  
- Android Studio / Xcode  

---

## ✅ Requisitos previos

- Flutter SDK (estable)  
- Android Studio (Android) o Xcode (iOS)  
- VS Code con extensiones Flutter y Dart  
- Proyecto configurado en Firebase  
- Proyecto configurado en Supabase  

Verificar Flutter:
```bash
flutter doctor
```

---

## 📦 Instalación

Clonar el repositorio:
```bash
git clone https://github.com/franxvas/App-Mantenimiento.git
cd App-Mantenimiento
```

Instalar dependencias:
```bash
flutter pub get
```

---

## 🔥 Configuración de Firebase

1. Crear un proyecto en Firebase Console  
2. Habilitar:
   - Firebase Authentication  
   - Cloud Firestore  
3. Configurar FlutterFire:
```bash
flutterfire configure
```

Colocar archivos de configuración:
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

---

## 🖼️ Configuración de Supabase

1. Crear proyecto en Supabase  
2. Crear un bucket en Storage  
3. Obtener:
   - SUPABASE_URL  
   - SUPABASE_ANON_KEY  

Configurar las claves en el proyecto (recomendado usar variables de entorno).

---

## ▶️ Ejecución de la aplicación

### Web (Chrome)
```bash
flutter run -d chrome
```

### Android
```bash
flutter run -d android
```

### iOS (macOS)
```bash
flutter run -d ios
```

---

## 🏗️ Build de producción

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

---

## 📁 Estructura del proyecto

```
lib/
  main.dart
  auth/
  productos/
  reportes/
  scan/
  services/
android/
ios/
web/
pubspec.yaml
```

---

## 🔍 Escaneo de códigos QR

El módulo de escaneo QR utiliza un paquete de lectura de códigos para:
1. Abrir la cámara del dispositivo  
2. Detectar el código QR  
3. Obtener el valor leído  
4. Consultar Firestore usando el código como ID del activo  
5. Mostrar información o permitir registrar reportes  

También permite leer códigos QR desde imágenes seleccionadas en la galería.

---

## 🧯 Solución de problemas

Limpiar y reinstalar dependencias:
```bash
flutter clean
flutter pub get
```

Configurar estrategia de pull en Git:
```bash
git config pull.rebase true
```

---

## 📩 Autor

Repositorio: https://github.com/franxvas/App-Mantenimiento
