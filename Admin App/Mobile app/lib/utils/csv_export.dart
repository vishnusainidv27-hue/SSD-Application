import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [headers] + [rows] as a CSV file and opens the share sheet so Admin
/// can save or send it — every report is exportable (Requirements §4.9). PDF
/// and Excel export are left for later; CSV opens directly in Excel/Sheets
/// and covers every report with one small utility rather than pulling in a
/// PDF-generation library for this already-large phase.
Future<void> exportCsv(
  BuildContext context, {
  required String filename,
  required List<String> headers,
  required List<List<String>> rows,
}) async {
  final buffer = StringBuffer()..writeln(headers.map(_escape).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(_escape).join(','));
  }
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(buffer.toString());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: filename),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export. Please try again.')));
    }
  }
}

String _escape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
