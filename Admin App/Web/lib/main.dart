import 'package:flutter/material.dart';
import 'package:ssd_shared/ssd_shared.dart';

/// Entry point for SSD Farm — Admin (Web).
/// Phase 1 TODO: call Firebase.initializeApp() here once
/// google-services.json / GoogleService-Info.plist are added
/// (see docs/SSD_Farm_Development_Plan.docx, Phase 1).
void main() {
  runApp(const SsdApp());
}

class SsdApp extends StatelessWidget {
  const SsdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSD Farm — Admin (Web)',
      theme: AppTheme.light,
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSD Farm — Admin (Web)')),
      body: const Center(
        child: Text('Phase 1 starting point — login screen goes here.'),
      ),
    );
  }
}
