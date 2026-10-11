import 'package:dart_frog/dart_frog.dart';
import 'package:server/db.dart';

Future<Response> onRequest(RequestContext context) async {
  try {
    await db.execute('SELECT 1');
    return Response.json(body: {'status': 'ok', 'db': 'connected'});
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'status': 'error', 'detail': '$e'},
    );
  }
}
