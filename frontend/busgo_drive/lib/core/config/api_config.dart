import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central API configuration for BUSGO Drive.
/// All values are read from the .env file in the project root.
/// To switch environments just edit .env — never hardcode here.
class ApiConfig {
  ApiConfig._();

  /// Backend base URL — set in .env as API_URL
  static String get baseUrl =>
      dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000/api';

  /// MapTiler API key — set in .env as MAPTILER_KEY
  static String get mapTilerKey =>
      dotenv.env['MAPTILER_KEY'] ?? '';

  /// Full MapTiler tile URL — use this in every TileLayer
  static String get tileUrl =>
      'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=${mapTilerKey}';


}

 



