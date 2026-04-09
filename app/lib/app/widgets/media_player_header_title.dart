import 'package:flutter/material.dart';

class MediaPlayerHeaderTitle extends StatelessWidget {
  const MediaPlayerHeaderTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.subtitleColor,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 1,
    this.fallbackTitle = '',
  });

  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? subtitleColor;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final String fallbackTitle;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title.trim().isEmpty ? fallbackTitle : title.trim();
    final resolvedSubtitle = subtitle?.trim() ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          resolvedTitle,
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (resolvedSubtitle.isNotEmpty)
          Text(
            resolvedSubtitle,
            maxLines: subtitleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: subtitleColor),
          ),
      ],
    );
  }
}
