import 'dart:io';

/// Saves avatar images under `public/avatars/`, which Dart Frog serves
/// as-is at `/avatars/<file>`
class AvatarFiles {
  /// Creates the store. [root] is the server folder (the working
  /// directory when `dart_frog dev` runs)
  AvatarFiles({String root = '.'}) : _dir = Directory('$root/public/avatars');

  final Directory _dir;

  /// Biggest upload accepted, in bytes. The app shrinks photos well
  /// below this before sending
  static const maxBytes = 5 * 1024 * 1024;

  /// The image type of [bytes] from its first bytes ("magic number"):
  /// `jpg`, `png` or `webp`, or null for anything else
  static String? imageType(List<int> bytes) {
    bool startsWith(List<int> magic, [int offset = 0]) {
      if (bytes.length < offset + magic.length) return false;
      for (var i = 0; i < magic.length; i++) {
        if (bytes[offset + i] != magic[i]) return false;
      }
      return true;
    }

    if (startsWith([0xFF, 0xD8, 0xFF])) return 'jpg';
    if (startsWith([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'png';
    }
    if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) {
      return 'webp';
    }
    return null;
  }

  /// Writes a new avatar for [userId] and returns its URL path. The name
  /// includes the time, so a changed avatar never shows a cached old one
  Future<String> save(int userId, List<int> bytes, String type) async {
    await _dir.create(recursive: true);
    final name = '$userId-${DateTime.now().millisecondsSinceEpoch}.$type';
    await File('${_dir.path}/$name').writeAsBytes(bytes, flush: true);
    return '/avatars/$name';
  }

  /// Deletes a file [save] wrote. Anything else (e.g. an outside URL) is
  /// left alone
  Future<void> delete(String? url) async {
    if (url == null || !url.startsWith('/avatars/')) return;
    final name = url.substring('/avatars/'.length);
    if (name.contains('/') || name.contains('..')) return;
    final file = File('${_dir.path}/$name');
    if (file.existsSync()) await file.delete();
  }
}
