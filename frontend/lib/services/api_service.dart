import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/print_job.dart';
import '../models/session.dart';
import '../utils/constants.dart';
import 'print_repository.dart';

/// Thin client for the backend API (see backend/controllers). Turns HTTP errors
/// into [PrintException], [QuotaExceededException] and [SessionExpiredException].
class ApiService {
  ApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? Constants.apiBaseUrl;

  final http.Client _client;
  final String baseUrl;

  static const _timeout = Duration(seconds: 20);

  Future<dynamic> _send(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    http.Response response;
    try {
      response = await http.Response.fromStream(
          await _client.send(request).timeout(_timeout));
    } on TimeoutException {
      throw const PrintException('The print server took too long to answer.');
    } on http.ClientException {
      throw const PrintException('Cannot reach the print server.');
    }

    final decoded = response.body.isEmpty ? null : _tryDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    if (response.statusCode == 401) throw const SessionExpiredException();
    if (response.statusCode == 429) {
      throw const PrintException(
          'Too many requests. Please wait a minute and try again.');
    }
    if (decoded is Map<String, dynamic>) {
      if (response.statusCode == 409 && decoded['error'] == 'quota_exceeded') {
        throw QuotaExceededException(
            (decoded['pagesOver'] as num?)?.toInt() ?? 0);
      }
      final message = decoded['message'];
      if (message is String && message.isNotEmpty) {
        throw PrintException(message);
      }
    }
    if (response.statusCode == 403) {
      throw const PrintException('You do not have permission to do that.');
    }
    throw PrintException(
        'The server could not do that (error ${response.statusCode}).');
  }

  static dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static Session _session(Map<String, dynamic> json, String token) => Session(
        token: token,
        userId: json['userId'] as String,
        name: json['name'] as String,
        isAdmin: json['isAdmin'] as bool? ?? false,
      );

  static QuotaInfo _quota(Map<String, dynamic> json) => QuotaInfo(
        used: (json['used'] as num).toInt(),
        total: (json['total'] as num).toInt(),
      );

  /// Demo sign-in: a private sandbox with sample documents.
  Future<Session> demoLogin({bool admin = false}) async {
    final json =
        await _send('POST', '/auth/demo-login', body: {'admin': admin});
    return _session(json as Map<String, dynamic>, json['token'] as String);
  }

  /// Who the token belongs to, used after Microsoft sign-in.
  Future<Session> me(String token) async {
    final json = await _send('GET', '/auth/me', token: token);
    return _session(json as Map<String, dynamic>, token);
  }

  Future<List<PrintJob>> heldJobs(String token) async {
    final json =
        await _send('GET', '/jobs/held', token: token) as List<dynamic>;
    return json
        .map((j) => PrintJob.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<QuotaInfo> quota(String token) async => _quota(
      await _send('GET', '/jobs/quota', token: token) as Map<String, dynamic>);

  /// Ids of the jobs that really printed.
  Future<List<String>> release(String token, List<String> jobIds) async {
    final json = await _send('POST', '/jobs/release',
        token: token, body: {'jobIds': jobIds}) as Map<String, dynamic>;
    return (json['printed'] as List<dynamic>).cast<String>();
  }

  Future<void> sendSample(String token) =>
      _send('POST', '/jobs/sample', token: token);

  Future<List<PrintJob>> allJobs(String token) async {
    final json = await _send('GET', '/jobs', token: token) as List<dynamic>;
    return json
        .map((j) => PrintJob.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserQuota>> users(String token) async {
    final json =
        await _send('GET', '/admin/users', token: token) as List<dynamic>;
    return json.map((u) {
      final m = u as Map<String, dynamic>;
      return UserQuota(
        userId: m['userId'] as String,
        name: m['name'] as String,
        quota: _quota(m['quota'] as Map<String, dynamic>),
      );
    }).toList();
  }

  Future<void> setQuota(String token, String userId, int quota) => _send(
        'POST',
        '/admin/set-quota',
        token: token,
        body: {'userId': userId, 'quota': quota},
      );
}
