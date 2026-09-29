import '../enums/http_status.dart';

class ApiResponse<T> {
  const ApiResponse({
    required this.data,
    required this.statusCode,
    this.headers = const {},
  });

  final T data;
  final int? statusCode;
  final Map<String, List<String>> headers;

  StatusCategory get category => StatusCategory.of(statusCode);
  bool get isSuccess => category == StatusCategory.success;

  String? header(String name) => headers[name.toLowerCase()]?.join(', ');
}
