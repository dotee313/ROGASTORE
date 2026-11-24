import 'dart:convert';
import 'dart:io';

import 'package:installed_apps/installed_apps.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';

const String kAutoUpdate = 'auto_update';
const String kAutoStore = 'auto_store_apps';
const String kAutoApps = 'auto_store_installed_apps';
const String kReviews = 'reviews_v1';
const String kDownloads = 'downloads_v1';

enum UpdateKind { store, app }

class UpdateInfo {
  final UpdateKind kind;
  final String id;
  final String title;
  final String version;
  final String url;
  final String notes;

  const UpdateInfo({
    required this.kind,
    required this.id,
    required this.title,
    required this.version,
    required this.url,
    required this.notes,
  });

  bool get isStore => kind == UpdateKind.store;
}

class DownloadState {
  final String id;
  final String label;
  final double progress;
  final bool done;
  final String? error;

  const DownloadState({
    required this.id,
    required this.label,
    required this.progress,
    this.done = false,
    this.error,
  });
}

/// مقارنة إصدارات بسيطة تتجاهل البادئة `v` وتتعامل مع الأجزاء غير الرقمية.
int compareVersion(String a, String b) {
  String norm(String s) => s.trim().toLowerCase().replaceFirst(RegExp(r'^v'), '');
  final pa = norm(a).split(RegExp(r'[.\-_+]'));
  final pb = norm(b).split(RegExp(r'[.\-_]+'));
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final ia = i < pa.length ? int.tryParse(pa[i]) ?? 0 : 0;
    final ib = i < pb.length ? int.tryParse(pb[i]) ?? 0 : 0;
    if (ia != ib) return ia > ib ? 1 : -1;
  }
  return 0;
}

class ReviewStore {
  final SharedPreferences prefs;
  ReviewStore(this.prefs);

  Map<String, List<Map<String, dynamic>>> _readAll() {
    final raw = prefs.getString(kReviews);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(
          k,
          (v is List)
              ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : <Map<String, dynamic>>[],
        ),
      );
    } catch (_) {
      return {};
    }
  }

  List<CatalogReview> load(String appId) {
    final raw = _readAll()[appId] ?? const [];
    return raw.map(CatalogReview.fromJson).toList();
  }

  Future<void> add(String appId, CatalogReview review) async {
    final all = _readAll();
    final list = all[appId] ?? <Map<String, dynamic>>[];
    list.add(review.toJson());
    all[appId] = list;
    await prefs.setString(kReviews, jsonEncode(all));
  }
}

class UpdateManager {
  final ValueNotifier<DownloadState?> active = ValueNotifier<DownloadState?>(null);
  final ValueNotifier<List<UpdateInfo>> available =
      ValueNotifier<List<UpdateInfo>>(const []);

