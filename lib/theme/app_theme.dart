import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// এক জায়গায় পুরো অ্যাপের রঙ, স্পেসিং আর শেপ।
///
/// আগে `static const _seed = Color(0xFF2D6A4F)` ১২টা ফাইলে আলাদা আলাদা করে
/// লেখা ছিল — একটা রঙ বদলাতে হলে ১২ জায়গায় খুঁজতে হতো। এখন শুধু এখানেই।
class AppColors {
  AppColors._();

  /// ব্র্যান্ড সবুজ (launcher icon / splash এর সাথে মিল)।
  static const primary = Color(0xFF2D6A4F);
  static const primaryDark = Color(0xFF1E4D38);
  static const primaryLight = Color(0xFF3F8A68);

  /// হেডার / avatar এর gradient।
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A8562), Color(0xFF215540)],
  );

  static const background = Color(0xFFF4F6F4);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFEFF2EF);

  static const ink = Color(0xFF16211C);
  static const inkMuted = Color(0xFF5C6A63);
  static const inkFaint = Color(0xFF8D9A93);

  static const success = Color(0xFF2E7D53);
  static const successBg = Color(0xFFE6F4EC);
  static const warning = Color(0xFFB26B00);
  static const warningBg = Color(0xFFFDF1DF);
  static const danger = Color(0xFFC0392B);
  static const dangerBg = Color(0xFFFBEAE8);
  static const info = Color(0xFF3A6EA5);

  static const border = Color(0x14000000); // ~8% কালো
  static const borderStrong = Color(0x24000000);

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF16211C).withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get liftedShadow => [
        BoxShadow(
          color: const Color(0xFF16211C).withValues(alpha: 0.08),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];
}

/// স্পেসিং আর কোণার গোলাকৃতির একটাই স্কেল, যাতে স্ক্রিনে স্ক্রিনে ছন্দ মেলে।
class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

class AppTheme {
  AppTheme._();

  /// পুরো UI বাংলায়, তাই বাংলা glyph আছে এমন ফন্ট দরকার।
  ///
  /// আগে Inter ব্যবহার হচ্ছিল — Inter এ বাংলা অক্ষর নেই, তাই প্রতিটা বাংলা লেখা
  /// সিস্টেমের fallback ফন্টে যেত। ওই fallback এর line-height Inter এর হিসাবের
  /// চেয়ে বড়, আর সেটাই ক্যালেন্ডারে সপ্তাহের নাম কেটে যাওয়ার আসল কারণ।
  static TextTheme _textTheme(TextTheme base) {
    final t = GoogleFonts.hindSiliguriTextTheme(base);
    return t.copyWith(
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink),
      bodyLarge: t.bodyLarge?.copyWith(height: 1.45, color: AppColors.ink),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.45, color: AppColors.ink),
      bodySmall: t.bodySmall?.copyWith(height: 1.4, color: AppColors.inkMuted),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
    );
    final textTheme = _textTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 19),
        iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.inkFaint, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
        prefixIconColor: AppColors.inkFaint,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.borderStrong),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 6,
        extendedTextStyle: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 14.5),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        side: const BorderSide(color: AppColors.border),
        labelStyle: GoogleFonts.hindSiliguri(fontSize: 13, color: AppColors.inkMuted),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.inkFaint,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w500, fontSize: 14),
        dividerColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 17),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.inkFaint,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.hindSiliguri(color: Colors.white, fontSize: 13.5),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkMuted,
        titleTextStyle: TextStyle(color: AppColors.ink, fontSize: 14.5, fontWeight: FontWeight.w600),
        subtitleTextStyle: TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
    );
  }
}
