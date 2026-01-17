import 'package:app/constants/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  List<String> themeColorList = ["Default", "Red", "Green", "Dark"];
  String? _colorName;

  String? get colorName => _colorName;

  void toggleTheme(String color) {
    if (color == "Dark") {
      _colorName = color;
      themeMode = ThemeMode.dark;
    } else {
      _colorName = color;
      themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

// void toggleTheme(bool isOn) {
//   themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
//   notifyListeners();
// }
}

class MyThemes {
  static final darkTheme = ThemeData(
    scaffoldBackgroundColor: Colors.grey.shade900,
    colorScheme: const ColorScheme.dark(),
    fontFamily: GoogleFonts.lato().fontFamily,
    primaryColor: Colors.black,
    brightness: Brightness.dark,
    // appBarTheme: AppBarTheme(color: Colors.black26)
    // iconTheme: IconThemeData(color: Colors.purple.shade200, opacity: 0.8),
  );

  static final lightTheme = ThemeData(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.themeColorBlue, // header background color
        onPrimary: AppColors.blackColor, // header text color
        onSurface: AppColors.blackColor, // body text color
      ),
      fontFamily: GoogleFonts.lato().fontFamily,
      primaryColor: AppColors.themeColorBlue,
      useMaterial3: true,
      brightness: Brightness.light,
      cardTheme: const CardThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        displayMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        displaySmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 10,
        ),
        headlineSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
        headlineMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 18,
        ),
        headlineLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 20,
        ),
        titleLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        bodyLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        bodyMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        bodySmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 10,
        ),
        labelSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        labelMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        labelLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
      ),
      tabBarTheme: const TabBarThemeData(labelColor: AppColors.whiteColor, indicatorColor: AppColors.whiteColor),
      unselectedWidgetColor: AppColors.greyColor,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.themeColorBlue),
      inputDecorationTheme: InputDecorationTheme(
        border: UnderlineInputBorder(
          borderSide: const BorderSide(
            width: AppSizes.one,
            color: AppColors.reachBlackColor,
          ),
          borderRadius: BorderRadius.circular(
            AppSizes.ten,
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      buttonTheme: const ButtonThemeData(
        hoverColor: AppColors.transparentColor,
        splashColor: AppColors.transparentColor,
        highlightColor: AppColors.transparentColor,
      ),
      bottomSheetTheme: const BottomSheetThemeData(surfaceTintColor: AppColors.whiteColor),
      appBarTheme: AppBarTheme(
        color: AppColors.themeColorBlue,
        surfaceTintColor: AppColors.themeColorBlue,
        elevation: 5,
        shadowColor: AppColors.blackColor.withOpacity(0.8),
        iconTheme: const IconThemeData(
          color: AppColors.whiteColor,
        ),
        titleTextStyle: const TextStyle(color: AppColors.whiteColor, fontSize: 20),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.blackColor,
      ),
      datePickerTheme: const DatePickerThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorBlue;
          }
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.primaryColor;
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorBlue;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorBlue;
          }
          return null;
        }),
      ));

  static final lightThemeRed = ThemeData(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.themeColorRed, // header background color
        onPrimary: AppColors.blackColor, // header text color
        onSurface: AppColors.blackColor, // body text color
      ),
      fontFamily: GoogleFonts.lato().fontFamily,
      primaryColor: AppColors.themeColorRed,
      brightness: Brightness.light,
      useMaterial3: true,
      cardTheme: const CardThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        displayMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        displaySmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 10,
        ),
        headlineSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
        headlineMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 18,
        ),
        headlineLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 20,
        ),
        titleLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        bodyLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        bodyMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        bodySmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 10,
        ),
        labelSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        labelMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        labelLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
      ),
      tabBarTheme: const TabBarThemeData(labelColor: AppColors.whiteColor, indicatorColor: AppColors.whiteColor),
      unselectedWidgetColor: AppColors.greyColor,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.themeColorRed),
      inputDecorationTheme: InputDecorationTheme(
        border: UnderlineInputBorder(
          borderSide: const BorderSide(
            width: AppSizes.one,
            color: AppColors.reachBlackColor,
          ),
          borderRadius: BorderRadius.circular(
            AppSizes.ten,
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      buttonTheme: const ButtonThemeData(
        hoverColor: AppColors.transparentColor,
        splashColor: AppColors.transparentColor,
        highlightColor: AppColors.transparentColor,
      ),
      bottomSheetTheme: const BottomSheetThemeData(surfaceTintColor: AppColors.whiteColor),
      appBarTheme: AppBarTheme(
        color: AppColors.themeColorRed,
        surfaceTintColor: AppColors.themeColorRed,
        elevation: 5,
        shadowColor: AppColors.blackColor.withOpacity(0.8),
        iconTheme: const IconThemeData(
          color: AppColors.whiteColor,
        ),
        titleTextStyle: const TextStyle(color: AppColors.whiteColor, fontSize: 20),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.blackColor,
      ),
      datePickerTheme: const DatePickerThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorRed;
          }
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorRed;
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorRed;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorRed;
          }
          return null;
        }),
      ));

  static final lightThemeGreen = ThemeData(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.themeColorGreen, // header background color
        onPrimary: AppColors.blackColor, // header text color
        onSurface: AppColors.blackColor, // body text color
      ),
      fontFamily: GoogleFonts.lato().fontFamily,
      primaryColor: AppColors.themeColorGreen,
      brightness: Brightness.light,
      useMaterial3: true,
      cardTheme: const CardThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        displayMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        displaySmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 10,
        ),
        headlineSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
        headlineMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 18,
        ),
        headlineLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 20,
        ),
        titleLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        bodyLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        bodyMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        bodySmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 10,
        ),
        labelSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        labelMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        labelLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
      ),
      tabBarTheme: const TabBarThemeData(labelColor: AppColors.whiteColor, indicatorColor: AppColors.whiteColor),
      unselectedWidgetColor: AppColors.greyColor,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.themeColorGreen),
      inputDecorationTheme: InputDecorationTheme(
        border: UnderlineInputBorder(
          borderSide: const BorderSide(
            width: AppSizes.one,
            color: AppColors.reachBlackColor,
          ),
          borderRadius: BorderRadius.circular(
            AppSizes.ten,
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      buttonTheme: const ButtonThemeData(
        hoverColor: AppColors.transparentColor,
        splashColor: AppColors.transparentColor,
        highlightColor: AppColors.transparentColor,
      ),
      bottomSheetTheme: const BottomSheetThemeData(surfaceTintColor: AppColors.whiteColor),
      appBarTheme: AppBarTheme(
        color: AppColors.themeColorGreen,
        surfaceTintColor: AppColors.themeColorGreen,
        elevation: 5,
        shadowColor: AppColors.blackColor.withOpacity(0.8),
        iconTheme: const IconThemeData(
          color: AppColors.whiteColor,
        ),
        titleTextStyle: const TextStyle(color: AppColors.whiteColor, fontSize: 20),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.blackColor,
      ),
      datePickerTheme: const DatePickerThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorGreen;
          }
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorGreen;
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorGreen;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorGreen;
          }
          return null;
        }),
      ));

  static final lightThemeMustard = ThemeData(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.themeColorMustard, // header background color
        onPrimary: AppColors.blackColor, // header text color
        onSurface: AppColors.blackColor, // body text color
      ),
      fontFamily: 'Lato',
      primaryColor: AppColors.themeColorMustard,
      useMaterial3: true,
      brightness: Brightness.light,
      cardTheme: const CardThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        displayMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        displaySmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 10,
        ),
        headlineSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
        headlineMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 18,
        ),
        headlineLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 20,
        ),
        titleLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        bodyLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        bodyMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        bodySmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 10,
        ),
        labelSmall: TextStyle(
          color: AppColors.blackColor,
          fontSize: 12,
        ),
        labelMedium: TextStyle(
          color: AppColors.blackColor,
          fontSize: 14,
        ),
        labelLarge: TextStyle(
          color: AppColors.blackColor,
          fontSize: 16,
        ),
      ),
      tabBarTheme: const TabBarThemeData(labelColor: AppColors.whiteColor, indicatorColor: AppColors.whiteColor),
      unselectedWidgetColor: AppColors.greyColor,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.themeColorMustard),
      inputDecorationTheme: InputDecorationTheme(
        border: UnderlineInputBorder(
          borderSide: const BorderSide(
            width: AppSizes.one,
            color: AppColors.reachBlackColor,
          ),
          borderRadius: BorderRadius.circular(
            AppSizes.ten,
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      buttonTheme: const ButtonThemeData(
        hoverColor: AppColors.transparentColor,
        splashColor: AppColors.transparentColor,
        highlightColor: AppColors.transparentColor,
      ),
      bottomSheetTheme: const BottomSheetThemeData(surfaceTintColor: AppColors.whiteColor),
      appBarTheme: AppBarTheme(
        color: AppColors.themeColorMustard,
        surfaceTintColor: AppColors.themeColorMustard,
        elevation: 5,
        shadowColor: AppColors.blackColor.withOpacity(0.8),
        iconTheme: const IconThemeData(
          color: AppColors.whiteColor,
        ),
        titleTextStyle: const TextStyle(color: AppColors.whiteColor, fontSize: 20),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.blackColor,
      ),
      datePickerTheme: const DatePickerThemeData(
        surfaceTintColor: AppColors.whiteColor,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorMustard;
          }
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorMustard;
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorMustard;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.themeColorMustard;
          }
          return null;
        }),
      ));
}
