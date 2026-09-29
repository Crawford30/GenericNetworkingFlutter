import 'dart:io';

Future<bool> fileExists(String path) => File(path).exists();

String joinPath(String directory, String fileName) {
  final sep = Platform.pathSeparator;
  return directory.endsWith(sep) ? '$directory$fileName' : '$directory$sep$fileName';
}
