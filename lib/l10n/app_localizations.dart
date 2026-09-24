import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
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
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('ru')];

  /// Product name, as the OS task switcher shows it
  ///
  /// In ru, this message translates to:
  /// **'SportVenue'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get navSearch;

  /// No description provided for @navGames.
  ///
  /// In ru, this message translates to:
  /// **'Игры'**
  String get navGames;

  /// No description provided for @navProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get navProfile;

  /// No description provided for @navCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать игру или бронь'**
  String get navCreate;

  /// No description provided for @createSheetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get createSheetTitle;

  /// No description provided for @createGameAction.
  ///
  /// In ru, this message translates to:
  /// **'Создать игру'**
  String get createGameAction;

  /// No description provided for @createGameActionSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Соберите участников и оплатите долю'**
  String get createGameActionSubtitle;

  /// No description provided for @bookVenueAction.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать площадку'**
  String get bookVenueAction;

  /// No description provided for @bookVenueActionSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите клуб и время'**
  String get bookVenueActionSubtitle;

  /// No description provided for @noVenuesAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступных площадок пока нет'**
  String get noVenuesAvailable;

  /// No description provided for @summaryDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get summaryDate;

  /// No description provided for @summaryTime.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get summaryTime;

  /// No description provided for @summaryVenue.
  ///
  /// In ru, this message translates to:
  /// **'Площадка'**
  String get summaryVenue;

  /// No description provided for @summaryPlayers.
  ///
  /// In ru, this message translates to:
  /// **'Игроки'**
  String get summaryPlayers;

  /// No description provided for @summaryTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get summaryTotal;

  /// No description provided for @summaryYourShare.
  ///
  /// In ru, this message translates to:
  /// **'Ваша часть'**
  String get summaryYourShare;

  /// No description provided for @back.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @durationHour.
  ///
  /// In ru, this message translates to:
  /// **'1 час'**
  String get durationHour;

  /// No description provided for @durationHourAndHalf.
  ///
  /// In ru, this message translates to:
  /// **'1.5 часа'**
  String get durationHourAndHalf;

  /// No description provided for @durationTwoHours.
  ///
  /// In ru, this message translates to:
  /// **'2 часа'**
  String get durationTwoHours;

  /// No description provided for @venueAddressDistance.
  ///
  /// In ru, this message translates to:
  /// **'{address} · {km} км'**
  String venueAddressDistance(String address, String km);

  /// No description provided for @pricePerHour.
  ///
  /// In ru, this message translates to:
  /// **'{price}/час'**
  String pricePerHour(String price);

  /// No description provided for @bookingRowSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'{time} · {status}'**
  String bookingRowSubtitle(String time, String status);

  /// No description provided for @sportStep.
  ///
  /// In ru, this message translates to:
  /// **'Шаг 1 из 2'**
  String get sportStep;

  /// No description provided for @sportQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Какой спорт?'**
  String get sportQuestion;

  /// No description provided for @sportHint.
  ///
  /// In ru, this message translates to:
  /// **'Можно выбрать несколько'**
  String get sportHint;

  /// No description provided for @sportsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Виды спорта пока недоступны'**
  String get sportsUnavailable;

  /// No description provided for @continueLabel.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get continueLabel;

  /// No description provided for @continueWithSports.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить · {count, plural, one{{count} вид} few{{count} вида} other{{count} видов}}'**
  String continueWithSports(int count);

  /// No description provided for @sportsSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить выбор'**
  String get sportsSaveFailed;

  /// No description provided for @greeting.
  ///
  /// In ru, this message translates to:
  /// **'Привет, {name}'**
  String greeting(String name);

  /// No description provided for @city.
  ///
  /// In ru, this message translates to:
  /// **'Москва'**
  String get city;

  /// No description provided for @notifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомлений пока нет'**
  String get noNotifications;

  /// No description provided for @searchPlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Найти площадку или игру'**
  String get searchPlaceholder;

  /// No description provided for @upcomingBooking.
  ///
  /// In ru, this message translates to:
  /// **'Предстоящая бронь'**
  String get upcomingBooking;

  /// No description provided for @seeAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get seeAll;

  /// No description provided for @recommendedVenues.
  ///
  /// In ru, this message translates to:
  /// **'Рекомендованные площадки'**
  String get recommendedVenues;

  /// No description provided for @openGames.
  ///
  /// In ru, this message translates to:
  /// **'Открытые игры'**
  String get openGames;

  /// No description provided for @noUpcomingBookings.
  ///
  /// In ru, this message translates to:
  /// **'У вас пока нет предстоящих броней'**
  String get noUpcomingBookings;

  /// No description provided for @profile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profile;

  /// No description provided for @accountSportVenue.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт SportVenue'**
  String get accountSportVenue;

  /// No description provided for @demoAccountSportVenue.
  ///
  /// In ru, this message translates to:
  /// **'Демо-аккаунт SportVenue'**
  String get demoAccountSportVenue;

  /// No description provided for @userSportVenue.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь SportVenue'**
  String get userSportVenue;

  /// No description provided for @noPhone.
  ///
  /// In ru, this message translates to:
  /// **'Номер не указан'**
  String get noPhone;

  /// No description provided for @editProfile.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать профиль'**
  String get editProfile;

  /// No description provided for @editProfileLater.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование профиля подключится позже'**
  String get editProfileLater;

  /// No description provided for @sportPreferences.
  ///
  /// In ru, this message translates to:
  /// **'Спортивные предпочтения'**
  String get sportPreferences;

  /// No description provided for @change.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get change;

  /// No description provided for @history.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get history;

  /// No description provided for @historySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'{bookings} броней · {games} игр'**
  String historySubtitle(int bookings, int games);

  /// No description provided for @logout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта'**
  String get logout;

  /// No description provided for @logoutQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта?'**
  String get logoutQuestion;

  /// No description provided for @logoutMessage.
  ///
  /// In ru, this message translates to:
  /// **'Брони и игры останутся на месте — чтобы вернуться к ним, придётся снова подтвердить номер телефона.'**
  String get logoutMessage;

  /// No description provided for @logoutConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logoutConfirm;

  /// No description provided for @logoutCancel.
  ///
  /// In ru, this message translates to:
  /// **'Остаться'**
  String get logoutCancel;

  /// No description provided for @statBookings.
  ///
  /// In ru, this message translates to:
  /// **'Броней'**
  String get statBookings;

  /// No description provided for @statMyGames.
  ///
  /// In ru, this message translates to:
  /// **'Моих игр'**
  String get statMyGames;

  /// No description provided for @statSports.
  ///
  /// In ru, this message translates to:
  /// **'Видов спорта'**
  String get statSports;

  /// No description provided for @historyEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся ваши брони и игры'**
  String get historyEmpty;

  /// No description provided for @bookingsSection.
  ///
  /// In ru, this message translates to:
  /// **'Брони'**
  String get bookingsSection;

  /// No description provided for @gamesSection.
  ///
  /// In ru, this message translates to:
  /// **'Игры'**
  String get gamesSection;

  /// No description provided for @historySummary.
  ///
  /// In ru, this message translates to:
  /// **'{bookings, plural, one{{bookings} бронь} few{{bookings} брони} other{{bookings} броней}} · {games, plural, one{{games} игра} few{{games} игры} other{{games} игр}}'**
  String historySummary(int bookings, int games);

  /// No description provided for @venuePickerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Площадка'**
  String get venuePickerTitle;

  /// No description provided for @venuePickerSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Название или адрес'**
  String get venuePickerSearchHint;

  /// No description provided for @clear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get clear;

  /// No description provided for @nothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не нашлось'**
  String get nothingFound;

  /// No description provided for @nothingFoundFor.
  ///
  /// In ru, this message translates to:
  /// **'По запросу «{query}» нет ни клуба, ни адреса.'**
  String nothingFoundFor(String query);

  /// No description provided for @reset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get reset;

  /// No description provided for @search.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get search;

  /// No description provided for @searchSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Москва · openfreemap'**
  String get searchSubtitle;

  /// No description provided for @centreOnMoscow.
  ///
  /// In ru, this message translates to:
  /// **'Центр Москвы'**
  String get centreOnMoscow;

  /// No description provided for @allFilter.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get allFilter;

  /// No description provided for @mapLoading.
  ///
  /// In ru, this message translates to:
  /// **'Карта загружается'**
  String get mapLoading;

  /// No description provided for @searchFieldHint.
  ///
  /// In ru, this message translates to:
  /// **'Клуб, площадка или район'**
  String get searchFieldHint;

  /// No description provided for @clearSearch.
  ///
  /// In ru, this message translates to:
  /// **'Очистить поиск'**
  String get clearSearch;

  /// No description provided for @clubsNearby.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} клуб} few{{count} клуба} other{{count} клубов}} рядом'**
  String clubsNearby(int count);

  /// No description provided for @noVenuesForSport.
  ///
  /// In ru, this message translates to:
  /// **'Площадок этого вида нет'**
  String get noVenuesForSport;

  /// No description provided for @noVenuesForSportHint.
  ///
  /// In ru, this message translates to:
  /// **'В Москве пока нет клубов с этим покрытием.'**
  String get noVenuesForSportHint;

  /// No description provided for @resetSearch.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить поиск'**
  String get resetSearch;

  /// No description provided for @skipSplash.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить заставку'**
  String get skipSplash;

  /// No description provided for @signInTitle.
  ///
  /// In ru, this message translates to:
  /// **'Войти или\nзарегистрироваться'**
  String get signInTitle;

  /// No description provided for @consent.
  ///
  /// In ru, this message translates to:
  /// **'Согласен с обработкой персональных данных и условиями сервиса'**
  String get consent;

  /// No description provided for @or.
  ///
  /// In ru, this message translates to:
  /// **'или'**
  String get or;

  /// No description provided for @signInWithGoogle.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithVk.
  ///
  /// In ru, this message translates to:
  /// **'Войти через VK'**
  String get signInWithVk;

  /// No description provided for @signInWithApple.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Apple'**
  String get signInWithApple;

  /// No description provided for @termsFooter.
  ///
  /// In ru, this message translates to:
  /// **'Продолжая, вы соглашаетесь с условиями использования и политикой конфиденциальности'**
  String get termsFooter;

  /// No description provided for @socialLater.
  ///
  /// In ru, this message translates to:
  /// **'Социальный вход подключится позже'**
  String get socialLater;

  /// No description provided for @wrongCode.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код, попробуйте ещё раз'**
  String get wrongCode;

  /// No description provided for @enterCode.
  ///
  /// In ru, this message translates to:
  /// **'Введите код'**
  String get enterCode;

  /// No description provided for @codeHint.
  ///
  /// In ru, this message translates to:
  /// **'Мы звоним на {phone}. Введите последние 4 цифры входящего номера'**
  String codeHint(String phone);

  /// No description provided for @resend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить повторно'**
  String get resend;

  /// No description provided for @resendIn.
  ///
  /// In ru, this message translates to:
  /// **'Отправить повторно через {seconds} с'**
  String resendIn(int seconds);

  /// No description provided for @doNotAnswer.
  ///
  /// In ru, this message translates to:
  /// **'Не отвечайте на звонок — нужны только последние 4 цифры номера'**
  String get doNotAnswer;

  /// No description provided for @callRequestedAgain.
  ///
  /// In ru, this message translates to:
  /// **'Звонок запрошен повторно'**
  String get callRequestedAgain;

  /// No description provided for @sportKind.
  ///
  /// In ru, this message translates to:
  /// **'Вид спорта'**
  String get sportKind;

  /// No description provided for @venueStep.
  ///
  /// In ru, this message translates to:
  /// **'Площадка'**
  String get venueStep;

  /// No description provided for @noVenuesForChosenSport.
  ///
  /// In ru, this message translates to:
  /// **'Для выбранного спорта площадок пока нет'**
  String get noVenuesForChosenSport;

  /// No description provided for @moreVenues.
  ///
  /// In ru, this message translates to:
  /// **'ещё {count}'**
  String moreVenues(int count);

  /// No description provided for @dateStep.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get dateStep;

  /// No description provided for @startStep.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get startStep;

  /// No description provided for @pickVenueFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала выберите площадку'**
  String get pickVenueFirst;

  /// No description provided for @durationStep.
  ///
  /// In ru, this message translates to:
  /// **'Продолжительность'**
  String get durationStep;

  /// No description provided for @placesStep.
  ///
  /// In ru, this message translates to:
  /// **'Количество мест'**
  String get placesStep;

  /// No description provided for @removePlace.
  ///
  /// In ru, this message translates to:
  /// **'Убрать место'**
  String get removePlace;

  /// No description provided for @addPlace.
  ///
  /// In ru, this message translates to:
  /// **'Добавить место'**
  String get addPlace;

  /// No description provided for @placesCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} место} few{{count} места} other{{count} мест}}'**
  String placesCount(int count);

  /// No description provided for @whoCanJoin.
  ///
  /// In ru, this message translates to:
  /// **'Кто может вступить'**
  String get whoCanJoin;

  /// No description provided for @approveManually.
  ///
  /// In ru, this message translates to:
  /// **'Одобрять вручную'**
  String get approveManually;

  /// No description provided for @approveManuallyHint.
  ///
  /// In ru, this message translates to:
  /// **'Вы будете подтверждать каждого игрока'**
  String get approveManuallyHint;

  /// No description provided for @participantFilter.
  ///
  /// In ru, this message translates to:
  /// **'Фильтр участников'**
  String get participantFilter;

  /// No description provided for @genderAny.
  ///
  /// In ru, this message translates to:
  /// **'Любой'**
  String get genderAny;

  /// No description provided for @genderMen.
  ///
  /// In ru, this message translates to:
  /// **'Мужчины'**
  String get genderMen;

  /// No description provided for @genderWomen.
  ///
  /// In ru, this message translates to:
  /// **'Женщины'**
  String get genderWomen;

  /// No description provided for @pricePerPerson.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость с человека'**
  String get pricePerPerson;

  /// No description provided for @emptyValue.
  ///
  /// In ru, this message translates to:
  /// **'—'**
  String get emptyValue;

  /// No description provided for @createGame.
  ///
  /// In ru, this message translates to:
  /// **'Создать игру'**
  String get createGame;

  /// No description provided for @pickSportAndVenue.
  ///
  /// In ru, this message translates to:
  /// **'Выберите вид спорта и площадку'**
  String get pickSportAndVenue;

  /// No description provided for @gameCreated.
  ///
  /// In ru, this message translates to:
  /// **'Игра создана'**
  String get gameCreated;

  /// No description provided for @booking.
  ///
  /// In ru, this message translates to:
  /// **'Бронирование'**
  String get booking;

  /// No description provided for @timeStep.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get timeStep;

  /// No description provided for @playersStep.
  ///
  /// In ru, this message translates to:
  /// **'Игроки'**
  String get playersStep;

  /// No description provided for @paySharePrice.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить свою часть · {price}'**
  String paySharePrice(String price);

  /// No description provided for @payFullPrice.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать целиком · {price}'**
  String payFullPrice(String price);

  /// No description provided for @confirmation.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение'**
  String get confirmation;

  /// No description provided for @payConsent.
  ///
  /// In ru, this message translates to:
  /// **'Нажимая «Перейти к оплате», вы соглашаетесь с условиями сервиса и политикой конфиденциальности'**
  String get payConsent;

  /// No description provided for @goToPayment.
  ///
  /// In ru, this message translates to:
  /// **'Перейти к оплате · {price}'**
  String goToPayment(String price);

  /// No description provided for @goBack.
  ///
  /// In ru, this message translates to:
  /// **'Вернуться назад'**
  String get goBack;

  /// No description provided for @paymentDone.
  ///
  /// In ru, this message translates to:
  /// **'Оплата прошла, бронь создана'**
  String get paymentDone;

  /// No description provided for @bookingDetails.
  ///
  /// In ru, this message translates to:
  /// **'Детали брони'**
  String get bookingDetails;

  /// No description provided for @onlyOrganizerCancels.
  ///
  /// In ru, this message translates to:
  /// **'Отменить бронь может только организатор'**
  String get onlyOrganizerCancels;

  /// No description provided for @cancelBooking.
  ///
  /// In ru, this message translates to:
  /// **'Отменить бронь'**
  String get cancelBooking;

  /// No description provided for @cancelBookingQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Отменить бронь?'**
  String get cancelBookingQuestion;

  /// No description provided for @cancelBookingMessage.
  ///
  /// In ru, this message translates to:
  /// **'{venue}, {date}, {time}. Вернуть её тем же нажатием не получится.'**
  String cancelBookingMessage(String venue, String date, String time);

  /// No description provided for @keepBooking.
  ///
  /// In ru, this message translates to:
  /// **'Оставить'**
  String get keepBooking;

  /// No description provided for @bookingCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Бронь отменена'**
  String get bookingCancelled;

  /// No description provided for @bookingDetailsCard.
  ///
  /// In ru, this message translates to:
  /// **'Детали бронирования'**
  String get bookingDetailsCard;

  /// No description provided for @statusLine.
  ///
  /// In ru, this message translates to:
  /// **'Статус · {status}'**
  String statusLine(String status);

  /// No description provided for @cancellationTerms.
  ///
  /// In ru, this message translates to:
  /// **'Условия отмены'**
  String get cancellationTerms;

  /// No description provided for @cancellationTermAuto.
  ///
  /// In ru, this message translates to:
  /// **'Если игра не набирает участников за 2 часа до начала, бронь отменяется автоматически'**
  String get cancellationTermAuto;

  /// No description provided for @cancellationTermRefund.
  ///
  /// In ru, this message translates to:
  /// **'Если вы отменяете сами, средства возвращаются на счёт в течение 3 дней'**
  String get cancellationTermRefund;

  /// No description provided for @removePlayer.
  ///
  /// In ru, this message translates to:
  /// **'Убрать игрока'**
  String get removePlayer;

  /// No description provided for @addPlayer.
  ///
  /// In ru, this message translates to:
  /// **'Добавить игрока'**
  String get addPlayer;

  /// No description provided for @playersCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} игрок} few{{count} игрока} other{{count} игроков}}'**
  String playersCount(int count);

  /// No description provided for @unknownSport.
  ///
  /// In ru, this message translates to:
  /// **'Спорт'**
  String get unknownSport;

  /// No description provided for @games.
  ///
  /// In ru, this message translates to:
  /// **'Игры'**
  String get games;

  /// No description provided for @gamesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'pickup-матчи рядом'**
  String get gamesSubtitle;

  /// No description provided for @filters.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get filters;

  /// No description provided for @filtersLater.
  ///
  /// In ru, this message translates to:
  /// **'Расширенные фильтры появятся позже'**
  String get filtersLater;

  /// No description provided for @nothingMatchesFilters.
  ///
  /// In ru, this message translates to:
  /// **'Под фильтры ничего не подошло'**
  String get nothingMatchesFilters;

  /// No description provided for @nothingMatchesFiltersHint.
  ///
  /// In ru, this message translates to:
  /// **'Игры есть, но не в этом виде спорта или не в это время.'**
  String get nothingMatchesFiltersHint;

  /// No description provided for @showAllGames.
  ///
  /// In ru, this message translates to:
  /// **'Показать все игры'**
  String get showAllGames;

  /// No description provided for @noOpenGames.
  ///
  /// In ru, this message translates to:
  /// **'Открытых игр пока нет'**
  String get noOpenGames;

  /// No description provided for @noOpenGamesHint.
  ///
  /// In ru, this message translates to:
  /// **'Создайте свою — участники смогут вступить и оплатить долю.'**
  String get noOpenGamesHint;

  /// No description provided for @gameWhen.
  ///
  /// In ru, this message translates to:
  /// **'{date} · {time}'**
  String gameWhen(String date, String time);

  /// No description provided for @freePlaces.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} место} few{{count} места} other{{count} мест}} свободно'**
  String freePlaces(int count);

  /// No description provided for @join.
  ///
  /// In ru, this message translates to:
  /// **'Вступить'**
  String get join;

  /// No description provided for @joined.
  ///
  /// In ru, this message translates to:
  /// **'Вы присоединились к игре'**
  String get joined;

  /// No description provided for @alreadyJoined.
  ///
  /// In ru, this message translates to:
  /// **'Вы уже в этой игре'**
  String get alreadyJoined;

  /// No description provided for @price.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость'**
  String get price;

  /// No description provided for @organizer.
  ///
  /// In ru, this message translates to:
  /// **'Организатор'**
  String get organizer;

  /// No description provided for @chatLater.
  ///
  /// In ru, this message translates to:
  /// **'Чат подключится позже'**
  String get chatLater;

  /// No description provided for @write.
  ///
  /// In ru, this message translates to:
  /// **'Написать'**
  String get write;

  /// No description provided for @players.
  ///
  /// In ru, this message translates to:
  /// **'игроки'**
  String get players;

  /// No description provided for @leaveGame.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из игры'**
  String get leaveGame;

  /// No description provided for @requestAfterApproval.
  ///
  /// In ru, this message translates to:
  /// **'Заявка и оплата после одобрения'**
  String get requestAfterApproval;

  /// No description provided for @joinGame.
  ///
  /// In ru, this message translates to:
  /// **'Присоединиться к игре'**
  String get joinGame;

  /// No description provided for @leaveGameQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из игры?'**
  String get leaveGameQuestion;

  /// No description provided for @leaveGameMessage.
  ///
  /// In ru, this message translates to:
  /// **'{venue}, {date} · {time}. Место вернётся в игру, и его сможет занять кто-то другой.'**
  String leaveGameMessage(String venue, String date, String time);

  /// No description provided for @leaveConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get leaveConfirm;

  /// No description provided for @stay.
  ///
  /// In ru, this message translates to:
  /// **'Остаться'**
  String get stay;

  /// No description provided for @leftGame.
  ///
  /// In ru, this message translates to:
  /// **'Вы вышли из игры'**
  String get leftGame;

  /// No description provided for @wasNotInGame.
  ///
  /// In ru, this message translates to:
  /// **'Вас не было в этой игре'**
  String get wasNotInGame;

  /// No description provided for @evening.
  ///
  /// In ru, this message translates to:
  /// **'Вечер'**
  String get evening;

  /// No description provided for @anyDay.
  ///
  /// In ru, this message translates to:
  /// **'Любой день'**
  String get anyDay;

  /// No description provided for @rating.
  ///
  /// In ru, this message translates to:
  /// **'Рейтинг {value}'**
  String rating(String value);

  /// No description provided for @freeSlot.
  ///
  /// In ru, this message translates to:
  /// **'свободно'**
  String get freeSlot;

  /// No description provided for @openGame.
  ///
  /// In ru, this message translates to:
  /// **'Открытая игра'**
  String get openGame;

  /// No description provided for @approvalGame.
  ///
  /// In ru, this message translates to:
  /// **'Игра по одобрению'**
  String get approvalGame;

  /// No description provided for @closedGame.
  ///
  /// In ru, this message translates to:
  /// **'Закрытая игра'**
  String get closedGame;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @noFreeSlots.
  ///
  /// In ru, this message translates to:
  /// **'На эту дату свободных слотов нет'**
  String get noFreeSlots;

  /// No description provided for @errorNetwork.
  ///
  /// In ru, this message translates to:
  /// **'сервер недоступен — проверьте, что он запущен'**
  String get errorNetwork;

  /// No description provided for @errorInvalidResponse.
  ///
  /// In ru, this message translates to:
  /// **'сервер вернул неожиданный ответ'**
  String get errorInvalidResponse;

  /// No description provided for @errorSessionExpired.
  ///
  /// In ru, this message translates to:
  /// **'сессия истекла — войдите снова'**
  String get errorSessionExpired;

  /// No description provided for @errorSlotTaken.
  ///
  /// In ru, this message translates to:
  /// **'этот слот уже занят, выберите другое время'**
  String get errorSlotTaken;

  /// No description provided for @errorGameFull.
  ///
  /// In ru, this message translates to:
  /// **'в игре больше нет свободных мест'**
  String get errorGameFull;

  /// No description provided for @errorCancelNotOrganizer.
  ///
  /// In ru, this message translates to:
  /// **'отменить бронь может только организатор'**
  String get errorCancelNotOrganizer;

  /// No description provided for @errorBadPhone.
  ///
  /// In ru, this message translates to:
  /// **'проверьте номер телефона'**
  String get errorBadPhone;

  /// No description provided for @errorInvalidCode.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код, попробуйте ещё раз'**
  String get errorInvalidCode;

  /// No description provided for @errorChallengeExpired.
  ///
  /// In ru, this message translates to:
  /// **'время проверки истекло — запросите новый звонок'**
  String get errorChallengeExpired;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In ru, this message translates to:
  /// **'слишком много попыток — запросите новый звонок'**
  String get errorTooManyAttempts;

  /// No description provided for @errorTimeout.
  ///
  /// In ru, this message translates to:
  /// **'сервер не ответил вовремя'**
  String get errorTimeout;

  /// No description provided for @errorUnknown.
  ///
  /// In ru, this message translates to:
  /// **'не удалось выполнить запрос'**
  String get errorUnknown;

  /// No description provided for @bookingStatusCollecting.
  ///
  /// In ru, this message translates to:
  /// **'ожидает участников'**
  String get bookingStatusCollecting;

  /// No description provided for @bookingStatusConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'подтверждена'**
  String get bookingStatusConfirmed;

  /// No description provided for @bookingStatusCancelled.
  ///
  /// In ru, this message translates to:
  /// **'отменена'**
  String get bookingStatusCancelled;

  /// No description provided for @bookingStatusExpired.
  ///
  /// In ru, this message translates to:
  /// **'истекла'**
  String get bookingStatusExpired;

  /// No description provided for @bookingStatusCollectingPaid.
  ///
  /// In ru, this message translates to:
  /// **'оплатили {paid} из {total}'**
  String bookingStatusCollectingPaid(int paid, int total);

  /// No description provided for @sharesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата долей'**
  String get sharesTitle;

  /// No description provided for @sharePaid.
  ///
  /// In ru, this message translates to:
  /// **'оплачено'**
  String get sharePaid;

  /// No description provided for @shareUnpaid.
  ///
  /// In ru, this message translates to:
  /// **'ждём оплату'**
  String get shareUnpaid;

  /// No description provided for @sharesLeft.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{осталась {count} доля} few{осталось {count} доли} other{осталось {count} долей}}'**
  String sharesLeft(int count);

  /// No description provided for @sharesAllPaid.
  ///
  /// In ru, this message translates to:
  /// **'все доли оплачены'**
  String get sharesAllPaid;

  /// No description provided for @player.
  ///
  /// In ru, this message translates to:
  /// **'Игрок'**
  String get player;

  /// No description provided for @playerOrganizer.
  ///
  /// In ru, this message translates to:
  /// **'Организатор'**
  String get playerOrganizer;

  /// No description provided for @playerGames.
  ///
  /// In ru, this message translates to:
  /// **'Игры этого участника'**
  String get playerGames;

  /// No description provided for @playerNoGames.
  ///
  /// In ru, this message translates to:
  /// **'Других игр этого участника здесь нет'**
  String get playerNoGames;

  /// No description provided for @playerPending.
  ///
  /// In ru, this message translates to:
  /// **'ждёт одобрения'**
  String get playerPending;

  /// No description provided for @vividNearby.
  ///
  /// In ru, this message translates to:
  /// **'Рядом'**
  String get vividNearby;

  /// No description provided for @vividTonight.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня вечером'**
  String get vividTonight;

  /// No description provided for @vividNewVenues.
  ///
  /// In ru, this message translates to:
  /// **'Новые площадки'**
  String get vividNewVenues;

  /// No description provided for @vividFreeNow.
  ///
  /// In ru, this message translates to:
  /// **'Свободно сейчас'**
  String get vividFreeNow;

  /// No description provided for @vividFrom.
  ///
  /// In ru, this message translates to:
  /// **'от {price}'**
  String vividFrom(String price);

  /// No description provided for @vividBook.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать'**
  String get vividBook;

  /// No description provided for @vividPickedForYou.
  ///
  /// In ru, this message translates to:
  /// **'Подобрали для вас'**
  String get vividPickedForYou;

  /// Заголовок ряда категорий на ярком главном экране
  ///
  /// In ru, this message translates to:
  /// **'Виды спорта'**
  String get vividSports;

  /// Метка на баннере яркого главного экрана
  ///
  /// In ru, this message translates to:
  /// **'Ближайшая игра'**
  String get vividNextGame;

  /// Заголовок ряда площадок на ярком главном экране
  ///
  /// In ru, this message translates to:
  /// **'Свободно сегодня'**
  String get vividFreeToday;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return LRu();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