  SharedPreferences? _prefs;
  String _currentVersion = '0.0.0';
  CancelToken? _cancel;
  bool _checking = false;
  String _lastMessage = '';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;
    } catch (_) {
      // الإصدار الافتراضي يبقى كما هو.
    }
  }

  String get currentVersion => _currentVersion;
  String get lastMessage => _lastMessage;

  bool get master => _prefs?.getBool(kAutoUpdate) ?? true;
  bool get autoStore => master && (_prefs?.getBool(kAutoStore) ?? true);
  bool get autoApps => master && (_prefs?.getBool(kAutoApps) ?? true);

  Future<void> setMaster(bool v) async => await _prefs?.setBool(kAutoUpdate, v);
  Future<void> setAutoStore(bool v) async => await _prefs?.setBool(kAutoStore, v);
  Future<void> setAutoApps(bool v) async => await _prefs?.setBool(kAutoApps, v);

  ReviewStore? get reviews => _prefs == null ? null : ReviewStore(_prefs!);

  Map<String, String> _downloads() {
    final raw = _prefs?.getString(kDownloads);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  String? downloadedPath(String id) => _downloads()[id];

  Future<void> _rememberDownload(String id, String path) async {
    final all = _downloads();
    all[id] = path;
    await _prefs?.setString(kDownloads, jsonEncode(all));
  }

  Future<UpdateInfo?> _checkStore() async {
    try {
      final r = await http
          .get(Uri.parse('$storeUpdateUrl?ts=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final version = (data['version'] ?? '').toString();
      final url = (data['apkUrl'] ?? '').toString();
      if (version.isEmpty || url.isEmpty) return null;
      if (compareVersion(version, _currentVersion) <= 0) return null;
      return UpdateInfo(
        kind: UpdateKind.store,
        id: 'store',
        title: 'روجا ستور',
        version: version,
        url: remoteUrl(url),
        notes: (data['notes'] ?? 'تحديث جديد للمتجر').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<UpdateInfo>> _checkApps() async {
    if (kIsWeb || !Platform.isAndroid) return const [];
    final found = <UpdateInfo>[];
    try {
      final apps = await loadApps();
      final packages = apps.map((a) => a.lookupPackage).toList();
      final installed = packages.isEmpty
          ? const <AppInfo>[]
          : await InstalledApps.getInstalledApps(
              packageNames: packages,
              excludeSystemApps: true,
              withIcon: false,
            );
      final versions = <String, String>{};
      for (final a in installed) {
        final v = a.versionName.trim();
        if (v.isNotEmpty) versions[a.packageName] = v;
      }
      for (final app in apps) {
        if (!app.hasApk) continue;
        final current = versions[app.lookupPackage];
        if (current == null) continue;
        if (compareVersion(app.version, current) > 0) {
          found.add(UpdateInfo(
            kind: UpdateKind.app,
            id: app.id,
            title: app.name,
            version: app.version,
            url: app.apkLink,
            notes: app.changelog.isEmpty ? 'إصدار أحدث متاح' : app.changelog,
          ));
        }
      }
    } catch (_) {
      // قد يفشل الفحص إن لم تُمنح صلاحية QUERY_ALL_PACKAGES.
    }
    return found;
  }

  /// يفحص التحديثات، ويُنزّلها تلقائياً عند تفعيل الخيار.
  Future<void> check({bool download = true}) async {
    if (_checking) return;
    _checking = true;
    try {
      // الفحص دائماً يعمل؛ الإعدادات تتحكم في التنزيل التلقائي فقط،
      // حتى يستطيع المستخدم إيقاف التنزيل التلقائي والفحص يدوياً.
      final found = <UpdateInfo>[];
      final s = await _checkStore();
      if (s != null) found.add(s);
      found.addAll(await _checkApps());
      available.value = found;
      _lastMessage = found.isEmpty ? 'لا توجد تحديثات متاحة' : 'توجد ${found.length} تحديثات';

      if (download && master) {
        for (final u in found) {
          if (u.isStore && !autoStore) continue;
          if (!u.isStore && !autoApps) continue;
          if (active.value != null && !active.value!.done) continue;
          await downloadUpdate(u, install: false, automatic: true);
        }
      }
    } finally {
      _checking = false;
    }
  }

  Future<String> _targetPath(String id) async {
    final dir = await getApplicationDocumentsDirectory();
    final updates = Directory('${dir.path}${Platform.pathSeparator}updates');
    if (!updates.existsSync()) await updates.create(recursive: true);
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '${updates.path}${Platform.pathSeparator}$safe.apk';
  }

  /// تنزيل قابل للإلغاء. `install=true` يفتح مثبّت أندرويد بعد اكتمال التنزيل.
  Future<void> downloadUpdate(
    UpdateInfo u, {
    bool install = false,
    bool automatic = false,
  }) async {
    if (u.url.isEmpty) return;
    final previous = active.value;
    if (previous != null && previous.id == u.id && !previous.done) return;

    active.value = DownloadState(id: u.id, label: u.title, progress: 0);
    CancelToken? token;
    try {
      final path = await _targetPath(u.id);
      token = CancelToken();
      _cancel = token;
      await Dio().download(
        u.url,
        path,
        cancelToken: token,
        onReceiveProgress: (received, total) {
          if (active.value?.id != u.id) return;
          final p = total > 0 ? received / total : -1.0;
          active.value = DownloadState(
              id: u.id, label: u.title, progress: p > 1 ? 1 : p);
        },
      );
      await _rememberDownload(u.id, path);
      active.value = DownloadState(
          id: u.id, label: u.title, progress: 1, done: true);
      if (install) {
        await OpenFilex.open(path,
            type: 'application/vnd.android.package-archive');
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        active.value = null;
        return;
      }
      active.value = DownloadState(
        id: u.id,
        label: u.title,
        progress: 0,
        error: automatic
            ? 'تعذّر التنزيل التلقائي، يمكنك المحاولة يدوياً'
            : 'تعذّر التنزيل، تحقّق من الرابط أو الإنترنت',
      );
    } catch (_) {
      active.value = DownloadState(
        id: u.id,
        label: u.title,
        progress: 0,
        error: 'تعذّر التنزيل، حاول مرة أخرى',
      );
    } finally {
      if (_cancel == token) _cancel = null;
    }
  }

  void cancelDownload() {
    _cancel?.cancel('ألغى المستخدم التنزيل');
  }

  Future<void> installDownloaded(String id) async {
    final path = downloadedPath(id);
    if (path == null) return;
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      await OpenFilex.open(path,
          type: 'application/vnd.android.package-archive');
    } catch (_) {
      // واجهة التنزيل تعرض الحالة المناسبة.
    }
  }
}

final updateManager = UpdateManager();
