import 'package:flutter/foundation.dart';

/// Bumped whenever the user's Favorites, Watchlist or reviews change on
/// any page, so pages that show them (like Profile's Favorite and
/// Watchlist tabs, which stay alive in the background) know to reload
final libraryChanged = ValueNotifier<int>(0);

/// Tells listeners of [libraryChanged] to reload
void notifyLibraryChanged() => libraryChanged.value++;
