class DownloadedFile {
  const DownloadedFile({
    required this.path,
    required this.fileName,
    this.statusCode,
    this.contentType,
  });

  final String path;
  final String fileName;
  final int? statusCode;
  final String? contentType;

  @override
  String toString() => 'DownloadedFile($path)';
}
