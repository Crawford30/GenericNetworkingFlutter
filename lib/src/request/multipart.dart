import 'dart:typed_data';

import 'package:dio/dio.dart';

enum MimeType {
  jpeg('image/jpeg'),
  png('image/png'),
  gif('image/gif'),
  heic('image/heic'),
  pdf('application/pdf'),
  doc('application/msword'),
  docx('application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
  xlsx('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  csv('text/csv'),
  octetStream('application/octet-stream');

  const MimeType(this.value);

  final String value;

  static MimeType? fromFileName(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => jpeg,
      'png' => png,
      'gif' => gif,
      'heic' => heic,
      'pdf' => pdf,
      'doc' => doc,
      'docx' => docx,
      'xlsx' => xlsx,
      'csv' => csv,
      _ => null,
    };
  }
}

/// A file to upload, from memory ([bytes]) or disk ([path], not on web).
class UploadableFile {
  UploadableFile.fromBytes(
    Uint8List this.bytes, {
    required this.fileName,
    this.fieldName = 'file',
    String? mimeType,
  })  : path = null,
        mimeType = mimeType ?? MimeType.fromFileName(fileName)?.value;

  UploadableFile.fromPath(
    String this.path, {
    String? fileName,
    this.fieldName = 'file',
    String? mimeType,
  })  : bytes = null,
        fileName = fileName ?? path.split(RegExp(r'[/\\]')).last,
        mimeType = mimeType ??
            MimeType.fromFileName(fileName ?? path)?.value;

  final Uint8List? bytes;
  final String? path;
  final String fileName;

  /// Form field name the server expects, e.g. `document`.
  final String fieldName;
  final String? mimeType;

  Future<MultipartFile> toMultipartFile() async {
    final contentType = DioMediaType.parse(mimeType ?? MimeType.octetStream.value);
    if (bytes != null) {
      return MultipartFile.fromBytes(bytes!, filename: fileName, contentType: contentType);
    }
    return MultipartFile.fromFile(path!, filename: fileName, contentType: contentType);
  }
}

/// Files plus plain form fields, sent as `multipart/form-data`.
class MultipartBody {
  const MultipartBody({this.files = const [], this.fields = const {}});

  final List<UploadableFile> files;
  final Map<String, Object?> fields;

  Future<FormData> toFormData() async {
    final form = FormData();
    for (final file in files) {
      form.files.add(MapEntry(file.fieldName, await file.toMultipartFile()));
    }
    await _appendFields(form, fields);
    return form;
  }
}

/// Builds [FormData] from a plain map, like the RN `createFormData` helper.
/// [UploadableFile] values become file parts, lists repeat the key, and
/// everything else is stringified.
Future<FormData> createFormData(Map<String, Object?> params) async {
  final form = FormData();
  await _appendFields(form, params);
  return form;
}

Future<void> _appendFields(FormData form, Map<String, Object?> params) async {
  for (final entry in params.entries) {
    final values = entry.value is List ? entry.value as List : [entry.value];
    for (final value in values) {
      if (value == null) continue;
      if (value is UploadableFile) {
        form.files.add(MapEntry(entry.key, await value.toMultipartFile()));
      } else if (value is DateTime) {
        form.fields.add(MapEntry(entry.key, value.toUtc().toIso8601String()));
      } else {
        form.fields.add(MapEntry(entry.key, value.toString()));
      }
    }
  }
}
