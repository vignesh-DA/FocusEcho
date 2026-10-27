class WebNotificationService {
  WebNotificationService._();
  static final WebNotificationService instance = WebNotificationService._();

  Future<void> requestPermissionFromUserGesture() async {}
  Future<void> showDistractionAlert(String appLabel, int level) async {}
  void clear() {}
}
