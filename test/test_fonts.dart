import 'dart:io';
import 'package:flutter/services.dart';

/// Flutter tests draw text with a placeholder font whose letters are far wider
/// than any real font, which produces false overflow errors. Load Roboto and
/// the Material icons from the SDK so layout is checked with realistic widths.
/// Does nothing when the SDK fonts cannot be found.
Future<void> loadTestFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, Map<String, int> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final name in files.keys) {
      final f = File('$dir/$name');
      if (!f.existsSync()) continue;
      any = true;
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    if (any) await loader.load();
  }

  await load('Roboto', {
    'Roboto-Regular.ttf': 400,
    'Roboto-Medium.ttf': 500,
    'Roboto-Bold.ttf': 700,
    'Roboto-Black.ttf': 900,
  });
  await load('MaterialIcons', {'MaterialIcons-Regular.otf': 400});
}
