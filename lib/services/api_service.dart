import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/persona_data.dart';
import '../models/selection_data.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _client = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  // ──────────────────────────────────────────
  // Health Check
  // ──────────────────────────────────────────

  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ──────────────────────────────────────────
  // Personas
  // ──────────────────────────────────────────

  /// SelectionData를 aipa-engine의 GeneratePersonasRequest로 변환하여 호출
  Future<List<PersonaData>> generatePersonas(SelectionData selection) async {
    // Flutter SelectionData → aipa-engine 포맷 변환
    final ageGroupMap = {
      '10s': '10대',
      '20s': '20대',
      '30s': '30대',
      '40s': '40대',
      '50s+': '50대',
      '60s+': '60대+',
    };

    // 비율이 0보다 큰 연령대만 포함
    final ageGroups = selection.ageRatios.entries
        .where((e) => e.value > 0)
        .map((e) => ageGroupMap[e.key] ?? e.key)
        .toList();

    final body = {
      'panel_count': selection.sampleSize,
      'age_groups': ageGroups,
      'gender_ratio': {
        'male': selection.maleRatio / 100.0,
        'female': selection.femaleRatio / 100.0,
      },
      'generate_backstories': false,
      if (selection.occupations.isNotEmpty) 'occupations': selection.occupations,
      if (selection.traits.isNotEmpty) 'traits': selection.traits,
    };

    final response = await _client.post(
      Uri.parse(ApiConfig.personaGenerateUrl),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw ApiException('페르소나 생성 실패: ${response.statusCode}',
          response.body);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw ApiException('페르소나 응답 형식 오류', response.body);
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((json) => _convertPersona(json))
        .toList();
  }

  /// aipa-engine Persona → Flutter PersonaData 변환
  PersonaData _convertPersona(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};
    final ageGroup = attributes['age_group'] as String? ?? '';

    // 연령대에서 대략적인 나이 추출
    final age = _ageFromGroup(ageGroup);

    // 성별 변환
    final gender = attributes['gender'] == 'male' ? '남성' : '여성';

    // 연령에 따라 socialStatus 결정
    final socialStatus = age >= 40 ? 'senior' : 'junior';

    return PersonaData(
      name: json['name'] ?? '',
      gender: gender,
      age: age,
      occupation: attributes['occupation'] ?? '',
      description: json['backstory'] ?? '',
      socialStatus: socialStatus,
    );
  }

  int _ageFromGroup(String ageGroup) {
    switch (ageGroup) {
      case '10대':
        return 17;
      case '20대':
        return 25;
      case '30대':
        return 33;
      case '40대':
        return 45;
      case '50대':
        return 55;
      case '60대+':
        return 65;
      default:
        return 30;
    }
  }

  // Available for future use
  /// 페르소나 템플릿 목록 조회
  Future<List<Map<String, dynamic>>> getPersonaTemplates() async {
    final response = await _client.get(
      Uri.parse(ApiConfig.personaTemplatesUrl),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('템플릿 조회 실패: ${response.statusCode}',
          response.body);
    }

    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['templates'] ?? []);
  }

  // ──────────────────────────────────────────
  // Simulations (설문 실행)
  // ──────────────────────────────────────────

  /// 시뮬레이션 생성 (백그라운드 실행)
  Future<Map<String, dynamic>> createSimulation({
    required int panelCount,
    required List<Map<String, dynamic>> questions,
    List<String> ageGroups = const [],
    Map<String, double>? genderRatio,
  }) async {
    final body = {
      'panel_count': panelCount,
      'age_groups': ageGroups,
      'gender_ratio': genderRatio ?? {'male': 0.5, 'female': 0.5},
      'questions': questions,
    };

    final response = await _client.post(
      Uri.parse(ApiConfig.simulationsPostUrl),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException('시뮬레이션 생성 실패: ${response.statusCode}',
          response.body);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('시뮬레이션 응답 형식 오류', response.body);
    }
    return decoded;
  }

  /// 시뮬레이션 상태 조회 (폴링용)
  Future<Map<String, dynamic>> getSimulationStatus(String sessionId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.simulationsUrl}/$sessionId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('시뮬레이션 조회 실패: ${response.statusCode}',
          response.body);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('시뮬레이션 상태 응답 형식 오류', response.body);
    }
    return decoded;
  }

  /// 시뮬레이션 결과 조회
  Future<Map<String, dynamic>> getSimulationResult(String sessionId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.simulationsUrl}/$sessionId/result'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('결과 조회 실패: ${response.statusCode}',
          response.body);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('결과 응답 형식 오류', response.body);
    }
    return decoded;
  }

  // ──────────────────────────────────────────
  // Chat
  // ──────────────────────────────────────────

  /// 페르소나 기반 AI 채팅 메시지 전송
  Future<String> sendChatMessage({
    required String message,
    required Map<String, dynamic> persona,
    String? platform,
    String? goal,
    String? format,
    List<Map<String, String>>? history,
    String? filePath,
    String? fileName,
    String? extractedText,
  }) async {
    // 이미지 파일이면 base64로 변환해서 보냄
    String? imageBase64;
    String? imageMediaType;
    if (filePath != null) {
      final ext = filePath.split('.').last.toLowerCase();
      final imageExts = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
      if (imageExts.contains(ext)) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            imageBase64 = base64Encode(bytes);
            imageMediaType = {
              'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
              'gif': 'image/gif', 'bmp': 'image/bmp', 'webp': 'image/webp',
            }[ext] ?? 'image/jpeg';
          }
        } catch (e) {
          debugPrint('이미지 base64 변환 실패: $e');
        }
      }
    }

    final body = {
      'message': message,
      'persona': persona,
      if (platform != null) 'platform': platform,
      if (goal != null) 'goal': goal,
      if (format != null) 'format': format,
      if (history != null) 'history': history,
      if (filePath != null) 'file_path': filePath,
      if (fileName != null) 'file_name': fileName,
      if (extractedText != null) 'extracted_text': extractedText,
      if (imageBase64 != null) 'image_base64': imageBase64,
      if (imageMediaType != null) 'image_media_type': imageMediaType,
    };

    final response = await _client.post(
      Uri.parse(ApiConfig.chatMessageUrl),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw ApiException('채팅 응답 실패: ${response.statusCode}', response.body);
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw ApiException('채팅 응답 형식 오류', response.body);
    }
    return data['response'] as String? ?? '';
  }

  // ──────────────────────────────────────────
  // File Upload
  // ──────────────────────────────────────────

  /// 파일 업로드 (문서 또는 이미지)
  Future<Map<String, dynamic>> uploadFile(String filePath, String fileName) async {
    final extension = fileName.split('.').last.toLowerCase();

    // 엔드포인트 결정
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
    final url = isImage ? ApiConfig.uploadImageUrl : ApiConfig.uploadDocumentUrl;

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ApiException('파일 업로드 실패: ${response.statusCode}', response.body);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('업로드 응답 형식 오류', response.body);
    }
    final result = decoded;
    debugPrint('업로드 응답 키: ${result.keys.toList()}');
    final pq = result['parsed_questions'];
    debugPrint('parsed_questions: ${pq is List ? '${pq.length}개' : 'null'}');
    return result;
  }

  // ──────────────────────────────────────────
  // Statistics
  // ──────────────────────────────────────────

  // Available for future use
  Future<Map<String, dynamic>> getAgeDistribution() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.statisticsUrl}/population/age'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('통계 조회 실패: ${response.statusCode}',
          response.body);
    }

    return jsonDecode(response.body);
  }

  // ──────────────────────────────────────────
  // Chat sessions (유저별 영구 대화 보관, 카톡방식)
  // ──────────────────────────────────────────

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (ApiConfig.bearerToken.isNotEmpty)
          'Authorization': 'Bearer ${ApiConfig.bearerToken}',
      };

  /// 대화방 저장/업데이트 (메시지 올 때마다 호출)
  Future<void> saveChat({
    required String userId,
    required String sessionId,
    String? platform,
    required String title,
    required List<Map<String, String>> messages,
  }) async {
    try {
      await _client
          .post(Uri.parse('${ApiConfig.chatsUrl}/$userId'),
              headers: _authHeaders,
              body: jsonEncode({
                'id': sessionId,
                'platform': platform,
                'title': title,
                'messages': messages,
              }))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('saveChat 실패(무시): $e');
    }
  }

  /// 유저의 대화방 목록 (최근순)
  Future<List<Map<String, dynamic>>> listChats(String userId) async {
    try {
      final res = await _client
          .get(Uri.parse('${ApiConfig.chatsUrl}/$userId'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final data = body is Map ? body['data'] : null;
      if (data is! List) return [];
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('listChats 실패: $e');
      return [];
    }
  }

  /// 대화방 전체 메시지 (재진입용)
  Future<List<Map<String, String>>> getChatMessages(String userId, String sessionId) async {
    try {
      final res = await _client
          .get(Uri.parse('${ApiConfig.chatsUrl}/$userId/$sessionId'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final msgs = (body is Map && body['data'] is Map) ? body['data']['messages'] : null;
      if (msgs is! List) return [];
      return msgs
          .whereType<Map>()
          .map((m) => {'role': (m['role'] ?? '').toString(), 'content': (m['content'] ?? '').toString()})
          .toList();
    } catch (e) {
      debugPrint('getChatMessages 실패: $e');
      return [];
    }
  }

  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final String message;
  final String? responseBody;

  ApiException(this.message, [this.responseBody]);

  @override
  String toString() => 'ApiException: $message';
}
