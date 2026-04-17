import 'package:flutter/material.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../models/emergency_model.dart';
import '../services/emergency_service.dart';

class EmergencyProvider extends ChangeNotifier {
  final EmergencyService _emergencyService;

  List<EmergencyAlertModel> _alerts = [];
  int _selectedType = 0;
  String _details = '';
  bool _isLoading = false;
  bool _alertSent = false;
  String? _errorMessage;

  EmergencyProvider(this._emergencyService);

  List<EmergencyAlertModel> get alerts => _alerts;
  int get selectedType => _selectedType;
  String get details => _details;
  bool get isLoading => _isLoading;
  bool get alertSent => _alertSent;
  String? get errorMessage => _errorMessage;

  // Raw API values — ordered to match UI
  static const List<String> alertTypes = [
    'medical',
    'criminal',
    'breakdown',
    'harassment',
    'other',
  ];

  // Display labels shown in the UI
  static const List<String> displayTypes = [
    '🏥 Medical Emergency',
    '🔪 Criminal Activity',
    '🔧 Bus Breakdown',
    '😰 Harassment',
    '📢 Other',
  ];

  Future<void> loadAlerts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _alerts = await _emergencyService.getAlerts();
    } on AppException catch (e) {
      _errorMessage = ErrorHandler.userMessage(e);
    } catch (e) {
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedType(int index) {
    _selectedType = index;
    notifyListeners();
  }

  void setDetails(String text) {
    _details = text;
  }

  Future<void> sendAlert({
    double? latitude,
    double? longitude,
    String? busId,
    String? tripId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final alert = await _emergencyService.sendAlert(
        alertType:   alertTypes[_selectedType],
        description: _details.isNotEmpty ? _details : null,
        latitude:    latitude,
        longitude:   longitude,
        busId:       busId,
        tripId:      tripId,
      );
      _alerts.insert(0, alert);
      _alertSent = true;
    } on AppException catch (e) {
      _errorMessage = ErrorHandler.userMessage(e);
    } catch (e) {
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetForm() {
    _selectedType = 0;
    _details = '';
    _alertSent = false;
    _errorMessage = null;
    notifyListeners();
  }
}
