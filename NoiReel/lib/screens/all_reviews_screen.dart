import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_scope.dart';
import '../widgets/dialogs.dart';
import '../widgets/review_card.dart';
import 'review_screen.dart';

/// Every review of a title, most liked first, loading more as you scroll.
/// Opened from "All reviews" on the details page. Returns true when it
/// closes if any review changed (a like, a comment, an edit)
class AllReviewsScreen extends StatefulWidget {
  /// Creates the page for [title]'s reviews
  const AllReviewsScreen({super.key, required this.api, required this.title});

  final ApiClient api;
  final TitleCard title;

  /// Reviews per page loaded from the server
  static const pageSize = 20;

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  final _scroll = ScrollController();
  List<Review> _reviews = [];
  int _total = 0;
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _changed = false;
  String? _error;
  bool _started = false;

  bool get _hasMore => _reviews.length < _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _loadFirst();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String? get _token => AuthScope.maybeOf(context)?.value?.token;

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.getReviews(
        widget.title.id,
        token: _token,
        limit: AllReviewsScreen.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _reviews = page.reviews;
        _total = page.total;
        _page = 1;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 600) _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await widget.api.getReviews(
        widget.title.id,
        token: _token,
        page: _page + 1,
        limit: AllReviewsScreen.pageSize,
      );
      if (!mounted) return;
      setState(() {
        final shown = {for (final r in _reviews) r.id};
        _reviews = [
          ..._reviews,
          ...page.reviews.where((r) => !shown.contains(r.id)),
        ];
        _total = page.total;
        _page++;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(Review review) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          api: widget.api,
          reviewId: review.id,
          preview: review,
        ),
      ),
    );
    if (changed ?? false) {
      _changed = true;
      if (mounted) _loadFirst();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyText = Theme.of(context).colorScheme.onSurface;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: BackTextButton.width,
          leading: const BackTextButton(),
          title: const Text('Reviews'),
        ),
        body: RefreshIndicator(
          onRefresh: _loadFirst,
          child: _loading
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                )
              : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [Text(_error!, textAlign: TextAlign.center)],
                )
              : ListView.separated(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: _reviews.length + 1,
                  separatorBuilder: (_, _) => Divider(
                    indent: 74,
                    height: 1,
                    color: bodyText.withValues(alpha: 0.15),
                  ),
                  itemBuilder: (context, i) {
                    if (i == _reviews.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : const SizedBox(height: 36),
                        ),
                      );
                    }
                    return ReviewCard(
                      api: widget.api,
                      review: _reviews[i],
                      onTap: () => _open(_reviews[i]),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
