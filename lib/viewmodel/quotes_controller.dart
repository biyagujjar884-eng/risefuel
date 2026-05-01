import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/date_helper.dart';
import '../data/local/quotes_local_data.dart';
import '../data/models/quote_model.dart';
import '../data/remote/quotes_api.dart';

class QuotesController extends GetxController with WidgetsBindingObserver {
  QuotesController({
    required this.localData,
    required this.remoteData,
    required this.sharedPreferences,
    required this.dateHelper,
  });

  final QuotesLocalData localData;
  final QuotesApi remoteData;
  final SharedPreferences sharedPreferences;
  final DateHelper dateHelper;

  static const String _quotesCacheKey = 'cached_quotes_v1';
  static const String _quoteOfDayKey = 'cached_quote_of_day_v1';
  static const String _favoritesKey = 'favorite_quotes_v2';
  static const String _lastFetchDayKey = 'last_fetch_day_v1';
  static const String _lastFetchTimeKey = 'last_fetch_time_v1';
  static const String _currentIndexKey = 'current_index_v1';
  static const String _themeModeKey = 'theme_mode';
  static const String _autoRotateKey = 'auto_rotate_v1';

  final RxList<QuoteModel> _quotes = <QuoteModel>[].obs;
  final Rxn<QuoteModel> _quoteOfDay = Rxn<QuoteModel>();
  final RxMap<String, QuoteModel> _favoriteQuotes = <String, QuoteModel>{}.obs;
  final RxInt _currentIndex = 0.obs;
  final RxBool _isLoading = false.obs;
  final RxnString _error = RxnString();
  final Rx<ThemeMode> _themeMode = ThemeMode.system.obs;
  final Rxn<DateTime> _lastUpdated = Rxn<DateTime>();
  final RxBool _isAutoRotateEnabled = false.obs;
  
  Timer? _autoRotateTimer;
  bool _hasInitialized = false;

  bool get isLoading => _isLoading.value;
  String? get error => _error.value;
  ThemeMode get themeMode => _themeMode.value;
  List<QuoteModel> get quotes => _quotes.toList();
  QuoteModel? get quoteOfDay => _quoteOfDay.value;
  int get currentIndex => _currentIndex.value;
  DateTime? get lastUpdated => _lastUpdated.value;
  bool get isAutoRotateEnabled => _isAutoRotateEnabled.value;

  QuoteModel? get currentQuote => _quotes.isEmpty
      ? null
      : _quotes[_currentIndex.value.clamp(0, _quotes.length - 1)];

  List<QuoteModel> get favoriteQuotes => _favoriteQuotes.values.toList();

  bool isFavorite(QuoteModel quote) =>
      _favoriteQuotes.containsKey(quote.storageId);

