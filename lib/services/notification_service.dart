import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> showSimulationComplete({
    required int panelCount,
    required int questionCount,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'simulation',
      '설문 시뮬레이션',
      channelDescription: '설문 시뮬레이션 완료 알림',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      0,
      '설문 시뮬레이션 완료',
      '$panelCount명의 AI 패널이 $questionCount개 질문에 응답했습니다. 결과를 확인하세요!',
      details,
    );
  }
}
