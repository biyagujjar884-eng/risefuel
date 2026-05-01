import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/quote_model.dart';

class QuotesApi {
  QuotesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _quotesEndpoint = 'https://zenquotes.io/api/quotes';
  static const String _todayEndpoint = 'https://zenquotes.io/api/today';
  static const String _randomEndpoint = 'https://zenquotes.io/api/random';

  Future<List<QuoteModel>> fetchQuotes() async {
    final response = await _client.get(Uri.parse(_quotesEndpoint));
    if (response.statusCode != 200) {
      throw QuotesApiException(
        'Failed to fetch quotes: HTTP ${response.statusCode}',
      );
    }
    final dynamic payload = jsonDecode(response.body);
    if (payload is! List) {
      throw QuotesApiException('Unexpected format for quotes response.');
    }
    return payload
        .whereType<Map<String, dynamic>>()
        .map(QuoteModel.fromJson)
        .toList(growable: false);
  }

  Future<QuoteModel?> fetchQuoteOfDay() async {
    final response = await _client.get(Uri.parse(_todayEndpoint));
    if (response.statusCode != 200) {
      throw QuotesApiException(
        'Failed to fetch quote of the day: HTTP ${response.statusCode}',
      );
    }
    final dynamic payload = jsonDecode(response.body);
    if (payload is List && payload.isNotEmpty) {
      final dynamic first = payload.first;
      if (first is Map<String, dynamic>) {
        return QuoteModel.fromJson(first);
      }
    }
    return null;
  }

  Future<QuoteModel?> fetchRandomQuote() async {
    final response = await _client.get(Uri.parse(_randomEndpoint));
    if (response.statusCode != 200) {
      throw QuotesApiException(
        'Failed to fetch random quote: HTTP ${response.statusCode}',
      );
    }
    final dynamic payload = jsonDecode(response.body);
    if (payload is List && payload.isNotEmpty) {
      final dynamic first = payload.first;
      if (first is Map<String, dynamic>) {
        return QuoteModel.fromJson(first);
      }
    }
    return null;
  }
}

class QuotesApiException implements Exception {
  QuotesApiException(this.message);
  final String message;

  @override
  String toString() => 'QuotesApiException: $message';
}

