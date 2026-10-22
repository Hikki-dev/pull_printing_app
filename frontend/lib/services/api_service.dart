import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/print_job.dart';
import '../models/printer.dart';
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

  static Session _session(Map<String, dynamic> json, String token,
          {required bool demo}) =>
      Session(
        token: token,
        userId: json['userId'] as String,
        name: json['name'] as String,
        isAdmin: json['isAdmin'] as bool? ?? false,
        demo: demo,
      );

  static QuotaInfo _quota(Map<String, dynamic> json) => QuotaInfo(
        used: (json['used'] as num).toInt(),
        total: (json['total'] as num).toInt(),
      );

  /// Demo sign-in: a private sandbox with sample documents.
  Future<Session> demoLogin({bool admin = false}) async {
    final json =
        await _send('POST', '/auth/demo-login', body: {'admin': admin});
    return _session(json as Map<String, dynamic>, json['token'] as String,
        demo: true);
  }

  /// Who the token belongs to, used after a work-account sign-in.
  Future<Session> me(String token) async {
    final json = await _send('GET', '/auth/me', token: token);
    return _session(json as Map<String, dynamic>, token, demo: false);
  }

  Future<AuthConfig> authConfig() async {
    final json = await _send('GET', '/auth/config') as Map<String, dynamic>;
    return AuthConfig(
      provider: (json['provider'] as String? ?? 'none').toLowerCase(),
      domain: json['domain'] as String?,
      demo: json['demo'] as bool? ?? false,
    );
  }

  Future<List<Printer>> printers(String token) async {
    final json = await _send('GET', '/printers', token: token) as List<dynamic>;
    return json
        .map((p) => Printer.fromJson(p as Map<String, dynamic>))
        .toList();
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
  Future<List<String>> release(String token, List<String> jobIds,
      {String? printerId}) async {
    final json = await _send('POST', '/jobs/release', token: token, body: {
      'jobIds': jobIds,
      if (printerId != null) 'printerId': printerId,
    }) as Map<String, dynamic>;
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
        email: m['email'] as String?,
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

  Future<SetupInfo> setup(String token) async {
    final m = await _send('GET', '/admin/setup', token: token)
        as Map<String, dynamic>;
    return SetupInfo(
      provider: m['provider'] as String? ?? 'None',
      domain: m['domain'] as String?,
      demoEnabled: m['demoEnabled'] as bool? ?? false,
      defaultQuota: (m['defaultQuota'] as num).toInt(),
      people: (m['people'] as num).toInt(),
      printers: (m['printers'] as num).toInt(),
      redirectUri: m['redirectUri'] as String? ?? '',
      warnings: (m['warnings'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  Future<void> setDefaultQuota(String token, int quota) =>
      _send('POST', '/admin/default-quota',
          token: token, body: {'quota': quota});

  Future<int> setQuotaForAll(String token, int quota) async {
    final m = await _send('POST', '/admin/set-quota-all',
        token: token, body: {'quota': quota}) as Map<String, dynamic>;
    return (m['changed'] as num?)?.toInt() ?? 0;
  }

  Future<Printer> addPrinter(
          String token, String name, String location) async =>
      Printer.fromJson(await _send('POST', '/admin/printers',
          token: token,
          body: {'name': name, 'location': location}) as Map<String, dynamic>);

  Future<void> updatePrinter(String token, Printer p) =>
      _send('PUT', '/admin/printers/${Uri.encodeComponent(p.id)}',
          token: token,
          body: {'name': p.name, 'location': p.location, 'enabled': p.enabled});

  Future<void> deletePrinter(String token, String id) =>
      _send('DELETE', '/admin/printers/${Uri.encodeComponent(id)}',
          token: token);
}
