// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class LRu extends L {
  LRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'SportVenue';

  @override
  String get navHome => 'Главная';

  @override
  String get navSearch => 'Поиск';

  @override
  String get navGames => 'Игры';

  @override
  String get navProfile => 'Профиль';

  @override
  String get navCreate => 'Создать игру или бронь';

  @override
  String get createSheetTitle => 'Создать';

  @override
  String get createGameAction => 'Создать игру';

  @override
  String get createGameActionSubtitle => 'Соберите участников и оплатите долю';

  @override
  String get bookVenueAction => 'Забронировать площадку';

  @override
  String get bookVenueActionSubtitle => 'Выберите клуб и время';

  @override
  String get noVenuesAvailable => 'Доступных площадок пока нет';

  @override
  String get summaryDate => 'Дата';

  @override
  String get summaryTime => 'Время';

  @override
  String get summaryVenue => 'Площадка';

  @override
  String get summaryPlayers => 'Игроки';

  @override
  String get summaryTotal => 'Итого';

  @override
  String get summaryYourShare => 'Ваша часть';

  @override
  String get back => 'Назад';

  @override
  String get cancel => 'Отмена';

  @override
  String get durationHour => '1 час';

  @override
  String get durationHourAndHalf => '1.5 часа';

  @override
  String get durationTwoHours => '2 часа';

  @override
  String venueAddressDistance(String address, String km) {
    return '$address · $km км';
  }

  @override
  String pricePerHour(String price) {
    return '$price/час';
  }

  @override
  String bookingRowSubtitle(String time, String status) {
    return '$time · $status';
  }

  @override
  String get sportStep => 'Шаг 1 из 2';

  @override
  String get sportQuestion => 'Какой спорт?';

  @override
  String get sportHint => 'Можно выбрать несколько';

  @override
  String get sportsUnavailable => 'Виды спорта пока недоступны';

  @override
  String get continueLabel => 'Продолжить';

  @override
  String continueWithSports(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count видов',
      few: '$count вида',
      one: '$count вид',
    );
    return 'Продолжить · $_temp0';
  }

  @override
  String get sportsSaveFailed => 'Не удалось сохранить выбор';

  @override
  String greeting(String name) {
    return 'Привет, $name';
  }

  @override
  String get city => 'Москва';

  @override
  String get notifications => 'Уведомления';

  @override
  String get noNotifications => 'Уведомлений пока нет';

  @override
  String get searchPlaceholder => 'Найти площадку или игру';

  @override
  String get upcomingBooking => 'Предстоящая бронь';

  @override
  String get seeAll => 'Все';

  @override
  String get recommendedVenues => 'Рекомендованные площадки';

  @override
  String get openGames => 'Открытые игры';

  @override
  String get noUpcomingBookings => 'У вас пока нет предстоящих броней';

  @override
  String get profile => 'Профиль';

  @override
  String get accountSportVenue => 'Аккаунт SportVenue';

  @override
  String get demoAccountSportVenue => 'Демо-аккаунт SportVenue';

  @override
  String get userSportVenue => 'Пользователь SportVenue';

  @override
  String get noPhone => 'Номер не указан';

  @override
  String get editProfile => 'Редактировать профиль';

  @override
  String get editProfileLater => 'Редактирование профиля подключится позже';

  @override
  String get sportPreferences => 'Спортивные предпочтения';

  @override
  String get change => 'Изменить';

  @override
  String get history => 'История';

  @override
  String historySubtitle(int bookings, int games) {
    return '$bookings броней · $games игр';
  }

  @override
  String get logout => 'Выйти из аккаунта';

  @override
  String get logoutQuestion => 'Выйти из аккаунта?';

  @override
  String get logoutMessage =>
      'Брони и игры останутся на месте — чтобы вернуться к ним, придётся снова подтвердить номер телефона.';

  @override
  String get logoutConfirm => 'Выйти';

  @override
  String get logoutCancel => 'Остаться';

  @override
  String get statBookings => 'Броней';

  @override
  String get statMyGames => 'Моих игр';

  @override
  String get statSports => 'Видов спорта';

  @override
  String get historyEmpty => 'Здесь появятся ваши брони и игры';

  @override
  String get bookingsSection => 'Брони';

  @override
  String get gamesSection => 'Игры';

  @override
  String historySummary(int bookings, int games) {
    String _temp0 = intl.Intl.pluralLogic(
      bookings,
      locale: localeName,
      other: '$bookings броней',
      few: '$bookings брони',
      one: '$bookings бронь',
    );
    String _temp1 = intl.Intl.pluralLogic(
      games,
      locale: localeName,
      other: '$games игр',
      few: '$games игры',
      one: '$games игра',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get venuePickerTitle => 'Площадка';

  @override
  String get venuePickerSearchHint => 'Название или адрес';

  @override
  String get clear => 'Очистить';

  @override
  String get nothingFound => 'Ничего не нашлось';

  @override
  String nothingFoundFor(String query) {
    return 'По запросу «$query» нет ни клуба, ни адреса.';
  }

  @override
  String get reset => 'Сбросить';

  @override
  String get search => 'Поиск';

  @override
  String get searchSubtitle => 'Москва · openfreemap';

  @override
  String get centreOnMoscow => 'Центр Москвы';

  @override
  String get allFilter => 'Все';

  @override
  String get mapLoading => 'Карта загружается';

  @override
  String get searchFieldHint => 'Клуб, площадка или район';

  @override
  String get clearSearch => 'Очистить поиск';

  @override
  String clubsNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клубов',
      few: '$count клуба',
      one: '$count клуб',
    );
    return '$_temp0 рядом';
  }

  @override
  String get noVenuesForSport => 'Площадок этого вида нет';

  @override
  String get noVenuesForSportHint =>
      'В Москве пока нет клубов с этим покрытием.';

  @override
  String get resetSearch => 'Сбросить поиск';

  @override
  String get skipSplash => 'Пропустить заставку';

  @override
  String get signInTitle => 'Войти или\nзарегистрироваться';

  @override
  String get consent =>
      'Согласен с обработкой персональных данных и условиями сервиса';

  @override
  String get or => 'или';

  @override
  String get signInWithGoogle => 'Войти через Google';

  @override
  String get signInWithVk => 'Войти через VK';

  @override
  String get signInWithApple => 'Войти через Apple';

  @override
  String get termsFooter =>
      'Продолжая, вы соглашаетесь с условиями использования и политикой конфиденциальности';

  @override
  String get socialLater => 'Социальный вход подключится позже';

  @override
  String get wrongCode => 'Неверный код, попробуйте ещё раз';

  @override
  String get enterCode => 'Введите код';

  @override
  String codeHint(String phone) {
    return 'Мы звоним на $phone. Введите последние 4 цифры входящего номера';
  }

  @override
  String get resend => 'Отправить повторно';

  @override
  String resendIn(int seconds) {
    return 'Отправить повторно через $seconds с';
  }

  @override
  String get doNotAnswer =>
      'Не отвечайте на звонок — нужны только последние 4 цифры номера';

  @override
  String get callRequestedAgain => 'Звонок запрошен повторно';

  @override
  String get sportKind => 'Вид спорта';

  @override
  String get venueStep => 'Площадка';

  @override
  String get noVenuesForChosenSport =>
      'Для выбранного спорта площадок пока нет';

  @override
  String moreVenues(int count) {
    return 'ещё $count';
  }

  @override
  String get dateStep => 'Дата';

  @override
  String get startStep => 'Начало';

  @override
  String get pickVenueFirst => 'Сначала выберите площадку';

  @override
  String get durationStep => 'Продолжительность';

  @override
  String get placesStep => 'Количество мест';

  @override
  String get removePlace => 'Убрать место';

  @override
  String get addPlace => 'Добавить место';

  @override
  String placesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мест',
      few: '$count места',
      one: '$count место',
    );
    return '$_temp0';
  }

  @override
  String get whoCanJoin => 'Кто может вступить';

  @override
  String get approveManually => 'Одобрять вручную';

  @override
  String get approveManuallyHint => 'Вы будете подтверждать каждого игрока';

  @override
  String get participantFilter => 'Фильтр участников';

  @override
  String get genderAny => 'Любой';

  @override
  String get genderMen => 'Мужчины';

  @override
  String get genderWomen => 'Женщины';

  @override
  String get pricePerPerson => 'Стоимость с человека';

  @override
  String get emptyValue => '—';

  @override
  String get createGame => 'Создать игру';

  @override
  String get pickSportAndVenue => 'Выберите вид спорта и площадку';

  @override
  String get gameCreated => 'Игра создана';

  @override
  String get booking => 'Бронирование';

  @override
  String get timeStep => 'Время';

  @override
  String get playersStep => 'Игроки';

  @override
  String paySharePrice(String price) {
    return 'Оплатить свою часть · $price';
  }

  @override
  String payFullPrice(String price) {
    return 'Забронировать целиком · $price';
  }

  @override
  String get confirmation => 'Подтверждение';

  @override
  String get payConsent =>
      'Нажимая «Перейти к оплате», вы соглашаетесь с условиями сервиса и политикой конфиденциальности';

  @override
  String goToPayment(String price) {
    return 'Перейти к оплате · $price';
  }

  @override
  String get goBack => 'Вернуться назад';

  @override
  String get paymentDone => 'Оплата прошла, бронь создана';

  @override
  String get bookingDetails => 'Детали брони';

  @override
  String get onlyOrganizerCancels => 'Отменить бронь может только организатор';

  @override
  String get cancelBooking => 'Отменить бронь';

  @override
  String get cancelBookingQuestion => 'Отменить бронь?';

  @override
  String cancelBookingMessage(String venue, String date, String time) {
    return '$venue, $date, $time. Вернуть её тем же нажатием не получится.';
  }

  @override
  String get keepBooking => 'Оставить';

  @override
  String get bookingCancelled => 'Бронь отменена';

  @override
  String get bookingDetailsCard => 'Детали бронирования';

  @override
  String statusLine(String status) {
    return 'Статус · $status';
  }

  @override
  String get cancellationTerms => 'Условия отмены';

  @override
  String get cancellationTermAuto =>
      'Если игра не набирает участников за 2 часа до начала, бронь отменяется автоматически';

  @override
  String get cancellationTermRefund =>
      'Если вы отменяете сами, средства возвращаются на счёт в течение 3 дней';

  @override
  String get removePlayer => 'Убрать игрока';

  @override
  String get addPlayer => 'Добавить игрока';

  @override
  String playersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count игроков',
      few: '$count игрока',
      one: '$count игрок',
    );
    return '$_temp0';
  }

  @override
  String get unknownSport => 'Спорт';

  @override
  String get games => 'Игры';

  @override
  String get gamesSubtitle => 'pickup-матчи рядом';

  @override
  String get filters => 'Фильтры';

  @override
  String get filtersLater => 'Расширенные фильтры появятся позже';

  @override
  String get nothingMatchesFilters => 'Под фильтры ничего не подошло';

  @override
  String get nothingMatchesFiltersHint =>
      'Игры есть, но не в этом виде спорта или не в это время.';

  @override
  String get showAllGames => 'Показать все игры';

  @override
  String get noOpenGames => 'Открытых игр пока нет';

  @override
  String get noOpenGamesHint =>
      'Создайте свою — участники смогут вступить и оплатить долю.';

  @override
  String gameWhen(String date, String time) {
    return '$date · $time';
  }

  @override
  String freePlaces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мест',
      few: '$count места',
      one: '$count место',
    );
    return '$_temp0 свободно';
  }

  @override
  String get join => 'Вступить';

  @override
  String get joined => 'Вы присоединились к игре';

  @override
  String get alreadyJoined => 'Вы уже в этой игре';

  @override
  String get price => 'Стоимость';

  @override
  String get organizer => 'Организатор';

  @override
  String get chatLater => 'Чат подключится позже';

  @override
  String get write => 'Написать';

  @override
  String get players => 'игроки';

  @override
  String get leaveGame => 'Выйти из игры';

  @override
  String get requestAfterApproval => 'Заявка и оплата после одобрения';

  @override
  String get joinGame => 'Присоединиться к игре';

  @override
  String get leaveGameQuestion => 'Выйти из игры?';

  @override
  String leaveGameMessage(String venue, String date, String time) {
    return '$venue, $date · $time. Место вернётся в игру, и его сможет занять кто-то другой.';
  }

  @override
  String get leaveConfirm => 'Выйти';

  @override
  String get stay => 'Остаться';

  @override
  String get leftGame => 'Вы вышли из игры';

  @override
  String get wasNotInGame => 'Вас не было в этой игре';

  @override
  String get evening => 'Вечер';

  @override
  String get anyDay => 'Любой день';

  @override
  String rating(String value) {
    return 'Рейтинг $value';
  }

  @override
  String get freeSlot => 'свободно';

  @override
  String get openGame => 'Открытая игра';

  @override
  String get approvalGame => 'Игра по одобрению';

  @override
  String get closedGame => 'Закрытая игра';

  @override
  String get retry => 'Повторить';

  @override
  String get noFreeSlots => 'На эту дату свободных слотов нет';

  @override
  String get errorNetwork => 'сервер недоступен — проверьте, что он запущен';

  @override
  String get errorInvalidResponse => 'сервер вернул неожиданный ответ';

  @override
  String get errorSessionExpired => 'сессия истекла — войдите снова';

  @override
  String get errorSlotTaken => 'этот слот уже занят, выберите другое время';

  @override
  String get errorGameFull => 'в игре больше нет свободных мест';

  @override
  String get errorCancelNotOrganizer =>
      'отменить бронь может только организатор';

  @override
  String get errorBadPhone => 'проверьте номер телефона';

  @override
  String get errorInvalidCode => 'Неверный код, попробуйте ещё раз';

  @override
  String get errorChallengeExpired =>
      'время проверки истекло — запросите новый звонок';

  @override
  String get errorTooManyAttempts =>
      'слишком много попыток — запросите новый звонок';

  @override
  String get errorTimeout => 'сервер не ответил вовремя';

  @override
  String get errorUnknown => 'не удалось выполнить запрос';

  @override
  String get bookingStatusCollecting => 'ожидает участников';

  @override
  String get bookingStatusConfirmed => 'подтверждена';

  @override
  String get bookingStatusCancelled => 'отменена';

  @override
  String get bookingStatusExpired => 'истекла';

  @override
  String bookingStatusCollectingPaid(int paid, int total) {
    return 'оплатили $paid из $total';
  }

  @override
  String get sharesTitle => 'Оплата долей';

  @override
  String get sharePaid => 'оплачено';

  @override
  String get shareUnpaid => 'ждём оплату';

  @override
  String sharesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'осталось $count долей',
      few: 'осталось $count доли',
      one: 'осталась $count доля',
    );
    return '$_temp0';
  }

  @override
  String get sharesAllPaid => 'все доли оплачены';

  @override
  String get player => 'Игрок';

  @override
  String get playerOrganizer => 'Организатор';

  @override
  String get playerGames => 'Игры этого участника';

  @override
  String get playerNoGames => 'Других игр этого участника здесь нет';

  @override
  String get playerPending => 'ждёт одобрения';

  @override
  String get vividNearby => 'Рядом';

  @override
  String get vividTonight => 'Сегодня вечером';

  @override
  String get vividNewVenues => 'Новые площадки';

  @override
  String get vividFreeNow => 'Свободно сейчас';

  @override
  String vividFrom(String price) {
    return 'от $price';
  }

  @override
  String get vividBook => 'Забронировать';

  @override
  String get vividPickedForYou => 'Подобрали для вас';
}
