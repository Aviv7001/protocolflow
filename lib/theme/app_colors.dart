import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF156F7A);
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF2DA8B8);
  static const onSecondary = Color(0xFFFFFFFF);

  // Backgrounds
  static const scaffoldBackground = Color(0xFFF7F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFEEF4F5);
  static const outline = Color(0xFFAEBCC1);
  static const outlineVariant = Color(0xFFD8E1E4);

  // Text
  static const textPrimary = Color(0xFF1F2933);
  static const textSecondary = Color(0xFF61717A);
  static const textDisabled = Color(0xFFAAB5BA);

  // Status
  static const success = Color(0xFF2EAD62);
  static const warning = Color(0xFFF4A524);
  static const error = Color(0xFFD64545);
  static const info = Color(0xFF2F80ED);

  // Interaction
  static const primaryContainer = Color(0xFFD7F0F3);
  static const onPrimaryContainer = Color(0xFF0F4D54);
  static const hover = Color(0xFFE7F6F8);
  static const pressed = Color(0xFFC3E8EC);
  static const focus = Color(0xFF4FB8C4);

  // Reserved for future AI features.
  static const aiPrimary = Color(0xFF7C5CFA);
  static const aiBackground = Color(0xFFF2EEFF);
}

@immutable
class ProtocolFlowColors extends ThemeExtension<ProtocolFlowColors> {
  const ProtocolFlowColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.hover,
    required this.pressed,
    required this.focus,
    required this.textDisabled,
    required this.aiPrimary,
    required this.aiBackground,
  });

  const ProtocolFlowColors.light()
    : success = AppColors.success,
      warning = AppColors.warning,
      info = AppColors.info,
      hover = AppColors.hover,
      pressed = AppColors.pressed,
      focus = AppColors.focus,
      textDisabled = AppColors.textDisabled,
      aiPrimary = AppColors.aiPrimary,
      aiBackground = AppColors.aiBackground;

  final Color success;
  final Color warning;
  final Color info;
  final Color hover;
  final Color pressed;
  final Color focus;
  final Color textDisabled;
  final Color aiPrimary;
  final Color aiBackground;

  @override
  ProtocolFlowColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? hover,
    Color? pressed,
    Color? focus,
    Color? textDisabled,
    Color? aiPrimary,
    Color? aiBackground,
  }) {
    return ProtocolFlowColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      hover: hover ?? this.hover,
      pressed: pressed ?? this.pressed,
      focus: focus ?? this.focus,
      textDisabled: textDisabled ?? this.textDisabled,
      aiPrimary: aiPrimary ?? this.aiPrimary,
      aiBackground: aiBackground ?? this.aiBackground,
    );
  }

  @override
  ProtocolFlowColors lerp(
    covariant ThemeExtension<ProtocolFlowColors>? other,
    double t,
  ) {
    if (other is! ProtocolFlowColors) return this;
    return ProtocolFlowColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      pressed: Color.lerp(pressed, other.pressed, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      aiPrimary: Color.lerp(aiPrimary, other.aiPrimary, t)!,
      aiBackground: Color.lerp(aiBackground, other.aiBackground, t)!,
    );
  }
}

extension ProtocolFlowThemeColors on BuildContext {
  ProtocolFlowColors get appColors =>
      Theme.of(this).extension<ProtocolFlowColors>()!;
}
