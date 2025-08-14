import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/print_job.dart';

class ApiService {
  final String baseUrl = "http://localhost:3000";
  // Adjust the base URL as needed for your backend

  Future<List<PrintJob>> fetchAllJobs({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/jobs'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch jobs: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => PrintJob.fromJson(json)).toList();
  }

  Future<List<PrintJob>> fetchMyHeldJobs({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/jobs/held'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch held jobs: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => PrintJob.fromJson(json)).toList();
  }

  Future<void> releaseJob({required String token, required String jobId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/jobs/release'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'jobId': jobId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to release job: ${response.statusCode}');
    }
  }
}
