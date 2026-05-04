import 'package:flutter_dotenv/flutter_dotenv.dart';


class AppConfig {
  static String get baseUrl => dotenv.env['API_URL'] ?? 'http://192.168.1.2:5000/api';
}









