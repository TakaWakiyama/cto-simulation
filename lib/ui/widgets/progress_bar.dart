import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GameProgressBar extends StatelessWidget {
  const GameProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.backgroundColor,
    this.showPercentage = false,
    this.label,
  });

  final double value; // 0.0 - 1.0
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final bool showPercentage;
  final String? label;

  Color get _defaultColor {
    if (value > 0.8) return AppColors.progressGreen;
    if (value > 0.4) return AppColors.progressOrange;
    return AppColors.progressRed;
  }

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? _defaultColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (showPercentage)
                  Text(
                    '${(value * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: barColor,
                    ),
                  ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: backgroundColor ?? AppColors.progressBg,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
      ],
    );
  }
}
