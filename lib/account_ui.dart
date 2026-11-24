import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account.dart';
import 'config.dart';
import 'theme.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool? _admin;

  @override
  void initState() {
    super.initState();
    _refreshRole();
  }

  Future<void> _refreshRole() async {
    final value = await account.isAdmin();
    if (mounted) setState(() => _admin = value);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!isAllowedEmail(email)) {
      _snack('يُسمح فقط بإيميلات @$allowedEmailDomain');
      return;
    }
    setState(() => _busy = true);
    final error = _signUp
        ? await account.signUp(email: email, password: password)
        : await account.signIn(email: email, password: password);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(error ??
        (_signUp
            ? 'تم إنشاء الحساب — تحقق من بريدك لتفعيله'
            : 'تم تسجيل الدخول'));
    if (error == null) await _refreshRole();
  }

  @override
  Widget build(BuildContext context) {
    if (!account.configured) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'الحسابات غير مفعّلة لهذا البناء.\nأضف SUPABASE_URL و SUPABASE_ANON_KEY إلى GitHub Secrets ثم أعد البناء.',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.goldSoft, height: 1.7),
          ),
        ),
      );
    }

    return StreamBuilder<AuthState>(
      stream: account.changes,
      builder: (context, snap) {
        final signedIn =
            account.signedIn || snap.data?.session != null;
        if (!signedIn) return _authForm();
        return _profile();
      },
    );
  }

  Widget _authForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        const Icon(Icons.account_circle_outlined, size: 62, color: C.gold),
        const SizedBox(height: 14),
        const Text('حسابك في روجا ستور',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: C.gold, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('التسجيل متاح لإيميلات @$allowedEmailDomain فقط',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: C.goldSoft)),
        const SizedBox(height: 24),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: C.gold),
          decoration: _input('name@fatimiyoun.me'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          style: const TextStyle(color: C.gold),
          decoration: _input('كلمة المرور'),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: C.gold,
                foregroundColor: C.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            onPressed: _busy ? null : _submit,
            child: Text(_signUp ? 'إنشاء حساب' : 'تسجيل الدخول',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _signUp = !_signUp),
          child: Text(_signUp
              ? 'لديك حساب؟ سجّل الدخول'
              : 'ليس لديك حساب؟ أنشئ واحداً',
              style: const TextStyle(color: C.goldSoft)),
        ),
      ],
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: C.line),
        filled: true,
        fillColor: C.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: C.line)),
      );

  Widget _profile() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.verified_rounded, color: C.gold, size: 40),
            const SizedBox(height: 10),
            Text(account.email,
                style: const TextStyle(
                    color: C.gold, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              const Text('الصلاحية: ',
                  style: TextStyle(color: C.goldSoft, fontSize: 12)),
              Text(_admin == true ? 'مطوّر (أدمن)' : 'مستخدم',
                  style: const TextStyle(
                      color: C.gold, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
        if (_admin == true) ...[
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: C.gold,
                  foregroundColor: C.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPanel()),
              ),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('لوحة المطوّر',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () async {
            await account.signOut();
            if (mounted) setState(() => _admin = null);
          },
          icon: const Icon(Icons.logout, color: C.gold),
          label: const Text('تسجيل الخروج',
              style: TextStyle(color: C.gold)),
        ),
      ],
    );
  }
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة المطوّر'),
          bottom: const TabBar(
            labelColor: C.gold,
            unselectedLabelColor: C.goldSoft,
            indicatorColor: C.gold,
            tabs: [
              Tab(text: 'التطبيقات'),
              Tab(text: 'المستخدمون'),
              Tab(text: 'التقييمات'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _AppsAdmin(),
          _UsersAdmin(),
          _ReviewsAdmin(),
        ]),
      ),
    );
  }
}

TextStyle get _title =>
    const TextStyle(color: C.gold, fontSize: 15, fontWeight: FontWeight.bold);

class _AppsAdmin extends StatefulWidget {
  const _AppsAdmin();

  @override
  State<_AppsAdmin> createState() => _AppsAdminState();
}

class _AppsAdminState extends State<_AppsAdmin> {
  late Future<List<Map<String, dynamic>>> _future = account.adminApps();

