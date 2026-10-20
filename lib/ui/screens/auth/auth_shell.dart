import 'package:flutter/material.dart';
import 'package:standup_app/core/app_spacing.dart';
import 'package:standup_app/core/app_strings.dart';

/// Shared frame for the account screens: logo, heading, subtitle and a centred,
/// scrollable column that still fits a 320 px phone with the keyboard open.
///
/// The sign-in, create-account and recovery screens are the same page with
/// different fields. Keeping the frame here means the three cannot drift into
/// three different logos, three widths and three header rhythms.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.titleKey,
    required this.subtitleKey,
    required this.children,
  });

  /// English dictionary key for the heading.
  final String titleKey;

  /// English dictionary key for the sentence below it.
  final String subtitleKey;

  /// The form itself: banners, fields, primary action and secondary links.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = isCompact ? AppSpace.huge : AppSpace.gutter;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal,
                vertical: AppSpace.gutter,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - AppSpace.gutter * 2)
                      .clamp(0.0, double.infinity)
                      .toDouble(),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBrand(context, accent),
                          const SizedBox(height: AppSpace.gutter),
                          Text(
                            appString(context, titleKey),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: AppSpace.md),
                          Text(
                            appString(context, subtitleKey),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xxl),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrand(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 84,
          height: 76,
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpace.xxl),
            border: Border.all(color: accent.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpace.xl),
            child: Image.asset(
              'assets/branding/CNPS_standup_logo.png',
              fit: BoxFit.contain,
              semanticLabel: 'CNPS StandUp',
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          appString(context, 'StandUp'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

/// An inline explanation above the form: a failed attempt or a sent email.
class AuthBanner extends StatelessWidget {
  const AuthBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpace.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(text, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}
