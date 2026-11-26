import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/profile_dao.dart';
import 'package:server/profile/avatar_files.dart';

/// POST   /me/profile/avatar   multipart/form-data with an `avatar` file
///        (JPEG, PNG or WebP, up to 5 MB). Replaces your avatar
///        200 {profile}   400 {error: "invalid", field: "avatar", message}
///        413 too big
/// DELETE /me/profile/avatar   back to the default picture
///        200 {profile}
/// Both need `Authorization: Bearer <token>` (401 if not logged in)
Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method;
  if (method != HttpMethod.post && method != HttpMethod.delete) {
    return methodNotAllowed();
  }

  final user = await currentUser(context);
  if (user == null) return notLoggedIn();
  final profiles = context.read<ProfileDao>();
  final files = context.read<AvatarFiles>();

  String? newUrl;
  if (method == HttpMethod.post) {
    // Turn away big uploads before reading them into memory
    final length = int.tryParse(
      context.request.headers['content-length'] ?? '',
    );
    if (length != null && length > AvatarFiles.maxBytes + 64 * 1024) {
      return _tooBig();
    }

    final FormData form;
    try {
      form = await context.request.formData();
    } on Exception {
      return _invalid('Send the photo as multipart/form-data.');
    }
    final upload = form.files['avatar'];
    if (upload == null) return _invalid('Choose a photo to upload.');

    final bytes = await upload.readAsBytes();
    if (bytes.length > AvatarFiles.maxBytes) return _tooBig();
    final type = AvatarFiles.imageType(bytes);
    if (type == null) return _invalid('Use a JPEG, PNG or WebP photo.');

    newUrl = await files.save(user.userId, bytes, type);
  }

  final oldUrl = await profiles.setAvatar(user.userId, newUrl);
  await files.delete(oldUrl);

  final profile = await profiles.find(user.userId);
  if (profile == null) return notFound('Profile');
  return Response.json(body: {'profile': profile.toJson()});
}

Response _invalid(String message) => Response.json(
  statusCode: 400,
  body: {'error': 'invalid', 'field': 'avatar', 'message': message},
);

Response _tooBig() => Response.json(
  statusCode: 413,
  body: {
    'error': 'too_large',
    'field': 'avatar',
    'message': 'That photo is too big. Pick one under 5 MB.',
  },
);
