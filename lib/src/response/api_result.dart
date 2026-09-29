import '../error/api_exception.dart';

/// Success-or-failure wrapper, for callers that prefer not to use try/catch.
sealed class ApiResult<T> {
  const ApiResult();

  static Future<ApiResult<T>> guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on ApiException catch (e) {
      return Failure(e);
    } catch (e, st) {
      return Failure(ApiException.fromError(e, st));
    }
  }

  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException error) failure,
  }) =>
      switch (this) {
        Success(:final data) => success(data),
        Failure(:final error) => failure(error),
      };

  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        Failure() => null,
      };

  ApiException? get errorOrNull => switch (this) {
        Success() => null,
        Failure(:final error) => error,
      };

  bool get isSuccess => this is Success<T>;
}

final class Success<T> extends ApiResult<T> {
  const Success(this.data);
  final T data;
}

final class Failure<T> extends ApiResult<T> {
  const Failure(this.error);
  final ApiException error;
}
