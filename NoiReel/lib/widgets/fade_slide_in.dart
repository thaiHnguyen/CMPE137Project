import 'package:flutter/material.dart';

/// Fades its child in while sliding it up a little, the first time it
/// appears. Used on every page so content eases in instead of popping in
///
/// Give items in a list increasing [delay]s (see [FadeSlideIn.staggered])
/// so they appear one after another. Skipped when the device asks for
/// reduced motion
class FadeSlideIn extends StatefulWidget {
  /// Animates [child] in after [delay]
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = defaultDuration,
    this.distance = 24,
  });

  /// Animates the [index]th item of a list in, a little after the one
  /// before it. Items past [maxSteps] all share the last delay, so long
  /// lists don't keep the user waiting
  factory FadeSlideIn.staggered({
    Key? key,
    required int index,
    required Widget child,
    Duration step = const Duration(milliseconds: 60),
    int maxSteps = 8,
    Duration duration = defaultDuration,
    double distance = 24,
  }) =>
      FadeSlideIn(
        key: key,
        delay: step * (index < maxSteps ? index : maxSteps),
        duration: duration,
        distance: distance,
        child: child,
      );

  /// How long the fade and slide take
  static const defaultDuration = Duration(milliseconds: 500);

  final Widget child;
  final Duration delay;     // Wait before starting
  final Duration duration;  // Length of the animation itself
  final double distance;    // Pixels the child slides up from

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  // One controller covers the delay and the animation, so there are no
  // timers to cancel if the widget goes away early
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delayFraction,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  double get _delayFraction {
    final total = (widget.delay + widget.duration).inMicroseconds;
    return total == 0 ? 0 : widget.delay.inMicroseconds / total;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1; // reduced motion: show right away
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _progress.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _progress.value) * widget.distance),
          child: child,
        ),
      ),
    );
  }
}
