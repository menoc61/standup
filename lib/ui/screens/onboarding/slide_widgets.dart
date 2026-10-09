import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/ui/widgets/posture_avatar.dart';
import 'package:standup_app/ui/widgets/spring_button.dart';

// ---------------------------------------------------------------------------
// Slide 1: Welcome
// ---------------------------------------------------------------------------
class WelcomeSlide extends StatelessWidget {
  final Color accentColor;

  const WelcomeSlide({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PostureAvatar(
            isStanding: true,
            stretchProgress: 0.6,
            accentColor: accentColor,
            size: 180,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              appString(context, 'HEALTH & WELLNESS CADENCE'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            appString(context, 'StandUp Ergonomics'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            appString(
              context,
              'Gentle reminders to move for 5 minutes every hour, combat sedentary strain, and keep your body energised at work.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 2: The Problem
// ---------------------------------------------------------------------------
class TheProblemSlide extends StatelessWidget {
  final Color accentColor;

  const TheProblemSlide({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PostureAvatar(
            isStanding: false,
            accentColor: AppColors.skipped,
            size: 160,
          ),
          const SizedBox(height: 24),
          Text(
            appString(context, 'The Sedentary Trap'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            appString(
              context,
              'Sitting continuously for 6+ hours daily compresses the lumbar spine, decreases blood circulation by 50%, and causes chronic posture fatigue.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildRiskRow(
            Icons.airline_seat_recline_extra,
            appString(context, 'Spinal Compression'),
            appString(context, 'Lumbar strain & shoulder stiffness'),
          ),
          const SizedBox(height: 10),
          _buildRiskRow(
            Icons.favorite_border,
            appString(context, 'Metabolic Sluggishness'),
            appString(context, 'Drop in circulation & calorie burn'),
          ),
          const SizedBox(height: 10),
          _buildRiskRow(
            Icons.battery_alert,
            appString(context, 'Energy Crashes'),
            appString(context, 'Afternoon brain fog & posture slump'),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskRow(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.skipped.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.skipped.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.skipped, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 3: The Solution
// ---------------------------------------------------------------------------
class TheSolutionSlide extends StatelessWidget {
  final Color accentColor;

  const TheSolutionSlide({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PostureAvatar(
            isStanding: true,
            stretchProgress: 0.85,
            accentColor: accentColor,
            size: 170,
          ),
          const SizedBox(height: 24),
          Text(
            appString(context, 'The 5-Minute Solution'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            appString(
              context,
              'Standing and stretching for just 5 minutes every hour resets your musculoskeletal balance, revives oxygen to the brain, and keeps posture aligned.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildBenefitRow(
            Icons.check_circle_outline,
            appString(context, '+32% Sustained Focus'),
            appString(context, 'Oxygen boost resets mental clarity'),
            accentColor,
          ),
          const SizedBox(height: 10),
          _buildBenefitRow(
            Icons.accessibility_new,
            appString(context, 'Zero Lower Back Strain'),
            appString(context, 'Intervertebral discs decompress'),
            accentColor,
          ),
          const SizedBox(height: 10),
          _buildBenefitRow(
            Icons.trending_up,
            appString(context, 'Passive Caloric Health'),
            appString(context, 'Engages major stabilizer muscle groups'),
            accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(
    IconData icon,
    String title,
    String desc,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 4: How It Works
// ---------------------------------------------------------------------------
class HowItWorksSlide extends StatelessWidget {
  final Color accentColor;

  const HowItWorksSlide({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            appString(context, 'How StandUp Works'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            appString(
              context,
              'A frictionless rhythm engineered around deep work without intrusive disruption.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          _buildStepCard(
            context,
            '1',
            'Gentle Scheduled Chimes',
            'Soft acoustic tones notify you when it is time to rise.',
            accentColor,
          ),
          const SizedBox(height: 12),
          _buildStepCard(
            context,
            '2',
            'One-Tap Actions',
            '"I Stood Up" logs 5 min active time. "Snooze 10m" pauses if you are presenting.',
            AppColors.snoozed,
          ),
          const SizedBox(height: 12),
          _buildStepCard(
            context,
            '3',
            'Intelligent Nudge Logic',
            'If you skip 3 times, StandUp gently reminds you why your back needs relief.',
            AppColors.completed,
          ),
          const SizedBox(height: 12),
          _buildStepCard(
            context,
            '4',
            'GitHub-Style Analytics',
            'Watch your consistency matrix glow with emerald green squares.',
            accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(
    BuildContext context,
    String num,
    String title,
    String desc,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appString(context, title),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  appString(context, desc),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 5: User Profile Setup
// ---------------------------------------------------------------------------
class ProfileSetupSlide extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController designationController;
  final TextEditingController emailController;
  final String selectedDepartment;
  final ValueChanged<String?> onDepartmentChanged;
  final Color accentColor;

  const ProfileSetupSlide({
    super.key,
    required this.nameController,
    required this.designationController,
    required this.emailController,
    required this.selectedDepartment,
    required this.onDepartmentChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final departments = [
      'Engineering',
      'Product & Design',
      'Marketing & Sales',
      'People & Ops',
      'Finance',
      'Leadership',
    ];

    // The onboarding shell already provides a scroll view, so this slide must
    // not nest a second one on the same axis.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            appString(context, 'Personalize Profile'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            appString(
              context,
              'Enter your work details to unlock department wellness benchmarks.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildInput(
            context,
            label: 'Full Name',
            controller: nameController,
            hint: 'e.g. Alex Morgan',
          ),
          const SizedBox(height: 14),
          _buildInput(
            context,
            label: 'Designation / Role',
            controller: designationController,
            hint: 'e.g. Senior Software Engineer',
          ),
          const SizedBox(height: 14),
          _buildInput(
            context,
            label: 'Work Email (Optional)',
            controller: emailController,
            hint: 'name@company.com',
          ),
          const SizedBox(height: 14),
          Text(
            appString(context, 'Department'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedDepartment,
                isExpanded: true,
                items: departments.map((dept) {
                  return DropdownMenuItem(
                    value: dept,
                    child: Text(dept, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: onDepartmentChanged,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInput(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appString(context, label),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 6: Organization Link
// ---------------------------------------------------------------------------
class OrganizationLinkSlide extends StatelessWidget {
  final String detectedOrgName;
  final Color accentColor;

  const OrganizationLinkSlide({
    super.key,
    required this.detectedOrgName,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appString(context, 'Organization Workspace'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            appString(
              context,
              'Join your company workspace to see collective progress and contribute only the daily totals you choose to share.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (detectedOrgName.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, color: accentColor, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appString(context, 'Detected Workspace:'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          detectedOrgName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    appString(
                      context,
                      'After onboarding, connect your account in Settings and use the invite code provided by your organization.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            appString(
              context,
              'Workspace membership is optional. Your individual reminder history stays on this device.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 7: Preferences
// ---------------------------------------------------------------------------
class PreferencesSlide extends StatelessWidget {
  final int selectedFrequency;
  final ValueChanged<int> onFrequencyChanged;
  final String selectedTheme;
  final ValueChanged<String> onThemeChanged;
  final String selectedColor;
  final ValueChanged<String> onColorChanged;
  final bool soundEnabled;
  final ValueChanged<bool> onSoundChanged;
  final VoidCallback onTestSound;

  const PreferencesSlide({
    super.key,
    required this.selectedFrequency,
    required this.onFrequencyChanged,
    required this.selectedTheme,
    required this.onThemeChanged,
    required this.selectedColor,
    required this.onColorChanged,
    required this.soundEnabled,
    required this.onSoundChanged,
    required this.onTestSound,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.getAccentColor(selectedColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            appString(context, 'Preferences & Cadence'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            appString(
              context,
              'Customize your reminder schedule, audio tones, and color palette.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          // Frequency
          Text(
            appString(context, 'Reminder Frequency'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [30, 60, 90].map((mins) {
              final isSel = selectedFrequency == mins;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () => onFrequencyChanged(mins),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel ? accent : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel
                              ? accent
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        formatDurationLabel(context, mins),
                        style: TextStyle(
                          color: isSel
                              ? Colors.white
                              : theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Color System
          Text(
            appString(context, 'Color Accent'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),

          // The swatch list comes from `AppColors.accents` rather than being
          // written out here, so the picker can never offer an option the theme
          // does not know how to render.
          // Wrap rather than Row: six 48dp touch targets are 288dp wide, which is wider
          // than a 320dp phone minus its horizontal padding. A Row overflows
          // outright; a Wrap reflows to a second line instead.
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            runSpacing: 8,
            children: AppColors.accents.map((option) {
              final isSel = selectedColor == option.id;
              final col = option.swatch;
              return Semantics(
                // Each swatch is a real choice, so it is a labelled button
                // rather than an anonymous image. The audit flagged this row
                // for having no name at all.
                button: true,
                selected: isSel,
                label: appString(context, option.label),
                child: Tooltip(
                  message: appString(context, option.label),
                  child: InkWell(
                    onTap: () => onColorChanged(option.id),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      // The visible circle is 38dp; the padding brings the
                      // touch target to 48dp, which is the accessibility floor.
                      padding: const EdgeInsets.all(5),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(
                            // A white ring reads on the light accents but
                            // disappears on the dark 'ink' swatch, so the ring
                            // is drawn in the surface colour instead.
                            color: isSel
                                ? theme.colorScheme.surface
                                : Colors.transparent,
                            width: 3.0,
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: col.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Sound Toggle & Test
          Row(
            children: [
              // Expanded: the French subtitle ("Jouer un son apaisant lors des
              // rappels") plus a 59px switch is wider than a 320dp phone.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appString(context, 'Sound Chimes'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      appString(
                        context,
                        'Play relaxing chimes on break alerts',
                      ),
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: soundEnabled,
                onChanged: onSoundChanged,
                activeThumbColor: accent,
              ),
            ],
          ),
          if (soundEnabled) ...[
            const SizedBox(height: 6),
            SpringButton(
              onTap: onTestSound,
              backgroundColor: accent.withValues(alpha: 0.15),
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up, size: 16),
                  SizedBox(width: 8),
                  Text(
                    appString(context, 'Play Preview Chime'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 8: Permissions
// ---------------------------------------------------------------------------
class PermissionsSlide extends StatelessWidget {
  final bool granted;
  final VoidCallback onRequest;
  final Color accentColor;

  const PermissionsSlide({
    super.key,
    required this.granted,
    required this.onRequest,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active,
              color: accentColor,
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            appString(context, 'System Permissions'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            appString(
              context,
              'To wake you up exactly when 50 or 60 minutes elapse, StandUp needs permission to send local alerts and schedule exact timers.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          SpringButton(
            onTap: onRequest,
            backgroundColor: granted ? AppColors.completed : accentColor,
            isFullWidth: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(granted ? Icons.check_circle : Icons.lock_open, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    appString(
                      context,
                      granted
                          ? 'Permissions Enabled ✓'
                          : 'Enable Notifications & Alarms',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 9: Privacy & Data Architecture
// ---------------------------------------------------------------------------
class PrivacySlide extends StatelessWidget {
  final bool optIn;
  final ValueChanged<bool> onOptInChanged;
  final Color accentColor;

  const PrivacySlide({
    super.key,
    required this.optIn,
    required this.onOptInChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield, color: accentColor, size: 28),
              const SizedBox(width: 10),
              // The longest title in the onboarding in French
              // ("La confidentialité dès la conception") — roughly twice the
              // English length, and it overflowed a 23px headline on every
              // phone.
              Expanded(
                child: Text(
                  appString(context, 'Privacy by Design'),
                  style: theme.textTheme.headlineMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            appString(
              context,
              'We believe employee health monitoring must never compromise personal autonomy.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _buildPrivacyItem(
            context,
            Icons.storage,
            '100% Local Drift Database',
            'Exact reminder timestamps & skip logs stay strictly on your device.',
          ),
          const SizedBox(height: 12),
          _buildPrivacyItem(
            context,
            Icons.cloud_sync,
            'Anonymized Aggregates',
            'Only daily counts (e.g. 7 stands completed) sync to Supabase for company metrics.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appString(context, 'Contribute to Org Statistics'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        appString(
                          context,
                          'Help leadership understand posture wellness trends.',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: optIn,
                  onChanged: onOptInChanged,
                  activeThumbColor: accentColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyItem(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appString(context, title),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                appString(context, desc),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 10: Ready To Go
// ---------------------------------------------------------------------------
class ReadyToGoSlide extends StatelessWidget {
  final VoidCallback onComplete;
  final Color accentColor;

  const ReadyToGoSlide({
    super.key,
    required this.onComplete,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PostureAvatar(
            isStanding: true,
            stretchProgress: 1.0,
            accentColor: accentColor,
            size: 190,
          ),
          const SizedBox(height: 24),
          Text(
            appString(context, 'You Are Ready!'),
            style: theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          Text(
            appString(
              context,
              'Your first cadence cycle has been initialized. Stand up when you hear the gentle chime, stretch your arms, and reclaim your daily vitality.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          SpringButton(
            onTap: onComplete,
            backgroundColor: accentColor,
            isFullWidth: true,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  appString(context, 'Launch StandUp Experience'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
