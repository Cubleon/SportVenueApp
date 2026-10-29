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

  /// No description provided for @venueAddressDistance.
  ///
  /// In ru, this message translates to:
  /// **'{address} · {km} км'**
  String venueAddressDistance(String address, String km);

  /// No description provided for @openMap.
  ///
  /// In ru, this message translates to:
  /// **'Открыть карту'**
  String get openMap;

  /// No description provided for @gameNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Игра не найдена'**
  String get gameNotFound;

  /// No description provided for @venueNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Клуб не найден'**
  String get venueNotFound;

  /// No description provided for @bookingNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Бронь не найдена'**
  String get bookingNotFound;

  /// No description provided for @notFoundHint.
  ///
  /// In ru, this message translates to:
  /// **'Возможно, ссылка устарела или запись удалили.'**
  String get notFoundHint;

  /// No description provided for @toHome.
  ///
  /// In ru, this message translates to:
  /// **'На главную'**
  String get toHome;

  /// No description provided for @shareGame.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться игрой'**
  String get shareGame;

  /// No description provided for @shareVenue.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться клубом'**
  String get shareVenue;

  /// No description provided for @venueSports.
  ///
  /// In ru, this message translates to:
  /// **'Виды спорта'**
  String get venueSports;

  /// No description provided for @venueAmenities.
  ///
  /// In ru, this message translates to:
  /// **'Что есть'**
  String get venueAmenities;

  /// No description provided for @venueCapacity.
  ///
  /// In ru, this message translates to:
  /// **'Сколько играет'**
  String get venueCapacity;

  /// No description provided for @capacityRange.
  ///
  /// In ru, this message translates to:
  /// **'от {min} до {max}'**
  String capacityRange(int min, int max);

  /// No description provided for @reviewsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} отзыв} few{{count} отзыва} other{{count} отзывов}}'**
  String reviewsCount(int count);

  /// No description provided for @ratingOnly.
  ///
  /// In ru, this message translates to:
  /// **'Рейтинг {rating}'**
  String ratingOnly(String rating);

  /// No description provided for @loading.
  ///
  /// In ru, this message translates to:
  /// **'считаем…'**
  String get loading;

  /// No description provided for @freeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Свободно'**
  String get freeLabel;

  /// No description provided for @freeHoursUnknown.
  ///
  /// In ru, this message translates to:
  /// **'нет данных'**
  String get freeHoursUnknown;

  /// No description provided for @freeHoursFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось узнать свободные часы'**
  String get freeHoursFailed;

  /// No description provided for @durationShorter.
  ///
  /// In ru, this message translates to:
  /// **'Короче'**
  String get durationShorter;

  /// No description provided for @durationLonger.
  ///
  /// In ru, this message translates to:
  /// **'Дольше'**
  String get durationLonger;

  /// No description provided for @hoursAndHalf.
  ///
  /// In ru, this message translates to:
  /// **'{hours},5 часа'**
  String hoursAndHalf(int hours);

  /// No description provided for @minutesCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} минута} few{{count} минуты} other{{count} минут}}'**
  String minutesCount(int count);

  /// No description provided for @filtersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get filtersTitle;

  /// No description provided for @filterPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена за час'**
  String get filterPrice;

  /// No description provided for @filterAnyPrice.
  ///
  /// In ru, this message translates to:
  /// **'любая'**
  String get filterAnyPrice;

  /// No description provided for @filterDistance.
  ///
  /// In ru, this message translates to:
  /// **'Расстояние'**
  String get filterDistance;

  /// No description provided for @filterAnyDistance.
  ///
  /// In ru, this message translates to:
  /// **'любое'**
  String get filterAnyDistance;

  /// No description provided for @filterAmenities.
  ///
  /// In ru, this message translates to:
  /// **'Что должно быть'**
  String get filterAmenities;

  /// No description provided for @upTo.
  ///
  /// In ru, this message translates to:
  /// **'до {value}'**
  String upTo(String value);

  /// No description provided for @distanceKm.
  ///
  /// In ru, this message translates to:
  /// **'{km} км'**
  String distanceKm(String km);

  /// No description provided for @filterShow.
  ///
  /// In ru, this message translates to:
  /// **'Показать {count, plural, one{{count} клуб} few{{count} клуба} other{{count} клубов}}'**
  String filterShow(int count);

  /// No description provided for @filterNoMatches.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не подходит'**
  String get filterNoMatches;

  /// No description provided for @filtersOpen.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get filtersOpen;

  /// No description provided for @hoursCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} час} few{{count} часа} other{{count} часов}}'**
  String hoursCount(int count);

  /// No description provided for @invitePlayers.
  ///
  /// In ru, this message translates to:
  /// **'Позвать игроков — скопировать ссылку'**
  String get invitePlayers;

  /// No description provided for @linkCopied.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка скопирована'**
  String get linkCopied;

  /// No description provided for @perHourSuffix.
  ///
  /// In ru, this message translates to:
  /// **'/час'**
  String get perHourSuffix;

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

  /// No description provided for @skipSports.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить — показывать все виды'**
  String get skipSports;

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

  /// No description provided for @historyEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пока пусто'**
  String get historyEmptyTitle;

  /// No description provided for @noBookingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Броней пока нет'**
  String get noBookingsTitle;

  /// No description provided for @noGamesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Игр пока нет'**
  String get noGamesTitle;

  /// No description provided for @findGame.
  ///
  /// In ru, this message translates to:
  /// **'Найти игру'**
  String get findGame;

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
  /// **'В Москве пока нет клубов для этого вида спорта.'**
  String get noVenuesForSportHint;

  /// No description provided for @noVenuesForQueryHint.
  ///
  /// In ru, this message translates to:
  /// **'По запросу «{query}» ничего не нашлось. Проверьте написание или сбросьте фильтры.'**
  String noVenuesForQueryHint(String query);

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

  /// No description provided for @signInWithEmail.
  ///
  /// In ru, this message translates to:
  /// **'Войти по почте'**
  String get signInWithEmail;

  /// No description provided for @emailSignInTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход по коду из письма'**
  String get emailSignInTitle;

  /// No description provided for @emailSignInHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите вашу электронную почту. Мы отправим шестизначный код для входа.'**
  String get emailSignInHint;

  /// No description provided for @emailLabel.
  ///
  /// In ru, this message translates to:
  /// **'Электронная почта'**
  String get emailLabel;

  /// No description provided for @sendEmailCode.
  ///
  /// In ru, this message translates to:
  /// **'Получить код'**
  String get sendEmailCode;

  /// No description provided for @emailCodeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Введите код из письма'**
  String get emailCodeTitle;

  /// No description provided for @emailCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код из 6 цифр'**
  String get emailCodeLabel;

  /// No description provided for @emailCodeSent.
  ///
  /// In ru, this message translates to:
  /// **'Отправили код на {email}'**
  String emailCodeSent(String email);

  /// No description provided for @emailCodeExpiresIn.
  ///
  /// In ru, this message translates to:
  /// **'Код действителен ещё {time}'**
  String emailCodeExpiresIn(String time);

  /// No description provided for @verifyEmailCode.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get verifyEmailCode;

  /// No description provided for @emailCheckSpam.
  ///
  /// In ru, this message translates to:
  /// **'Если письма нет, проверьте папку «Спам».'**
  String get emailCheckSpam;

  /// No description provided for @resendEmailCode.
  ///
  /// In ru, this message translates to:
  /// **'Отправить код повторно'**
  String get resendEmailCode;

  /// No description provided for @resendEmailCodeIn.
  ///
  /// In ru, this message translates to:
  /// **'Повторная отправка через {seconds} сек.'**
  String resendEmailCodeIn(int seconds);

  /// No description provided for @changeEmail.
  ///
  /// In ru, this message translates to:
  /// **'Изменить почту'**
  String get changeEmail;

  /// No description provided for @errorBadEmail.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте адрес электронной почты'**
  String get errorBadEmail;

  /// No description provided for @errorInvalidEmailCode.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код. Проверьте 6 цифр в последнем письме.'**
  String get errorInvalidEmailCode;

  /// No description provided for @errorEmailChallengeExpired.
  ///
  /// In ru, this message translates to:
  /// **'Код больше не действует. Запросите новый код.'**
  String get errorEmailChallengeExpired;

  /// No description provided for @errorEmailAttemptsExceeded.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много неверных попыток. Запросите новый код.'**
  String get errorEmailAttemptsExceeded;

  /// No description provided for @errorEmailUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить письмо. Попробуйте позже.'**
  String get errorEmailUnavailable;

  /// No description provided for @errorEmailTooManyRequests.
  ///
  /// In ru, this message translates to:
  /// **'Слишком частая отправка кодов. Попробуйте позже.'**
  String get errorEmailTooManyRequests;

  /// No description provided for @consent.
  ///
  /// In ru, this message translates to:
  /// **'Согласен с обработкой персональных данных и условиями сервиса'**
  String get consent;

  /// No description provided for @consentRequired.
  ///
  /// In ru, this message translates to:
  /// **'Отметьте согласие, чтобы продолжить'**
  String get consentRequired;

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

  /// No description provided for @chooseVenue.
  ///
  /// In ru, this message translates to:
  /// **'Выберите площадку'**
  String get chooseVenue;

  /// No description provided for @venuesToChoose.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} площадка рядом} few{{count} площадки рядом} many{{count} площадок рядом} other{{count} площадки рядом}}'**
  String venuesToChoose(int count);

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
  /// **'Сколько игроков'**
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
  /// **'Кто может играть'**
  String get participantFilter;

  /// No description provided for @participantFilterHint.
  ///
  /// In ru, this message translates to:
  /// **'Ограничение по полу имеет смысл для женских или мужских составов. В остальных случаях оставьте «Любой».'**
  String get participantFilterHint;

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

  /// No description provided for @bookingCreated.
  ///
  /// In ru, this message translates to:
  /// **'Бронь создана'**
  String get bookingCreated;

  /// No description provided for @bookingCreatedShares.
  ///
  /// In ru, this message translates to:
  /// **'Позовите игроков: им осталось оплатить {count, plural, one{{count} долю} few{{count} доли} other{{count} долей}}. Если за 2 часа до начала оплачены не все доли, бронь отменится, а деньги вернутся.'**
  String bookingCreatedShares(int count);

  /// No description provided for @bookingCreatedFull.
  ///
  /// In ru, this message translates to:
  /// **'Площадка ваша целиком — искать игроков не нужно.'**
  String get bookingCreatedFull;

  /// No description provided for @openBooking.
  ///
  /// In ru, this message translates to:
  /// **'Открыть бронь'**
  String get openBooking;

  /// No description provided for @bookingSuccessDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get bookingSuccessDone;

  /// No description provided for @successHeld.
  ///
  /// In ru, this message translates to:
  /// **'Время за вами до {when}'**
  String successHeld(String when);

  /// No description provided for @successFullBody.
  ///
  /// In ru, this message translates to:
  /// **'Оплатите бронь до этого срока, и площадка ваша. Не успеете — бронь отменится.'**
  String get successFullBody;

  /// No description provided for @bookingDetails.
  ///
  /// In ru, this message translates to:
  /// **'Бронь'**
  String get bookingDetails;

  /// No description provided for @statusLabel.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get statusLabel;

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
  /// **'{venue}, {date}, {time}. Место освободится для других, вернуть его не получится. Деньги вернутся в течение 1 рабочего дня.'**
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

  /// No description provided for @howPaymentWorks.
  ///
  /// In ru, this message translates to:
  /// **'Как это работает'**
  String get howPaymentWorks;

  /// No description provided for @payShareTitle.
  ///
  /// In ru, this message translates to:
  /// **'Своя часть · {price}'**
  String payShareTitle(String price);

  /// No description provided for @payShareExplainer.
  ///
  /// In ru, this message translates to:
  /// **'Вы платите свою долю, остальные {others, plural, one{{others} долю} few{{others} доли} other{{others} долей}} оплачивают другие игроки — всего {total}. Если за 2 часа до начала доли не собраны, бронь отменяется, а деньги возвращаются в течение 1 рабочего дня.'**
  String payShareExplainer(int others, String total);

  /// No description provided for @payFullTitle.
  ///
  /// In ru, this message translates to:
  /// **'Целиком · {price}'**
  String payFullTitle(String price);

  /// No description provided for @payFullExplainer.
  ///
  /// In ru, this message translates to:
  /// **'Площадка ваша сразу, искать игроков не нужно.'**
  String get payFullExplainer;

  /// No description provided for @cancellationTerms.
  ///
  /// In ru, this message translates to:
  /// **'Условия отмены'**
  String get cancellationTerms;

  /// No description provided for @cancellationTermAuto.
  ///
  /// In ru, this message translates to:
  /// **'Если за 2 часа до начала оплачены не все доли, бронь отменяется автоматически'**
  String get cancellationTermAuto;

  /// No description provided for @cancellationTermRefund.
  ///
  /// In ru, this message translates to:
  /// **'Если бронь отменена, деньги возвращаются в течение 1 рабочего дня'**
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
  /// **'открытые игры, куда можно вписаться'**
  String get gamesSubtitle;

  /// No description provided for @youAreIn.
  ///
  /// In ru, this message translates to:
  /// **'вы в игре'**
  String get youAreIn;

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

  /// No description provided for @players.
  ///
  /// In ru, this message translates to:
  /// **'Игроки'**
  String get players;

  /// No description provided for @leaveGame.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из игры'**
  String get leaveGame;

  /// No description provided for @sendRequest.
  ///
  /// In ru, this message translates to:
  /// **'Подать заявку'**
  String get sendRequest;

  /// No description provided for @requestSent.
  ///
  /// In ru, this message translates to:
  /// **'Заявка отправлена, ждём ответа организатора'**
  String get requestSent;

  /// No description provided for @game.
  ///
  /// In ru, this message translates to:
  /// **'Игра'**
  String get game;

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

  /// No description provided for @anyTime.
  ///
  /// In ru, this message translates to:
  /// **'В любое время'**
  String get anyTime;

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

  /// No description provided for @errorChallengeExpired.
  ///
  /// In ru, this message translates to:
  /// **'Время проверки истекло — получите новый номер для звонка'**
  String get errorChallengeExpired;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In ru, this message translates to:
  /// **'Подождите минуту перед новой попыткой'**
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

  /// No description provided for @paymentScreenTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата доли'**
  String get paymentScreenTitle;

  /// No description provided for @payYourShare.
  ///
  /// In ru, this message translates to:
  /// **'Ваша доля'**
  String get payYourShare;

  /// No description provided for @payRecipient.
  ///
  /// In ru, this message translates to:
  /// **'Получатель: {name}, {bank}'**
  String payRecipient(String name, String bank);

  /// No description provided for @payTestBanner.
  ///
  /// In ru, this message translates to:
  /// **'Тестовая оплата: счёт ещё не открыт, деньги не отправляйте.'**
  String get payTestBanner;

  /// No description provided for @payCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код доли'**
  String get payCodeLabel;

  /// No description provided for @payCodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Вставьте код в комментарий к переводу: по нему мы найдём вашу оплату.'**
  String get payCodeHint;

  /// No description provided for @payCopyCode.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать'**
  String get payCopyCode;

  /// No description provided for @payCodeCopied.
  ///
  /// In ru, this message translates to:
  /// **'Код скопирован'**
  String get payCodeCopied;

  /// No description provided for @payViaBank.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить через банк'**
  String get payViaBank;

  /// No description provided for @payBankFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось открыть банк. Отсканируйте QR с другого телефона.'**
  String get payBankFailed;

  /// No description provided for @payQrHint.
  ///
  /// In ru, this message translates to:
  /// **'Отсканируйте камерой телефона или в приложении банка'**
  String get payQrHint;

  /// No description provided for @payQrShow.
  ///
  /// In ru, this message translates to:
  /// **'Показать QR для другого устройства'**
  String get payQrShow;

  /// No description provided for @payQrHide.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть QR'**
  String get payQrHide;

  /// No description provided for @payIPaid.
  ///
  /// In ru, this message translates to:
  /// **'Я оплатил'**
  String get payIPaid;

  /// No description provided for @payDeadline.
  ///
  /// In ru, this message translates to:
  /// **'Все доли нужно оплатить до {when}'**
  String payDeadline(String when);

  /// No description provided for @payPendingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем оплату'**
  String get payPendingTitle;

  /// No description provided for @payPendingBody.
  ///
  /// In ru, this message translates to:
  /// **'Сверяем перевод с выпиской банка. Если не найдём, скажем здесь же.'**
  String get payPendingBody;

  /// No description provided for @payPaidTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата получена'**
  String get payPaidTitle;

  /// No description provided for @payPaidBody.
  ///
  /// In ru, this message translates to:
  /// **'Ваша доля оплачена. Бронь подтвердится, когда оплатят все.'**
  String get payPaidBody;

  /// No description provided for @payNotFoundTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не нашли перевод'**
  String get payNotFoundTitle;

  /// No description provided for @payNotFoundBody.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте сумму и код в комментарии и нажмите «Я оплатил» ещё раз.'**
  String get payNotFoundBody;

  /// No description provided for @payAdminNote.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий: {note}'**
  String payAdminNote(String note);

  /// No description provided for @payRefundDue.
  ///
  /// In ru, this message translates to:
  /// **'Бронь отменена. Деньги вернутся в течение 1 рабочего дня.'**
  String get payRefundDue;

  /// No description provided for @payRefunded.
  ///
  /// In ru, this message translates to:
  /// **'Деньги за эту долю вернули.'**
  String get payRefunded;

  /// No description provided for @payNothing.
  ///
  /// In ru, this message translates to:
  /// **'У вас нет доли в этой брони.'**
  String get payNothing;

  /// No description provided for @payMyShare.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить свою долю · {price}'**
  String payMyShare(String price);

  /// No description provided for @payMyPlace.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить своё место · {price}'**
  String payMyPlace(String price);

  /// No description provided for @payToBooking.
  ///
  /// In ru, this message translates to:
  /// **'Открыть бронь'**
  String get payToBooking;

  /// No description provided for @bookingStatusAwaiting.
  ///
  /// In ru, this message translates to:
  /// **'проверяем оплату'**
  String get bookingStatusAwaiting;

  /// No description provided for @shareOpenSeat.
  ///
  /// In ru, this message translates to:
  /// **'Свободное место'**
  String get shareOpenSeat;

  /// No description provided for @shareStatusOpen.
  ///
  /// In ru, this message translates to:
  /// **'свободно'**
  String get shareStatusOpen;

  /// No description provided for @shareStatusPending.
  ///
  /// In ru, this message translates to:
  /// **'проверяем оплату'**
  String get shareStatusPending;

  /// No description provided for @shareStatusNotFound.
  ///
  /// In ru, this message translates to:
  /// **'не нашли оплату'**
  String get shareStatusNotFound;

  /// No description provided for @shareStatusRefundDue.
  ///
  /// In ru, this message translates to:
  /// **'вернём деньги'**
  String get shareStatusRefundDue;

  /// No description provided for @shareStatusRefunded.
  ///
  /// In ru, this message translates to:
  /// **'деньги вернули'**
  String get shareStatusRefunded;

  /// No description provided for @errorSharePaid.
  ///
  /// In ru, this message translates to:
  /// **'Место уже оплачено. Выйти можно, только если организатор отменит бронь — тогда деньги вернутся.'**
  String get errorSharePaid;

  /// No description provided for @errorDeadlinePassed.
  ///
  /// In ru, this message translates to:
  /// **'Срок оплаты уже прошёл.'**
  String get errorDeadlinePassed;

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

  /// Заголовок ряда категорий на ярком главном экране
  ///
  /// In ru, this message translates to:
  /// **'Виды спорта'**
  String get sportsSection;

  /// Подпись над календарём на ярком главном экране
  ///
  /// In ru, this message translates to:
  /// **'Когда играете'**
  String get whenToPlay;

  /// Сколько игр в выбранный день
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} игра} few{{count} игры} other{{count} игр}}'**
  String gamesCount(int count);

  /// Заголовок ряда площадок с выбранной датой
  ///
  /// In ru, this message translates to:
  /// **'Свободно {date}'**
  String freeOnDate(String date);

  /// Сколько слотов свободно у площадки в выбранный день
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} слот} few{{count} слота} other{{count} слотов}}'**
  String slotsFree(int count);

  /// Подпись на карточке игры, когда свободных мест не осталось
  ///
  /// In ru, this message translates to:
  /// **'мест нет'**
  String get gameFull;

  /// Сколько осталось до начала игры, когда больше часа
  ///
  /// In ru, this message translates to:
  /// **'через {hours} ч {minutes} мин'**
  String startsInHours(int hours, int minutes);

  /// Сколько осталось до начала игры, когда меньше часа
  ///
  /// In ru, this message translates to:
  /// **'через {count, plural, one{{count} минуту} few{{count} минуты} other{{count} минут}}'**
  String startsInMinutes(int count);

  /// Игра начинается завтра
  ///
  /// In ru, this message translates to:
  /// **'завтра в {time}'**
  String startsTomorrow(String time);

  /// Игра уже началась
  ///
  /// In ru, this message translates to:
  /// **'идёт сейчас'**
  String get gameRunning;

  /// Примерное время пешком до площадки
  ///
  /// In ru, this message translates to:
  /// **'{count} мин пешком'**
  String walkMinutes(int count);

  /// Рейтинг и число отзывов
  ///
  /// In ru, this message translates to:
  /// **'{rating} · {count, plural, one{{count} отзыв} few{{count} отзыва} other{{count} отзывов}}'**
  String ratingWithReviews(String rating, int count);

  /// Сколько часов свободно у площадки в выбранный день
  ///
  /// In ru, this message translates to:
  /// **'свободно {count, plural, one{{count} час} few{{count} часа} other{{count} часов}}'**
  String freeHoursToday(int count);

  /// Кнопка на главной и заголовок экрана с бронями
  ///
  /// In ru, this message translates to:
  /// **'Мои брони'**
  String get myBookings;

  /// Кнопка на главной и заголовок экрана с играми игрока
  ///
  /// In ru, this message translates to:
  /// **'Мои игры'**
  String get myGames;

  /// Пустой экран «Мои игры»
  ///
  /// In ru, this message translates to:
  /// **'Вы пока не вступили ни в одну игру'**
  String get noMyGames;

  /// Сколько у игрока броней
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} бронь} few{{count} брони} other{{count} броней}}'**
  String bookingsCount(int count);

  /// Сколько игроков набрано из нужного
  ///
  /// In ru, this message translates to:
  /// **'{taken} из {capacity}'**
  String playersOfCapacity(int taken, int capacity);

  /// Строка «Уровень» в карточке игры
  ///
  /// In ru, this message translates to:
  /// **'Уровень'**
  String get gameLevel;

  /// Строка «Формат» в карточке игры
  ///
  /// In ru, this message translates to:
  /// **'Формат'**
  String get gameFormat;

  /// No description provided for @callToSignIn.
  ///
  /// In ru, this message translates to:
  /// **'Позвоните для входа'**
  String get callToSignIn;

  /// No description provided for @callFromPhone.
  ///
  /// In ru, this message translates to:
  /// **'Позвоните с вашего номера {phone} на номер ниже. Если у вас две SIM-карты, выберите нужную.'**
  String callFromPhone(String phone);

  /// No description provided for @callInstructions.
  ///
  /// In ru, this message translates to:
  /// **'Звонок бесплатный и автоматически сбросится. После звонка вернитесь в приложение — вход произойдёт автоматически.'**
  String get callInstructions;

  /// No description provided for @callPhone.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить'**
  String get callPhone;

  /// No description provided for @copyPhoneNumber.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать номер'**
  String get copyPhoneNumber;

  /// No description provided for @phoneCopied.
  ///
  /// In ru, this message translates to:
  /// **'Номер скопирован'**
  String get phoneCopied;

  /// No description provided for @waitingForCall.
  ///
  /// In ru, this message translates to:
  /// **'Ждём ваш звонок'**
  String get waitingForCall;

  /// No description provided for @callConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Номер подтверждён'**
  String get callConfirmed;

  /// No description provided for @callExpiresIn.
  ///
  /// In ru, this message translates to:
  /// **'Осталось времени: {time}'**
  String callExpiresIn(String time);

  /// No description provided for @checkCall.
  ///
  /// In ru, this message translates to:
  /// **'Я уже позвонил — проверить'**
  String get checkCall;

  /// No description provided for @restartCall.
  ///
  /// In ru, this message translates to:
  /// **'Получить новый номер'**
  String get restartCall;

  /// No description provided for @changePhone.
  ///
  /// In ru, this message translates to:
  /// **'Изменить свой номер'**
  String get changePhone;

  /// No description provided for @dialerUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть приложение для звонков. Наберите указанный номер вручную с вашего телефона.'**
  String get dialerUnavailable;

  /// No description provided for @bookingStateCollectingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Собираем оплату'**
  String get bookingStateCollectingTitle;

  /// No description provided for @bookingStateCollectingBody.
  ///
  /// In ru, this message translates to:
  /// **'Все доли нужно оплатить до {when}. Если не успеть, бронь снимется, а деньги вернутся в течение 1 рабочего дня.'**
  String bookingStateCollectingBody(String when);

  /// No description provided for @bookingStateAwaitingBody.
  ///
  /// In ru, this message translates to:
  /// **'Сверяем переводы с выпиской банка. Бронь подтвердится, когда найдём все.'**
  String get bookingStateAwaitingBody;

  /// No description provided for @bookingStateConfirmedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Бронь подтверждена'**
  String get bookingStateConfirmedTitle;

  /// No description provided for @bookingStateConfirmedBody.
  ///
  /// In ru, this message translates to:
  /// **'Время за вами: {when}.'**
  String bookingStateConfirmedBody(String when);

  /// No description provided for @bookingStateExpiredTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не собрали вовремя'**
  String get bookingStateExpiredTitle;

  /// No description provided for @bookingStateExpiredBody.
  ///
  /// In ru, this message translates to:
  /// **'Доли не оплатили до срока, поэтому бронь снята.'**
  String get bookingStateExpiredBody;

  /// No description provided for @bookingStateCancelledTitle.
  ///
  /// In ru, this message translates to:
  /// **'Бронь отменена'**
  String get bookingStateCancelledTitle;

  /// No description provided for @bookingStateRefundDue.
  ///
  /// In ru, this message translates to:
  /// **'Деньги вернём в течение 1 рабочего дня.'**
  String get bookingStateRefundDue;

  /// No description provided for @bookingStateRefunded.
  ///
  /// In ru, this message translates to:
  /// **'Деньги вернули.'**
  String get bookingStateRefunded;

  /// No description provided for @bookingStateNoMoney.
  ///
  /// In ru, this message translates to:
  /// **'Оплат не было, возвращать нечего.'**
  String get bookingStateNoMoney;

  /// No description provided for @takeShareButton.
  ///
  /// In ru, this message translates to:
  /// **'Занять место · {price}'**
  String takeShareButton(String price);

  /// No description provided for @takeShareNoPlaces.
  ///
  /// In ru, this message translates to:
  /// **'Свободных мест в этой брони нет.'**
  String get takeShareNoPlaces;

  /// No description provided for @takeShareClosed.
  ///
  /// In ru, this message translates to:
  /// **'Места в этой брони больше не раздают.'**
  String get takeShareClosed;

  /// No description provided for @joinGamePaid.
  ///
  /// In ru, this message translates to:
  /// **'Присоединиться · {price}'**
  String joinGamePaid(String price);

  /// No description provided for @adminPaymentsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплаты'**
  String get adminPaymentsTitle;

  /// No description provided for @adminPaymentsMenu.
  ///
  /// In ru, this message translates to:
  /// **'Проверить переводы и вернуть деньги'**
  String get adminPaymentsMenu;

  /// No description provided for @adminTabCheck.
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get adminTabCheck;

  /// No description provided for @adminTabRefund.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть'**
  String get adminTabRefund;

  /// No description provided for @adminEmptyCheck.
  ///
  /// In ru, this message translates to:
  /// **'Проверять нечего: все «Я оплатил» разобраны.'**
  String get adminEmptyCheck;

  /// No description provided for @adminEmptyRefund.
  ///
  /// In ru, this message translates to:
  /// **'Возвращать никому не нужно.'**
  String get adminEmptyRefund;

  /// No description provided for @adminPayer.
  ///
  /// In ru, this message translates to:
  /// **'В банке: {name}'**
  String adminPayer(String name);

  /// No description provided for @adminClaimed.
  ///
  /// In ru, this message translates to:
  /// **'Нажал «Я оплатил»: {when}'**
  String adminClaimed(String when);

  /// No description provided for @adminDeadline.
  ///
  /// In ru, this message translates to:
  /// **'Срок сбора: {when}'**
  String adminDeadline(String when);

  /// No description provided for @adminGameAt.
  ///
  /// In ru, this message translates to:
  /// **'{venue} · {when}'**
  String adminGameAt(String venue, String when);

  /// No description provided for @adminFound.
  ///
  /// In ru, this message translates to:
  /// **'Нашёл перевод'**
  String get adminFound;

  /// No description provided for @adminNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Не нашёл'**
  String get adminNotFound;

  /// No description provided for @adminRefunded.
  ///
  /// In ru, this message translates to:
  /// **'Деньги вернул'**
  String get adminRefunded;

  /// No description provided for @adminConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить оплату?'**
  String get adminConfirmTitle;

  /// No description provided for @adminConfirmMessage.
  ///
  /// In ru, this message translates to:
  /// **'{name}, {amount}, код {code}. Доля станет оплаченной.'**
  String adminConfirmMessage(String name, String amount, String code);

  /// No description provided for @adminRejectTitle.
  ///
  /// In ru, this message translates to:
  /// **'Почему не нашли перевод?'**
  String get adminRejectTitle;

  /// No description provided for @adminRejectHint.
  ///
  /// In ru, this message translates to:
  /// **'Причину увидит игрок на экране оплаты.'**
  String get adminRejectHint;

  /// No description provided for @adminRejectAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма не совпадает'**
  String get adminRejectAmount;

  /// No description provided for @adminRejectCode.
  ///
  /// In ru, this message translates to:
  /// **'Нет кода в комментарии'**
  String get adminRejectCode;

  /// No description provided for @adminRejectMissing.
  ///
  /// In ru, this message translates to:
  /// **'Перевода нет в выписке'**
  String get adminRejectMissing;

  /// No description provided for @adminRefundTitle.
  ///
  /// In ru, this message translates to:
  /// **'Деньги вернули?'**
  String get adminRefundTitle;

  /// No description provided for @adminRefundMessage.
  ///
  /// In ru, this message translates to:
  /// **'{name}, {amount}. Сначала верните возвратом по операции СБП в банке, потом отметьте здесь.'**
  String adminRefundMessage(String name, String amount);

  /// No description provided for @adminMarked.
  ///
  /// In ru, this message translates to:
  /// **'Отмечено'**
  String get adminMarked;

  /// No description provided for @adminPhoneCopied.
  ///
  /// In ru, this message translates to:
  /// **'Номер скопирован'**
  String get adminPhoneCopied;

  /// No description provided for @adminOnly.
  ///
  /// In ru, this message translates to:
  /// **'Этот раздел только для администратора оплат.'**
  String get adminOnly;

  /// No description provided for @adminEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Всё разобрано'**
  String get adminEmptyTitle;

  /// No description provided for @bookingStateYouDidNotPay.
  ///
  /// In ru, this message translates to:
  /// **'Вы не платили за это место, возвращать нечего.'**
  String get bookingStateYouDidNotPay;

  /// No description provided for @bookAgain.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать заново'**
  String get bookAgain;

  /// No description provided for @deleteAccount.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт'**
  String get deleteAccount;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In ru, this message translates to:
  /// **'Имя, телефон и почта удалятся. Неоплаченные места в будущих бронях освободятся, а деньги за оплаченные вернём в течение 1 рабочего дня. Отменить удаление нельзя.'**
  String get deleteAccountMessage;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить навсегда'**
  String get deleteAccountConfirm;
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
