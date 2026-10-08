import 'package:flutter/material.dart';

/// Motion that respects the conventions of the platform it is running on.
///
/// Flutter's own guidance is that a shared component should feel at home on
/// both platforms rather than importing one platform's motion language into the
/// other. The differences that matter for a full-screen journey:
///
/// * **iOS** uses a slower, continuous curve with no overshoot. Pages feel like
///   sheets sliding past each other. Anything that bounces reads as broken.
/// * **Android** uses Material's emphasized easing: quicker to accelerate,
///   slower to settle, and a small overshoot on entry. A linear or long iOS
///   curve feels sluggish on Android.
///
/// Durations are kept close on purpose. A much faster Android animation reads as
/// a cut, and a much slower iOS one reads as a stall.
class PlatformMotion {
  const PlatformMotion._();

  /// How long a page-to-page transition takes.
  static const Duration pageDuration = Duration(milliseconds: 380);

  /// Curve for a page advance.
  static Curve pageForward(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => Curves.easeInOutCubic,
    _ => Curves.easeOutCubic,
  };

  /// Curve for going back. Returning is lighter than advancing because the
  /// user is undoing rather than committing.
  static Curve pageBackward(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => Curves.easeOutCubic,
    _ => Curves.easeOutCubic,
  };

  /// Material's emphasized-decelerate, used for entering elements.
  static Curve enter(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => Curves.easeOutCubic,
    _ => Curves.easeOutBack,
  };

  /// Curve for elements that leave the screen.
  static Curve exit(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => Curves.easeInCubic,
    _ => Curves.easeInCubic,
  };

  /// Stagger delay between consecutive list items. Long enough to read as a
  /// sequence, short enough that the last item is not left feeling late.
  static Duration stagger(TargetPlatform platform, int index) {
    // iOS tends to move things as a group; Android staggers more visibly.
    final step = switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 30,
      _ => 55,
    };
    return Duration(milliseconds: step * index);
  }

  /// Spring used for press feedback, tuned to the platform's feel.
  static const SpringDescription pressSpring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 30,
  );

  /// Softer spring for celebratory motion.
  static const SpringDescription softSpring = SpringDescription(
    mass: 1.4,
    stiffness: 260,
    damping: 22,
  );
}

/// Builds a page transition for a [PageView].
///
/// The default [PageView] transition slides content horizontally, which is
/// correct for a linear stepper like onboarding. This variant adds a slight
/// scale and fade so a slide feels like it is being replaced rather than merely
/// translated, and it collapses to an instant cut under reduced motion.
class PlatformPageTransition extends PageTransitionsBuilder {
  const PlatformPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final platform = Theme.of(context).platform;
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final entering = CurvedAnimation(
      parent: animation,
      curve: PlatformMotion.pageForward(platform),
      reverseCurve: PlatformMotion.exit(platform),
    );

    // A small backward slide on exit gives the sense of depth between pages
    // without the exaggerated parallax some builders use.
    final leaving = CurvedAnimation(
      parent: secondaryAnimation,
      curve: PlatformMotion.pageBackward(platform),
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(entering),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(entering),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(0, -0.02),
          ).animate(leaving),
          child: child,
        ),
      ),
    );
  }
}
