import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// المستودع العام هو المصدر الوحيد للكتالوج والصور.
const String repoRawBase =
    'https://raw.githubusercontent.com/dotee313/ROGASTORE/main/';
const String catalogUrl = '${repoRawBase}apps.json';
const String storeUpdateUrl = '${repoRawBase}store_update.json';

/// يسمح بكتابة `assets/logo.svg` داخل apps.json بدل رابط كامل.
String remoteUrl(String value) {
  final v = value.trim();
  if (v.isEmpty) return '';
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  return '$repoRawBase${v.replaceFirst(RegExp(r'^/+'), '')}';
}

final Map<String, Future<Uint8List>> _bytesCache = {};

/// تحميل صورة مرة واحدة وتخزينها في الذاكرة لتجنب تكرار الطلبات.
Future<Uint8List> fetchBytes(String url) {
  final cached = _bytesCache[url];
  if (cached != null) return cached;
  final future = http
      .get(Uri.parse(url))
      .timeout(const Duration(seconds: 12))
      .then((r) {
    if (r.statusCode != 200) {
      throw HttpExceptionCompat(r.statusCode);
    }
    return r.bodyBytes;
  }).catchError((Object e) {
    _bytesCache.remove(url);
    throw e;
  });
  _bytesCache[url] = future;
  return future;
}

class HttpExceptionCompat implements Exception {
  final int status;
  const HttpExceptionCompat(this.status);
  @override
  String toString() => 'HTTP $status';
}

class CatalogReview {
  final String author;
  final int rating;
  final String text;
  final String date;

  const CatalogReview({
    required this.author,
    required this.rating,
    required this.text,
    required this.date,
  });

  factory CatalogReview.fromJson(Map<String, dynamic> j) {
    return CatalogReview(
      author: (j['author'] ?? 'مستخدم').toString(),
      rating: (j['rating'] is num
              ? (j['rating'] as num).toInt()
              : int.tryParse(j['rating'].toString()) ?? 5)
          .clamp(1, 5)
          .toInt(),
      text: (j['text'] ?? '').toString(),
      date: (j['date'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'author': author,
        'rating': rating,
        'text': text,
        'date': date,
      };
}

class AppItem {
  final String id;
  final String name;
  final String tagline;
  final String description;
  final String category;
  final String version;
  final String size;
  final String iconUrl;
  final String apkUrl;
  final String changelog;
  final List<String> screenshots;

  /// اسم الحزمة على أندرويد، ويُستخدم لمطابقة التطبيق المثبّت عند فحص التحديثات.
  final String packageName;

  /// تقييمات أولية اختيارية تأتي من الكتالوج.
  final List<CatalogReview> reviews;

  AppItem({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.category,
    required this.version,
    required this.size,
    required this.iconUrl,
    required this.apkUrl,
    required this.changelog,
    required this.screenshots,
    required this.packageName,
    required this.reviews,
  });

  factory AppItem.fromJson(Map<String, dynamic> j) {
    String s(String k) => (j[k] ?? '').toString();
    final rawScreenshots = j['screenshots'];
    final rawReviews = j['reviews'];
    return AppItem(
      id: s('id'),
      name: s('name'),
      tagline: s('tagline'),
      description: s('description'),
      category: s('category').isEmpty ? 'عام' : s('category'),
      version: s('version'),
      size: s('size'),
      iconUrl: s('iconUrl'),
      apkUrl: s('apkUrl'),
      changelog: s('changelog'),
      screenshots: rawScreenshots is List
          ? rawScreenshots.map((e) => e.toString()).toList()
          : const <String>[],
      packageName: s('packageName'),
      reviews: rawReviews is List
          ? rawReviews
              .whereType<Map>()
              .map((e) => CatalogReview.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const <CatalogReview>[],
    );
  }

  bool get hasApk => apkUrl.trim().isNotEmpty;
  String get iconLink => remoteUrl(iconUrl);
  String get apkLink => apkUrl.trim();
  List<String> get screenshotLinks =>
      screenshots.map(remoteUrl).where((e) => e.isNotEmpty).toList();
  String get lookupPackage => packageName.trim().isEmpty ? id : packageName.trim();
}

List<AppItem> _parse(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return const <AppItem>[];
  final apps = decoded['apps'];
  if (apps is! List) return const <AppItem>[];
  return apps
      .whereType<Map>()
      .map((e) => AppItem.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// الكتالوج البعيد أولاً، والنسخة المدمجة كحل احتياطي عند انقطاع الإنترنت.
Future<List<AppItem>> loadApps() async {
  try {
    final r = await http
        .get(Uri.parse('$catalogUrl?ts=${DateTime.now().millisecondsSinceEpoch}'))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      final parsed = _parse(utf8.decode(r.bodyBytes));
      if (parsed.isNotEmpty) return parsed;
    }
  } catch (_) {
    // يُستخدم الملف المدمج أدناه.
  }
  try {
    return _parse(await rootBundle.loadString('assets/apps.json'));
  } catch (_) {
    return const <AppItem>[];
  }
}
