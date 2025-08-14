import 'package:flutter/material.dart';
import '../models/print_job.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/job_card.dart';
import 'login_screen.dart';

class ReleaseJobsScreen extends StatefulWidget {
  final String accessToken;
  const ReleaseJobsScreen({required this.accessToken, super.key});

  @override
  State<ReleaseJobsScreen> createState() => _ReleaseJobsScreenState();
}

class _ReleaseJobsScreenState extends State<ReleaseJobsScreen> {
  final _api = ApiService();
  late Future<List<PrintJob>> _jobs;
  bool _releasing = false;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  void _fetchJobs() {
    setState(() {
      _jobs = _api.fetchMyHeldJobs(token: widget.accessToken);
    });
  }

  Future<void> _release(PrintJob job) async {
    if (Constants.defaultPrinterId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No default printer configured.')),
      );
      return;
    }

    setState(() => _releasing = true);

    try {
      await _api.releaseJob(
        token: widget.accessToken,
        jobId: job.id,
      );
      if (!mounted) return;
      _fetchJobs();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Released: ${job.fileName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Release failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Print Jobs'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _fetchJobs(),
        child: Stack(
          children: [
            FutureBuilder<List<PrintJob>>(
              future: _jobs,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snap.error}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                final jobs = snap.data ?? [];
                if (jobs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.print_disabled,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No held jobs.'),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: jobs.length,
                  itemBuilder: (context, i) => JobCard(
                    job: jobs[i],
                    onRelease: _releasing ? null : () => _release(jobs[i]),
                  ),
                );
              },
            ),
            if (_releasing)
              Container(
                color: Colors.black.withOpacity(0.1),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
