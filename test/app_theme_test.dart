import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/theme/app_colors.dart';
import 'package:protocolflow/theme/app_theme.dart';

void main() {
  test('light theme exposes the ProtocolFlow design-system colors', () {
    final theme = ProtocolFlowTheme.lightTheme;
    final colors = theme.extension<ProtocolFlowColors>();

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.onPrimary, AppColors.onPrimary);
    expect(theme.colorScheme.secondary, AppColors.secondary);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.colorScheme.surfaceContainer, AppColors.surfaceContainer);
    expect(theme.colorScheme.onSurface, AppColors.textPrimary);
    expect(theme.colorScheme.onSurfaceVariant, AppColors.textSecondary);
    expect(theme.colorScheme.outline, AppColors.outline);
    expect(theme.colorScheme.outlineVariant, AppColors.outlineVariant);
    expect(theme.colorScheme.error, AppColors.error);
    expect(theme.scaffoldBackgroundColor, AppColors.scaffoldBackground);
    expect(colors?.success, AppColors.success);
    expect(colors?.warning, AppColors.warning);
    expect(colors?.info, AppColors.info);
    expect(colors?.aiPrimary, AppColors.aiPrimary);
    expect(colors?.aiBackground, AppColors.aiBackground);
  });

  test('app bars and primary buttons use the brand colors', () {
    final theme = ProtocolFlowTheme.lightTheme;

    expect(theme.appBarTheme.backgroundColor, AppColors.primary);
    expect(theme.appBarTheme.foregroundColor, AppColors.onPrimary);
    expect(theme.tabBarTheme.labelColor, AppColors.primary);
    expect(theme.tabBarTheme.unselectedLabelColor, AppColors.primary);
    expect(theme.tabBarTheme.indicatorColor, AppColors.primary);

    final buttonStyle = theme.elevatedButtonTheme.style!;
    expect(buttonStyle.backgroundColor?.resolve({}), AppColors.primary);
    expect(buttonStyle.foregroundColor?.resolve({}), AppColors.onPrimary);
  });
}
