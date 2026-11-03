/// Dirección del servidor de autenticación.
///
/// Se cambia al compilar/ejecutar:
///   flutter run --dart-define=API_URL=http://10.0.2.2:3000   (emulador Android)
///   flutter run --dart-define=API_URL=https://api.tudominio.com   (producción)
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000',
);
