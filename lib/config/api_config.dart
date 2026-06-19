import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // AIPA Engine API (Cloud Run 또는 로컬)
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8080';

  // API v1 prefix
  static String get apiPrefix => '$baseUrl/api/v1';

  // Endpoints
  static String get personaGenerateUrl => '$apiPrefix/personas/generate';
  static String get personaTemplatesUrl => '$apiPrefix/personas/templates';
  // POST는 trailing slash 필요, GET은 trailing slash 없어야 함
  static String get simulationsUrl => '$apiPrefix/simulations';
  static String get simulationsPostUrl => '$apiPrefix/simulations/';
  static String get statisticsUrl => '$apiPrefix/statistics';
  static String get chatMessageUrl => '$apiPrefix/chat/message';
  static String get uploadDocumentUrl => '$apiPrefix/upload/document';
  static String get uploadImageUrl => '$apiPrefix/upload/image';

  // Users / Auth (Firestore → PostgreSQL 백엔드)
  static String get usersUrl => '$apiPrefix/users';

  // 보호 라우트(PUT/DELETE/POST history)용 공유 Bearer 토큰.
  // 서버 .env 의 API_BEARER_TOKEN 과 동일 값을 클라이언트 .env 에 설정.
  static String get bearerToken => dotenv.env['API_BEARER_TOKEN'] ?? '';

  // Kakao
  static String get kakaoNativeAppKey =>
      dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '';
}
