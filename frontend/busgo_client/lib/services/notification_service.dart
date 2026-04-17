import '../core/constants/api_constants.dart';
import '../models/notification_model.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _api;
  NotificationService(this._api);

  /// GET /notifications
  Future<List<NotificationModel>> getNotifications() async {
    final data = await _api.get(ApiEndpoints.notifications);
    final list = data as List<dynamic>;
    return list
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /notifications/:id/read
  Future<void> markRead(String id) async {
    await _api.patch(ApiEndpoints.notificationRead(id));
  }

  /// PATCH /notifications/read-all
  Future<void> markAllRead() async {
    await _api.patch(ApiEndpoints.notificationsReadAll);
  }

  /// DELETE /notifications/:id
  Future<void> deleteNotification(String id) async {
    await _api.delete(ApiEndpoints.notificationDelete(id));
  }
}
