import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/auth_service.dart';
import 'package:server/db.dart';

final _auth = AuthService.withPool(db);

/// Makes [AuthService] available to every route under /auth
/// Tests can provide a mock instead.
Handler middleware(Handler handler) {
  return handler.use(provider<AuthService>((_) => _auth));
}
