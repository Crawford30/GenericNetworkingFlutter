Future<bool> fileExists(String path) async => false;

String joinPath(String directory, String fileName) =>
    directory.endsWith('/') ? '$directory$fileName' : '$directory/$fileName';
