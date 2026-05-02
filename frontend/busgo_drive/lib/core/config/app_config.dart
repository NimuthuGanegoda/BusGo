import 'package:flutter_dotenv/flutter_dotenv.dart';


class AppConfig {
  static String get baseUrl => dotenv.env['API_URL'] ?? 'https://busgo-production.up.railway.app/api';
}