  bool get canGoNext => _currentIndex.value < _quotes.length - 1;
  bool get canGoPrevious => _currentIndex.value > 0;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    _autoRotateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_shouldRefreshDaily()) {
        fetchLatestQuotes(force: false);
      }
    }
  }

  Future<void> initialize({bool forceRefresh = false}) async {
    if (!_hasInitialized || forceRefresh) {
      await _restoreState();
      _hasInitialized = true;
    }
    
    if (forceRefresh || _shouldRefreshDaily()) {
      await fetchLatestQuotes(force: forceRefresh);
    }
    
    if (_isAutoRotateEnabled.value) {
      _startAutoRotate();
    }
  }

  Future<void> _restoreState() async {
    _setLoading(true);
    try {
      await _restoreSettings();
      await _restoreCachedQuotes();
      await _restoreFavorites();

      _currentIndex.value = sharedPreferences.getInt(_currentIndexKey) ?? 0;
      _ensureCurrentIndexBounds();

      if (_quotes.isEmpty) {
        final local = await localData.loadQuotes();
        _quotes.assignAll(local);
      }
      
      final lastTimeStr = sharedPreferences.getString(_lastFetchTimeKey);
      if (lastTimeStr != null) {
        _lastUpdated.value = DateTime.tryParse(lastTimeStr);
      }

      _error.value = null;
      update();
    } catch (_) {
      _error.value = 'Initialized with offline mode.';
      update();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchLatestQuotes({bool force = false}) async {
    // If not forcing, only refresh if it's a new day
    if (!force && !_shouldRefreshDaily() && _quotes.isNotEmpty) return;

    _setLoading(true);
    try {
      // 1. Fetch Quote of the Day
      final QuoteModel? latestOfDay = await remoteData.fetchQuoteOfDay();
      
      // 2. Fetch a batch of fresh quotes
      final List<QuoteModel> fetchedQuotes = await remoteData.fetchQuotes();

      if (fetchedQuotes.isNotEmpty) {
        // Shuffle to make it feel fresh every time
        final shuffled = List<QuoteModel>.from(fetchedQuotes)..shuffle();
        _quotes.assignAll(shuffled);
      }

      if (latestOfDay != null) {
        _quoteOfDay.value = latestOfDay;
        // Ensure QOTD is at the top if not already in list
        if (!_quotes.any((q) => q.storageId == latestOfDay.storageId)) {
          _quotes.insert(0, latestOfDay);
        }
      }

      _currentIndex.value = 0;
      _lastUpdated.value = DateTime.now();
      _error.value = null;

      // Persist in background
      _persistAllState();
      update();
    } catch (e) {
      _error.value = _quotes.isEmpty 
          ? 'Network error. Please check your connection.'
          : 'Showing cached quotes. New fetch failed.';
      update();
    } finally {
      _setLoading(false);
    }
  }

  void toggleAutoRotate() {
    _isAutoRotateEnabled.value = !_isAutoRotateEnabled.value;
    sharedPreferences.setBool(_autoRotateKey, _isAutoRotateEnabled.value);
    
    if (_isAutoRotateEnabled.value) {
      _startAutoRotate();
    } else {
      _autoRotateTimer?.cancel();
    }
    update();
  }

  void _startAutoRotate() {
    _autoRotateTimer?.cancel();
    _autoRotateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (canGoNext) {
        goToNextQuote();
      } else {
        setCurrentIndex(0); // Loop back
      }
    });
  }

  void toggleFavorite(QuoteModel quote) {
    final id = quote.storageId;
    if (_favoriteQuotes.containsKey(id)) {
      _favoriteQuotes.remove(id);
    } else {
      _favoriteQuotes[id] = quote;
    }
    _persistFavorites();
    update();
  }

  void removeFavorite(QuoteModel quote) {
    if (_favoriteQuotes.remove(quote.storageId) != null) {
      _persistFavorites();
      update();
    }
  }

  void setCurrentIndex(int index) {
    if (_quotes.isEmpty) return;
    final int nextIndex = index.clamp(0, _quotes.length - 1);
    if (nextIndex == _currentIndex.value) return;
    
    _currentIndex.value = nextIndex;
    sharedPreferences.setInt(_currentIndexKey, _currentIndex.value);
    update();
  }

  void goToNextQuote() {
    if (canGoNext) setCurrentIndex(_currentIndex.value + 1);
  }

  void goToPreviousQuote() {
    if (canGoPrevious) setCurrentIndex(_currentIndex.value - 1);
  }

  void toggleThemeMode() {
    final next = _themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(next);
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode.value = mode;
    sharedPreferences.setString(_themeModeKey, mode.name);
    Get.changeThemeMode(mode);
    update();
  }

  bool _shouldRefreshDaily() {
    final String todayKey = dateHelper.dayKey();
    final String? stored = sharedPreferences.getString(_lastFetchDayKey);
    return stored == null || stored != todayKey;
  }

  Future<void> _restoreSettings() async {
    // Theme
    final themeStored = sharedPreferences.getString(_themeModeKey);
    if (themeStored != null) {
      _themeMode.value = ThemeMode.values.firstWhere(
        (m) => m.name == themeStored,
        orElse: () => ThemeMode.system,
      );
      Get.changeThemeMode(_themeMode.value);
    }

    // Auto rotate
    _isAutoRotateEnabled.value = sharedPreferences.getBool(_autoRotateKey) ?? false;
  }

  Future<void> _restoreCachedQuotes() async {
    final String? storedQuotes = sharedPreferences.getString(_quotesCacheKey);
    if (storedQuotes != null && storedQuotes.isNotEmpty) {
      try {
        final List<dynamic> data = jsonDecode(storedQuotes);
        _quotes.assignAll(data
            .whereType<Map<String, dynamic>>()
            .map(QuoteModel.fromJson)
            .toList());
      } catch (_) {}
    }

    final String? qotdStored = sharedPreferences.getString(_quoteOfDayKey);
    if (qotdStored != null && qotdStored.isNotEmpty) {
      try {
        _quoteOfDay.value = QuoteModel.fromJson(jsonDecode(qotdStored));
      } catch (_) {}
    }
  }

  Future<void> _restoreFavorites() async {
    final String? stored = sharedPreferences.getString(_favoritesKey);
    if (stored != null && stored.isNotEmpty) {
      try {
        final List<dynamic> data = jsonDecode(stored);
        final Map<String, QuoteModel> favs = {};
        for (var item in data.whereType<Map<String, dynamic>>()) {
          final q = QuoteModel.fromJson(item);
          favs[q.storageId] = q;
        }
        _favoriteQuotes.assignAll(favs);
      } catch (_) {}
    }
  }

  void _persistAllState() {
    // Background persistence to avoid blocking UI
    Future.wait([
      _persistQuotes(),
      _persistQuoteOfDay(),
      sharedPreferences.setString(_lastFetchDayKey, dateHelper.dayKey()),
      sharedPreferences.setString(_lastFetchTimeKey, _lastUpdated.value?.toIso8601String() ?? ''),
    ]);
  }

  Future<void> _persistQuotes() async {
    if (_quotes.isEmpty) return;
    final encoded = jsonEncode(_quotes.map((q) => q.toJson()).toList());
    await sharedPreferences.setString(_quotesCacheKey, encoded);
  }

  Future<void> _persistQuoteOfDay() async {
    if (_quoteOfDay.value == null) return;
    await sharedPreferences.setString(_quoteOfDayKey, jsonEncode(_quoteOfDay.value!.toJson()));
  }

  Future<void> _persistFavorites() async {
    final encoded = jsonEncode(_favoriteQuotes.values.map((q) => q.toJson()).toList());
    await sharedPreferences.setString(_favoritesKey, encoded);
  }

  void _ensureCurrentIndexBounds() {
    if (_quotes.isEmpty) {
      _currentIndex.value = 0;
    } else if (_currentIndex.value >= _quotes.length) {
      _currentIndex.value = _quotes.length - 1;
    }
  }

  void _setLoading(bool value) {
    if (_isLoading.value == value) return;
    _isLoading.value = value;
    update();
  }
}