  void _reload() => setState(() => _future = account.adminApps());

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.gold,
        foregroundColor: C.black,
        onPressed: () async {
          final saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const _AppEditor()),
          );
          if (saved == true) _reload();
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: C.gold));
          }
          if (snap.hasError) {
            return Center(child: Text('تعذّر التحميل: ${snap.error}'));
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد تطبيقات بعد'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              return Card(
                color: C.card,
                child: ListTile(
                  title: Text((row['name'] ?? row['id']).toString(),
                      style: _title),
                  subtitle: Text(
                      '${row['id']}  •  ${row['version'] ?? '-'}',
                      style: const TextStyle(fontSize: 11, color: C.goldSoft)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: C.gold),
                      onPressed: () async {
                        final saved = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => _AppEditor(data: row)),
                        );
                        if (saved == true) _reload();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: C.gold),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: C.surface,
                            title: const Text('تأكيد الحذف',
                                style: TextStyle(color: C.gold)),
                            content: const Text('حذف هذا التطبيق من الكتالوج؟',
                                style: TextStyle(color: C.goldSoft)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('إلغاء'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        try {
                          await account.deleteApp(row['id'].toString());
                          _reload();
                        } catch (e) {
                          _snack('تعذّر الحذف: $e');
                        }
                      },
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AppEditor extends StatefulWidget {
  final Map<String, dynamic>? data;
  const _AppEditor({this.data});

  @override
  State<_AppEditor> createState() => _AppEditorState();
}

class _AppEditorState extends State<_AppEditor> {
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _tagline;
  late final TextEditingController _description;
  late final TextEditingController _category;
  late final TextEditingController _version;
  late final TextEditingController _size;
  late final TextEditingController _icon;
  late final TextEditingController _apk;
  late final TextEditingController _package;
  late final TextEditingController _changelog;
  late final TextEditingController _shots;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final d = widget.data ?? const {};
    String s(String key) => d[key]?.toString() ?? '';
    _id = TextEditingController(text: s('id'));
    _name = TextEditingController(text: s('name'));
    _tagline = TextEditingController(text: s('tagline'));
    _description = TextEditingController(text: s('description'));
    _category = TextEditingController(text: s('category'));
    _version = TextEditingController(text: s('version'));
    _size = TextEditingController(text: s('size'));
    _icon = TextEditingController(text: s('icon_url'));
    _apk = TextEditingController(text: s('apk_url'));
    _package = TextEditingController(text: s('package_name'));
    _changelog = TextEditingController(text: s('changelog'));
    final shots = d['screenshots'];
    _shots = TextEditingController(
        text: shots is List ? shots.join(', ') : '');
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: C.line),
        filled: true,
        fillColor: C.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C.line)),
      );

  Widget _field(String label, TextEditingController c, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: lines,
          style: const TextStyle(color: C.gold),
          decoration: _dec(label),
        ),
      );

  Future<void> _pickApk() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['apk'],
      withData: false,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await account.uploadApk(file);
      if (mounted) setState(() => _apk.text = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_id.text.trim().isEmpty || _name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('المعرّف والاسم مطلوبان')));
      return;
    }
    setState(() => _saving = true);
    try {
      await account.saveApp({
        'id': _id.text.trim(),
        'name': _name.text.trim(),
        'tagline': _tagline.text.trim(),
        'description': _description.text.trim(),
        'category': _category.text.trim(),
        'version': _version.text.trim(),
        'size': _size.text.trim(),
        'icon_url': _icon.text.trim(),
        'apk_url': _apk.text.trim(),
        'package_name': _package.text.trim(),
        'changelog': _changelog.text.trim(),
        'screenshots': _shots.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّر الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل التطبيق')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _field('المعرّف (id) مثل shilagram', _id),
          _field('الاسم', _name),
          _field('الشعار القصير', _tagline),
          _field('الوصف', _description, lines: 3),
          _field('التصنيف', _category),
          _field('الإصدار', _version),
          _field('الحجم', _size),
          _field('رابط الأيقونة', _icon),
          _field('رابط APK', _apk),
          _field('اسم الحزمة', _package),
          _field('ما الجديد', _changelog, lines: 2),
          _field('لقطات الشاشة (روابط مفصولة بفاصلة)', _shots, lines: 2),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickApk,
            icon: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file),
            label: Text(_uploading ? 'جارٍ الرفع...' : 'اختيار ورفع ملف APK'),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: C.gold, foregroundColor: C.black),
              onPressed: _saving ? null : _save,
              child: const Text('حفظ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersAdmin extends StatefulWidget {
  const _UsersAdmin();

  @override
  State<_UsersAdmin> createState() => _UsersAdminState();
}

class _UsersAdminState extends State<_UsersAdmin> {
  late Future<List<Map<String, dynamic>>> _future = account.adminUsers();

  void _reload() => setState(() => _future = account.adminUsers());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: C.gold));
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return const Center(child: Text('لا يوجد مستخدمون'));
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            final isAdmin = row['role'] == 'admin';
            return Card(
              color: C.card,
              child: ListTile(
                title: Text((row['email'] ?? '-').toString(), style: _title),
                subtitle: Text(isAdmin ? 'مطوّر' : 'مستخدم',
                    style: const TextStyle(fontSize: 11, color: C.goldSoft)),
                trailing: IconButton(
                  icon: Icon(
                      isAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: C.gold),
                  tooltip: isAdmin ? 'إزالة الصلاحية' : 'منح صلاحية مطوّر',
                  onPressed: () async {
                    await account.setUserRole(
                        row['id'].toString(), isAdmin ? 'user' : 'admin');
                    _reload();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReviewsAdmin extends StatefulWidget {
  const _ReviewsAdmin();

  @override
  State<_ReviewsAdmin> createState() => _ReviewsAdminState();
}

class _ReviewsAdminState extends State<_ReviewsAdmin> {
  late Future<List<Map<String, dynamic>>> _future = account.adminReviews();

  void _reload() => setState(() => _future = account.adminReviews());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: C.gold));
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return const Center(child: Text('لا توجد تقييمات'));
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            return Card(
              color: C.card,
              child: ListTile(
                title: Text(
                    '${row['app_id']} — ${row['author'] ?? 'مستخدم'} (${row['rating']}★)',
                    style: _title),
                subtitle: Text((row['text'] ?? '').toString(),
                    style: const TextStyle(fontSize: 11, color: C.goldSoft)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: C.gold),
                  onPressed: () async {
                    await account.deleteReview(row['id'].toString());
                    _reload();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
