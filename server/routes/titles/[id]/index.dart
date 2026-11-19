import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/title_dao.dart';

/// GET /titles/:id
/// 200 title details with moods and vote totals - 404 no such title
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();

  final titleId = parseId(id);
  final title = titleId == null
      ? null
      : await context.read<TitleDao>().findDetails(titleId);
  if (title == null) return notFound('Title');

  return Response.json(body: title.toJson());
}
