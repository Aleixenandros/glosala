// Compatibilidad con el renderizador Markdown hasta su migración a material_ui.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

abstract final class TemaAplicacion {
  static const accent = Color(0xFFA693F5);

  static ThemeData build(Brightness brightness, {String tema = 'amatista'}) {
    final dark = brightness == Brightness.dark;
    final semilla = switch (tema) {
      'bosque' => const Color(0xFF428B67),
      'oceano' => const Color(0xFF297FA8),
      'ambar' => const Color(0xFF9C6C21),
      _ => const Color(0xFF8062D6),
    };
    final scheme = ColorScheme.fromSeed(
      seedColor: semilla,
      brightness: brightness,
      surface: dark ? const Color(0xFF1C1C21) : const Color(0xFFFAF9FD),
      primary: tema == 'amatista'
          ? dark
                ? accent
                : const Color(0xFF7154BF)
          : null,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Inter',
      textTheme: Typography.material2021().black.apply(
        bodyColor: dark ? const Color(0xFFDAD9E0) : const Color(0xFF303039),
        displayColor: dark ? const Color(0xFFF1EFF7) : const Color(0xFF24212F),
      ),
      dividerColor: dark ? const Color(0xFF303036) : const Color(0xFFE5E2EC),
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xFF303036) : const Color(0xFFE5E2EC),
        space: 1,
        thickness: 1,
      ),
      iconTheme: IconThemeData(
        color: dark ? const Color(0xFF9B98A7) : const Color(0xFF77717E),
        size: 20,
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 450),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF25252C) : const Color(0xFFF0EDF5),
        isDense: true,
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: .65),
          fontSize: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static Color sidebar(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF18181D)
      : const Color(0xFFF3F1F8);
  static Color rail(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF131317)
      : const Color(0xFFEAE7F0);
}
