import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
export '../theme/app_colors.dart';

class Brand extends StatelessWidget {
  const Brand({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: large ? 48 : 38,
        height: large ? 48 : 38,
        decoration: BoxDecoration(
          color: context.colors.blue,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          Icons.shield_outlined,
          color: context.colors.onBlue,
          size: large ? 28 : 23,
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'SecretPod',
            style: TextStyle(
              fontSize: large ? 26 : 23,
              fontWeight: FontWeight.w600,
              letterSpacing: -.8,
              color: context.colors.ink,
            ),
          ),
        ),
      ),
    ],
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class EnvironmentBadge extends StatelessWidget {
  const EnvironmentBadge(this.environment, {super.key});
  final String environment;
  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (environment) {
      'Production' => (context.colors.success, context.colors.successContainer),
      'Staging' => (context.colors.warning, context.colors.warningContainer),
      _ => (context.colors.blue, context.colors.blueContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 6),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              environment,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData kindIcon(String kind) => switch (kind) {
  'API key' => Icons.key_rounded,
  'Environment variable' => Icons.data_object_rounded,
  'Password' => Icons.password_rounded,
  'Username and password' => Icons.manage_accounts_outlined,
  'Certificate' => Icons.verified_outlined,
  _ => Icons.lock_outline,
};
String calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

bool secretExpired(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).isBefore(DateTime.utc(today.year, today.month, today.day));
}

String expiryLabel(DateTime? date) => date == null
    ? 'Never expires'
    : '${secretExpired(date) ? 'Expired' : 'Expires'} ${calendarDate(date)}';

class RotationLabel extends StatelessWidget {
  const RotationLabel({super.key});
  @override
  Widget build(BuildContext context) => Text(
    'Needs rotating',
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: context.colors.danger,
    ),
  );
}

class ExpiryLabel extends StatelessWidget {
  const ExpiryLabel(this.date, {super.key});
  final DateTime? date;
  @override
  Widget build(BuildContext context) => Text(
    expiryLabel(date),
    style: TextStyle(
      fontSize: 12,
      color: date != null && secretExpired(date!)
          ? Theme.of(context).colorScheme.error
          : context.colors.muted,
    ),
  );
}

String friendlyDate(DateTime time) {
  final d = time.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: context.colors.emptyPanel,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Icon(icon, color: context.colors.blue, size: 36),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.muted, height: 1.5),
          ),
        ),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}
