import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('hi'),
    Locale('ur'),
  ];

  /// No description provided for @helloWorld.
  ///
  /// In en, this message translates to:
  /// **'Hello User.'**
  String get helloWorld;

  /// No description provided for @changeLanguageFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Change Language From Device to See Translation.'**
  String get changeLanguageFromDevice;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @onboarding1title.
  ///
  /// In en, this message translates to:
  /// **'Fractional shares'**
  String get onboarding1title;

  /// No description provided for @onboarding1description.
  ///
  /// In en, this message translates to:
  /// **'Instead of having to buy an entire share, invest any amount you want.'**
  String get onboarding1description;

  /// No description provided for @onboarding2title.
  ///
  /// In en, this message translates to:
  /// **'Learn as you go'**
  String get onboarding2title;

  /// No description provided for @onboarding2description.
  ///
  /// In en, this message translates to:
  /// **'Download the Stockpile app and master the market with our mini-lesson.'**
  String get onboarding2description;

  /// No description provided for @onboarding3title.
  ///
  /// In en, this message translates to:
  /// **'Kids and teens'**
  String get onboarding3title;

  /// No description provided for @onboarding3description.
  ///
  /// In en, this message translates to:
  /// **'Kids and teens can track their stocks 24/7 and place trades that you approve.'**
  String get onboarding3description;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter an email'**
  String get enterEmail;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters long'**
  String get passwordMinLength;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @dontHaveAnAccountYet.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account yet?'**
  String get dontHaveAnAccountYet;

  /// No description provided for @registerNow.
  ///
  /// In en, this message translates to:
  /// **'Register Now'**
  String get registerNow;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @brandedItemsForSale.
  ///
  /// In en, this message translates to:
  /// **'Branded Items For Sale'**
  String get brandedItemsForSale;

  /// No description provided for @allItemsForSale.
  ///
  /// In en, this message translates to:
  /// **'All Items For Sale'**
  String get allItemsForSale;

  /// No description provided for @menuItems.
  ///
  /// In en, this message translates to:
  /// **'Menu Items'**
  String get menuItems;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @enterFirstName.
  ///
  /// In en, this message translates to:
  /// **'Enter first Name'**
  String get enterFirstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @enterLastName.
  ///
  /// In en, this message translates to:
  /// **'Enter last Name'**
  String get enterLastName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter Phone'**
  String get enterPhone;

  /// No description provided for @enter10DigitPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter 10 digit phone number'**
  String get enter10DigitPhoneNumber;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @enterGender.
  ///
  /// In en, this message translates to:
  /// **'Enter Gender'**
  String get enterGender;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @enterAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter Address'**
  String get enterAddress;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter Name'**
  String get enterName;

  /// No description provided for @addressInformation.
  ///
  /// In en, this message translates to:
  /// **'Address Information'**
  String get addressInformation;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @enterCity.
  ///
  /// In en, this message translates to:
  /// **'Enter City'**
  String get enterCity;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @enterState.
  ///
  /// In en, this message translates to:
  /// **'Enter State'**
  String get enterState;

  /// No description provided for @postCode.
  ///
  /// In en, this message translates to:
  /// **'Post Code'**
  String get postCode;

  /// No description provided for @enterPostCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Post Code'**
  String get enterPostCode;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @meetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get meetings;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @eventAddOrEdit.
  ///
  /// In en, this message translates to:
  /// **'Add/Edit Event'**
  String get eventAddOrEdit;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @enterATitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a Title'**
  String get enterATitle;

  /// No description provided for @enterAtleast4Characters.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 4 characters'**
  String get enterAtleast4Characters;

  /// No description provided for @fromDate.
  ///
  /// In en, this message translates to:
  /// **'From Date'**
  String get fromDate;

  /// No description provided for @toDate.
  ///
  /// In en, this message translates to:
  /// **'To Date'**
  String get toDate;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @enterADescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a Description'**
  String get enterADescription;

  /// No description provided for @enterAtleast10Characters.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 10 characters'**
  String get enterAtleast10Characters;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get save;

  /// No description provided for @formControls.
  ///
  /// In en, this message translates to:
  /// **'Form Controls'**
  String get formControls;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date Of Birth'**
  String get dateOfBirth;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @fieldIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Field is required'**
  String get fieldIsRequired;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @knownLanguages.
  ///
  /// In en, this message translates to:
  /// **'Known Languages'**
  String get knownLanguages;

  /// No description provided for @availableFrom.
  ///
  /// In en, this message translates to:
  /// **'Available From'**
  String get availableFrom;

  /// No description provided for @selectAvailableFromDate.
  ///
  /// In en, this message translates to:
  /// **'Select Available From Date'**
  String get selectAvailableFromDate;

  /// No description provided for @availableTill.
  ///
  /// In en, this message translates to:
  /// **'Available Till'**
  String get availableTill;

  /// No description provided for @selectAvailableTillDate.
  ///
  /// In en, this message translates to:
  /// **'Select Available Till Date'**
  String get selectAvailableTillDate;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @enteraDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a Description'**
  String get enteraDescription;

  /// No description provided for @additionalInformation.
  ///
  /// In en, this message translates to:
  /// **'Additional Information'**
  String get additionalInformation;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @addEventinCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add Event in Calendar'**
  String get addEventinCalendar;

  /// No description provided for @seeMore.
  ///
  /// In en, this message translates to:
  /// **'See More'**
  String get seeMore;

  /// No description provided for @charts.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get charts;

  /// No description provided for @googleMap.
  ///
  /// In en, this message translates to:
  /// **'Google Map'**
  String get googleMap;

  /// No description provided for @qRCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qRCode;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get years;

  /// No description provided for @barChart.
  ///
  /// In en, this message translates to:
  /// **'Bar Chart'**
  String get barChart;

  /// No description provided for @lineChart.
  ///
  /// In en, this message translates to:
  /// **'Line Chart'**
  String get lineChart;

  /// No description provided for @pieChart.
  ///
  /// In en, this message translates to:
  /// **'Pie Chart'**
  String get pieChart;

  /// No description provided for @doughnutChart.
  ///
  /// In en, this message translates to:
  /// **'Doughnut Chart'**
  String get doughnutChart;

  /// No description provided for @pyramidChart.
  ///
  /// In en, this message translates to:
  /// **'Pyramid Chart'**
  String get pyramidChart;

  /// No description provided for @changeTheme.
  ///
  /// In en, this message translates to:
  /// **'Change Theme'**
  String get changeTheme;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @customCharts.
  ///
  /// In en, this message translates to:
  /// **'Custom Charts'**
  String get customCharts;

  /// No description provided for @customChips.
  ///
  /// In en, this message translates to:
  /// **'Custom Chips'**
  String get customChips;

  /// No description provided for @otpVerification.
  ///
  /// In en, this message translates to:
  /// **'OTP Verification'**
  String get otpVerification;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'hi',
    'ur',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hi':
      return AppLocalizationsHi();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
