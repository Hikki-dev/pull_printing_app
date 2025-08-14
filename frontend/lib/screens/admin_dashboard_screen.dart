import 'package:flutter/material.dart';
import '../models/print_job.dart';
import '../services/api_service.dart';
import '../widgets/job_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _api = ApiService();
  late Future<List<PrintJob>> _jobs;
  final String token = 'your_token_here'; // get from login/auth

  @override
  void initState() {
    super.initState();
    _jobs = _api.fetchAllJobs(token: token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: FutureBuilder<List<PrintJob>>(
        future: _jobs,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final jobs = snap.data!;
          if (jobs.isEmpty) {
            return const Center(child: Text('No jobs found.'));
          }
          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, i) => JobCard(job: jobs[i]),
          );
        },
      ),
    );
  }
}
