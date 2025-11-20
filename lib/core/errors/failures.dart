// core/error/failures.dart
abstract class Failure {
  final String message;
  Failure(this.message);
}

class ServerFailure extends Failure {
  ServerFailure(String message) : super(message);

  @override
  String toString() => 'ServerFailure: $message';
}

class CacheFailure extends Failure {
  CacheFailure(String message) : super(message);

  @override
  String toString() => 'CacheFailure: $message';
}
