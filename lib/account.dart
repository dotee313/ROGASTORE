import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

/// كل عمليات الحسابات والصلاحيات تمرّ من هنا.
/// القاعدة الذهبية: التطبيق لا يقرر من هو الأدمن؛ الخادم هو الذي يقرر
/// عبر جدول profiles وسياسات RLS. لا يوجد أي مفتاح أدمن داخل الـ APK.
class AccountService {
  SupabaseClient get _client => Supabase.instance.client;

  bool get configured => backendReady;
  User? get user => configured ? _client.auth.currentUser : null;
  bool get signedIn => user != null;
  String get email => user?.email ?? '';

  Stream<AuthState> get changes =>
      configured ? _client.auth.onAuthStateChange : const Stream.empty();

  Future<bool> isAdmin() async {
    final u = user;
    if (u == null) return false;
    try {
      final row = await _client
          .from('profiles')
          .select('role')
          .eq('id', u.id)
          .maybeSingle();
      return row?['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  /// يرجع null عند النجاح، أو رسالة خطأ مقروءة عند الفشل.
  Future<String?> signUp({required String email, required String password}) async {
    if (!isAllowedEmail(email)) {
      return 'يُسمح فقط بإيميلات @$allowedEmailDomain';
    }
    if (password.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    try {
      await _client.auth.signUp(email: email.trim(), password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'تعذّر إنشاء الحساب، حاول مرة أخرى';
    }
  }

  Future<String?> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
          email: email.trim(), password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'تعذّر تسجيل الدخول، تحقّق من الإنترنت';
    }
  }

  Future<void> signOut() async {
    if (configured) await _client.auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    if (configured) {
      await _client.auth.resetPasswordForEmail(email.trim());
    }
  }

  List<Map<String, dynamic>> _rows(dynamic data) => (data as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .toList();

  Future<List<Map<String, dynamic>>> adminApps() async {
    final data = await _client
        .from('apps')
        .select()
        .order('id', ascending: true);
    return _rows(data);
  }

  /// يقرأ الكتالوج من Supabase إن كان مفعّلاً؛ القراءة عامة بسياسة RLS.
  Future<List<Map<String, dynamic>>> catalogRows() async {
    if (!configured) return const [];
    try {
      final data = await _client.from('apps').select();
      return _rows(data);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveApp(Map<String, dynamic> data) async {
    await _client.from('apps').upsert(data);
  }

  Future<void> deleteApp(String id) async {
    await _client.from('apps').delete().eq('id', id);
  }

  /// يرفع APK إلى Storage العام ويُرجع رابطه المباشر.
  Future<String> uploadApk(PlatformFile file) async {
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final ext = (file.extension ?? 'apk').replaceAll(RegExp(r'[^a-z0-9]'), '');
    final name = '${DateTime.now().millisecondsSinceEpoch}.app.$ext';
    final path = 'apps/$name';
    await _client.storage.from('apks').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/vnd.android.package-archive',
            upsert: true,
          ),
        );
    return _client.storage.from('apks').getPublicUrl(path);
  }

  Future<List<Map<String, dynamic>>> adminUsers() async {
    final data = await _client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);
    return _rows(data);
  }

  Future<void> setUserRole(String id, String role) async {
    await _client
        .from('profiles')
        .update({'role': role})
        .eq('id', id);
  }

  Future<void> deleteUser(String id) async {
    // حذف المستخدم من auth.users سيحذف profile تلقائياً عبر ON DELETE CASCADE.
    await _client.rpc('admin_delete_user', params: {'target': id});
  }

  Future<List<Map<String, dynamic>>> adminReviews() async {
    final data = await _client
        .from('reviews')
        .select()
        .order('created_at', ascending: false);
    return _rows(data);
  }

  Future<void> deleteReview(String id) async {
    await _client.from('reviews').delete().eq('id', id);
  }

  /// المستخدمون المسجّلون يضيفون تقييمهم إلى الخادم إن وُجد اتصال.
  Future<void> addReview({
    required String appId,
    required String author,
    required int rating,
    required String text,
  }) async {
    final u = user;
    if (u == null) return;
    await _client.from('reviews').insert({
      'app_id': appId,
      'user_id': u.id,
      'author': author,
      'rating': rating,
      'text': text,
    });
  }

  /// التقييمات البعيدة تُعرض للجميع، مع المحلية كنسخة احتياطية.
  Future<List<Map<String, dynamic>>> remoteReviews(String appId) async {
    if (!configured) return const [];
    try {
      final data = await _client
          .from('reviews')
          .select()
          .eq('app_id', appId)
          .order('created_at', ascending: false);
      return _rows(data);
    } catch (_) {
      return const [];
    }
  }
}

final account = AccountService();
