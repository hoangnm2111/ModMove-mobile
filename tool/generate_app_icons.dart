import 'dart:io';

/// Export density variants, then retain the white-tinted adaptive foreground.
Future<void> main() async {
  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    'flutter_launcher_icons',
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    exitCode = result.exitCode;
    return;
  }
  final adaptive = File(
    'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
  );
  final xml = await adaptive.readAsString();
  await adaptive.writeAsString(
    xml.replaceAll(
      '@drawable/ic_launcher_foreground"',
      '@drawable/ic_launcher_foreground_white"',
    ),
  );
}
