import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'account.dart';
import 'account_ui.dart';
import 'catalog.dart';
import 'services.dart';
import 'theme.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    // الفحص عند التشغيل؛ التنزيل الفعلي يتحقق من الإعدادات داخل UpdateManager.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateManager.check(download: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const _DownloadStrip(),
          Expanded(
            child: IndexedStack(index: _i, children: const [
              StorePage(),
              UpdatesPage(),
              SettingsPage(),
              AccountPage(),
              AboutPage(),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.storefront_outlined), label: 'المتجر'),
          NavigationDestination(
              icon: Icon(Icons.system_update_alt_outlined), label: 'التحديثات'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'الإعدادات'),
          NavigationDestination(
              icon: Icon(Icons.account_circle_outlined), label: 'حسابي'),
          NavigationDestination(
              icon: Icon(Icons.info_outline), label: 'عن روجا'),
        ],
      ),
    );
  }
}

class _DownloadStrip extends StatelessWidget {
  const _DownloadStrip();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DownloadState?>(
      valueListenable: updateManager.active,
      builder: (context, s, _) {
        if (s == null) return const SizedBox.shrink();
        final p = s.progress;
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [C.card, C.surface], begin: Alignment.topRight),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: C.gold.withValues(alpha: .45)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: C.purple.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.download_rounded, color: C.gold, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: C.gold, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                if (s.error != null)
                  Text(s.error!,
                      style: const TextStyle(color: C.purpleLight, fontSize: 11))
                else if (s.done)
                  const Text('اكتمل التنزيل',
                      style: TextStyle(color: C.goldSoft, fontSize: 11))
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: p < 0 ? null : p,
                      minHeight: 5,
                      color: C.gold,
                      backgroundColor: C.purple.withValues(alpha: .3),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            if (s.done)
              IconButton(
                tooltip: 'تثبيت',
                onPressed: () => updateManager.installDownloaded(s.id),
                icon: const Icon(Icons.install_mobile, color: C.gold),
              )
            else
              IconButton(
                tooltip: 'إلغاء',
                onPressed: () {
                  if (s.error != null) {
                    updateManager.active.value = null;
                  } else {
                    updateManager.cancelDownload();
                  }
                },
                icon: const Icon(Icons.close, color: C.gold),
              ),
          ]),
        );
      },
    );
  }
}

class AppIcon extends StatelessWidget {
  final AppItem app;
  final double size;

  const AppIcon(this.app, {super.key, this.size = 58});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [C.purple, C.black],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: C.gold.withValues(alpha: .7), width: 1),
        borderRadius: BorderRadius.circular(size * .26),
      ),
      child: Text(
        app.name.isEmpty ? '?' : app.name.characters.first,
        style: TextStyle(
            color: C.gold, fontSize: size * .42, fontWeight: FontWeight.bold),
      ),
    );

    final url = app.iconLink;
    if (url.isEmpty) return fallback;
    final isSvg = Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .26),
      child: FutureBuilder<Uint8List>(
        future: fetchBytes(url),
        builder: (context, snap) {
          if (snap.hasData) {
            final bytes = snap.data!;
            return isSvg
                ? SvgPicture.memory(bytes, width: size, height: size,
                    fit: BoxFit.cover)
                : Image.memory(bytes, width: size, height: size,
                    fit: BoxFit.cover);
          }
          if (snap.hasError) return fallback;
          return Container(
            width: size,
            height: size,
            color: C.card,
            child: Center(
              child: SizedBox(
                width: size * .35,
                height: size * .35,
                child: const CircularProgressIndicator(
                    color: C.gold, strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// صورة بعيدة تُحمّل مرة واحدة عبر الكاش نفسه الذي تستخدمه الأيقونات،
/// لتجنّب اختفاء الصور عند فشل Image.network داخل التطبيق.
class _RemoteImage extends StatelessWidget {
  final String url;

  const _RemoteImage(this.url);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FutureBuilder<Uint8List>(
        future: fetchBytes(url),
        builder: (context, snap) {
          if (snap.hasData) {
            return Image.memory(snap.data!,
                width: 140, height: 210, fit: BoxFit.cover);
          }
          return Container(
            width: 140,
            height: 210,
            color: C.card,
            alignment: Alignment.center,
            child: snap.hasError
                ? const Icon(Icons.image_not_supported_outlined,
                    color: C.purpleLight)
                : const CircularProgressIndicator(color: C.gold, strokeWidth: 2),
          );
        },
      ),
    );
  }
}

class StorePage extends StatefulWidget {
  const StorePage({super.key});
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  late Future<List<AppItem>> _f = loadApps();
  String _q = '';
  String _cat = 'الكل';

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: C.gold,
      backgroundColor: C.card,
      onRefresh: () async {
        setState(() => _f = loadApps());
        await _f;
      },
      child: FutureBuilder<List<AppItem>>(
        future: _f,
        builder: (context, snap) {
          final all = snap.data ?? const <AppItem>[];
          final cats = <String>{'الكل', ...all.map((a) => a.category)}.toList();
          final list = all.where((a) {
            final okCat = _cat == 'الكل' || a.category == _cat;
            final okQ = _q.isEmpty ||
                a.name.contains(_q) ||
                a.tagline.contains(_q);
            return okCat && okQ;
          }).toList();

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Row(children: [
                SvgPicture.asset('assets/logo.svg', width: 46, height: 46),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('روجا ستور',
                        style: TextStyle(
                            color: C.gold,
                            fontSize: 23,
                            fontWeight: FontWeight.bold)),
                    Text('متجر تطبيقاتي الخاص',
                        style: TextStyle(fontSize: 12, color: C.goldSoft)),
                  ]),
                ),
                IconButton(
                  tooltip: 'التحديثات',
                  onPressed: () => updateManager.check(download: false),
                  icon: const Icon(Icons.refresh, color: C.gold),
                ),
              ]),
              const SizedBox(height: 18),
              TextField(
                onChanged: (v) => setState(() => _q = v.trim()),
                style: const TextStyle(color: C.gold),
                cursorColor: C.gold,
                decoration: InputDecoration(
                  hintText: 'ابحث عن تطبيق',
                  hintStyle: const TextStyle(color: C.line),
                  prefixIcon: const Icon(Icons.search, color: C.gold),
                  filled: true,
                  fillColor: C.card,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: C.line)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: C.gold)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ChoiceChip(
                    label: Text(cats[i]),
                    selected: _cat == cats[i],
                    onSelected: (_) => setState(() => _cat = cats[i]),
                    showCheckmark: false,
                    backgroundColor: C.card,
                    selectedColor: C.purple,
                    labelStyle: TextStyle(
                        color: _cat == cats[i] ? C.gold : C.goldSoft),
                    side: BorderSide(
                        color: _cat == cats[i] ? C.gold : C.line),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (snap.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.only(top: 70),
                  child: Center(
                      child: CircularProgressIndicator(color: C.gold)),
                )
              else if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 70),
                  child: Center(child: Text('لا توجد تطبيقات')),
                )
              else
                ...list.map((a) => _AppCard(a)),
            ],
          );
        },
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final AppItem app;
  const _AppCard(this.app);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: C.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => DetailsPage(app))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.line),
            ),
            child: Row(children: [
              Hero(tag: 'icon-${app.id}', child: AppIcon(app)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(app.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: C.gold,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                    ),
                    ValueListenableBuilder<List<UpdateInfo>>(
                      valueListenable: updateManager.available,
                      builder: (context, updates, _) {
                        if (!updates.any((u) => u.id == app.id)) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: C.purple,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('جديد',
                              style: TextStyle(color: C.gold, fontSize: 9)),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(app.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 5),
                  Text('${app.version}  •  ${app.size}',
                      style: const TextStyle(
                          fontSize: 11, color: C.purpleLight)),
                ]),
              ),
              const Icon(Icons.chevron_left, color: C.gold),
            ]),
          ),
        ),
      ),
    );
  }
}

class DetailsPage extends StatefulWidget {
  final AppItem app;
  const DetailsPage(this.app, {super.key});

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  late final UpdateInfo _update;
  List<CatalogReview> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _update = UpdateInfo(
      kind: UpdateKind.app,
      id: widget.app.id,
      title: widget.app.name,
      version: widget.app.version,
      url: widget.app.apkLink,
      notes: widget.app.changelog,
    );
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final local = updateManager.reviews?.load(widget.app.id) ??
        const <CatalogReview>[];
    final remote = await account.remoteReviews(widget.app.id);
    final remoteReviews = remote.map((r) {
      final rating = (r['rating'] is num
              ? (r['rating'] as num).toInt()
              : int.tryParse(r['rating'].toString()) ?? 5)
          .clamp(1, 5)
          .toInt();
      final created = (r['created_at'] ?? '').toString();
      return CatalogReview(
        author: (r['author'] ?? 'مستخدم').toString(),
        rating: rating,
        text: (r['text'] ?? '').toString(),
        date: created.length >= 10 ? created.substring(0, 10) : '',
      );
    }).toList();

    final all = <CatalogReview>[
      ...widget.app.reviews,
      ...local,
      ...remoteReviews,
    ];
    final seen = <String>{};
    final unique = all.where((r) {
      return seen.add('${r.author}|${r.rating}|${r.text}|${r.date}');
    }).toList();
    if (!mounted) return;
    setState(() => _reviews = unique);
  }

  Future<void> _download() async {
    if (!widget.app.hasApk) return;
    await updateManager.downloadUpdate(_update, install: true);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final hasUpdate =
        updateManager.available.value.any((u) => u.id == app.id);
    double avg = 0;
    if (_reviews.isNotEmpty) {
      avg = _reviews.fold<int>(0, (s, r) => s + r.rating) / _reviews.length;
    }

    return Scaffold(
      appBar: AppBar(title: Text(app.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(children: [
            Hero(tag: 'icon-${app.id}', child: AppIcon(app, size: 84)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.name,
                    style: const TextStyle(
                        color: C.gold,
                        fontSize: 23,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(app.tagline, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 7),
                Text('${app.category}  •  ${app.version}  •  ${app.size}',
                    style: const TextStyle(fontSize: 11, color: C.purpleLight)),
              ]),
            ),
          ]),
          const SizedBox(height: 22),
          ValueListenableBuilder<DownloadState?>(
            valueListenable: updateManager.active,
            builder: (context, s, _) {
              final mine = s != null && s.id == app.id;
              final busy = mine && !s.done && s.error == null;
              final done = mine && s.done;
              final label = !app.hasApk
                  ? 'قريبًا'
                  : busy
                      ? (s.progress < 0
                          ? 'جارٍ التنزيل...'
                          : '${((s.progress * 100).toInt())}%')
                      : done
                          ? 'تم التنزيل — اضغط للتثبيت'
                          : hasUpdate
                              ? 'تحديث متاح — تنزيل وتثبيت'
                              : 'تنزيل وتثبيت';
              return SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: C.gold,
                    foregroundColor: C.black,
                    disabledBackgroundColor: C.card,
                    disabledForegroundColor: C.goldSoft,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: busy || !app.hasApk
                      ? null
                      : done
                          ? () => updateManager.installDownloaded(app.id)
                          : _download,
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
          if (app.screenshotLinks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('لقطات الشاشة',
                style: const TextStyle(
                    color: C.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: app.screenshotLinks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _RemoteImage(app.screenshotLinks[i]),
              ),
            ),
          ],
          _section('عن التطبيق', app.description),
          if (app.changelog.isNotEmpty) _section('ما الجديد', app.changelog),
          const SizedBox(height: 24),
          Row(children: [
            const Expanded(
              child: Text('التقييمات والتعليقات',
                  style: TextStyle(
                      color: C.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              tooltip: 'أضف تقييمًا',
              onPressed: _showReviewDialog,
              icon: const Icon(Icons.add_comment_outlined, color: C.gold),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(avg.toStringAsFixed(1),
                    style: const TextStyle(
                        color: C.gold,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                _Stars(avg.round()),
                const SizedBox(width: 8),
                Text('${_reviews.length} تقييم',
                    style: const TextStyle(fontSize: 11, color: C.goldSoft)),
              ]),
              if (_reviews.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('كن أول من يقيّم هذا التطبيق.'),
                )
              else
                ..._reviews.map((r) => Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(r.author,
                                  style: const TextStyle(
                                      color: C.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              _Stars(r.rating, size: 13),
                            ]),
                            if (r.text.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(r.text, style: const TextStyle(fontSize: 12)),
                            ],
                          ]),
                    )),
            ]),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog() {
    final name = TextEditingController();
    final text = TextEditingController();
    int rating = 5;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: C.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: C.line)),
          title: const Text('أضف تقييمًا',
              style: TextStyle(color: C.gold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Stars(rating,
                  size: 26,
                  onTap: (v) => setLocal(() => rating = v)),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                style: const TextStyle(color: C.gold),
                decoration: InputDecoration(
                  hintText: 'الاسم (اختياري)',
                  hintStyle: const TextStyle(color: C.line),
                  filled: true,
                  fillColor: C.card,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: C.line)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: text,
                maxLines: 3,
                style: const TextStyle(color: C.gold),
                decoration: InputDecoration(
                  hintText: 'اكتب تعليقك...',
                  hintStyle: const TextStyle(color: C.line),
                  filled: true,
                  fillColor: C.card,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: C.line)),
                ),
              ),
              if (!account.signedIn)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'سجّل الدخول من تبويب «حسابي» لحفظ تقييمك للجميع.',
                    style: TextStyle(fontSize: 11, color: C.purpleLight),
                  ),
                ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: C.goldSoft)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: C.gold, foregroundColor: C.black),
              onPressed: () async {
                final now = DateTime.now().toIso8601String().substring(0, 10);
                final author =
                    name.text.trim().isEmpty ? 'مستخدم' : name.text.trim();
                final review = CatalogReview(
                  author: author,
                  rating: rating,
                  text: text.text.trim(),
                  date: now,
                );
                try {
                  if (account.signedIn) {
                    await account.addReview(
                      appId: widget.app.id,
                      author: author,
                      rating: rating,
                      text: review.text,
                    );
                  } else {
                    await updateManager.reviews?.add(widget.app.id, review);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تعذّر حفظ التقييم: $e')));
                  }
                  return;
                }
                if (context.mounted) Navigator.pop(context);
                await _loadReviews();
              },
              child: const Text('حفظ',
                  style: TextStyle(color: C.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: C.gold, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.line),
            ),
            child: Text(body, style: const TextStyle(height: 1.6)),
          ),
        ]),
      );
}

class _Stars extends StatelessWidget {
  final int rating;
  final double size;
  final ValueChanged<int>? onTap;

  const _Stars(this.rating, {this.size = 15, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final icon = Icon(
          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: C.gold,
          size: size,
        );
        if (onTap == null) return icon;
        return InkWell(onTap: () => onTap!(i + 1), child: icon);
      }),
    );
  }
}

class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key});
  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends State<UpdatesPage> {
  @override
  void initState() {
    super.initState();
    updateManager.check(download: false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<UpdateInfo>>(
      valueListenable: updateManager.available,
      builder: (context, updates, _) {
        return RefreshIndicator(
          color: C.gold,
          backgroundColor: C.card,
          onRefresh: () => updateManager.check(download: false),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              const Text('التحديثات',
                  style: TextStyle(
                      color: C.gold,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'يُفحص المتجر والتطبيقات المثبّتة عند التشغيل. التنزيل التلقائي يمكن إيقافه من الإعدادات.',
                style: TextStyle(fontSize: 12, height: 1.6, color: C.goldSoft),
              ),
              const SizedBox(height: 18),
              if (updates.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 50),
                  alignment: Alignment.center,
                  child: Column(children: [
                    Icon(Icons.verified_rounded,
                        size: 56, color: C.purpleLight),
                    const SizedBox(height: 12),
                    const Text('كل شيء محدّث'),
                  ]),
                )
              else
                ...updates.map((u) => _UpdateTile(u)),
            ],
          ),
        );
      },
    );
  }
}

class _UpdateTile extends StatelessWidget {
  final UpdateInfo u;
  const _UpdateTile(this.u);

  @override
  Widget build(BuildContext context) {
    final downloaded = updateManager.downloadedPath(u.id) != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.line),
      ),
      child: Row(children: [
        Icon(u.isStore ? Icons.system_update : Icons.apps,
            color: C.gold, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.title,
                style: const TextStyle(
                    color: C.gold, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text('الإصدار ${u.version}',
                style: const TextStyle(fontSize: 11, color: C.purpleLight)),
            const SizedBox(height: 3),
            Text(u.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: C.gold,
              foregroundColor: C.black,
              padding: const EdgeInsets.symmetric(horizontal: 12)),
          onPressed: () => downloaded
              ? updateManager.installDownloaded(u.id)
              : updateManager.downloadUpdate(u, install: true),
          child: Text(downloaded ? 'تثبيت' : 'تنزيل',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _master;
  late bool _store;
  late bool _apps;

  @override
  void initState() {
    super.initState();
    _master = updateManager.master;
    _store = updateManager.autoStore;
    _apps = updateManager.autoApps;
  }

  Future<void> _setMaster(bool v) async {
    await updateManager.setMaster(v);
    setState(() {
      _master = v;
      _store = updateManager.autoStore;
      _apps = updateManager.autoApps;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const Text('الإعدادات',
            style: TextStyle(
                color: C.gold, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: C.line),
          ),
          child: Column(children: [
            SwitchListTile(
              value: _master,
              onChanged: _setMaster,
              activeColor: C.gold,
              activeTrackColor: C.purple,
              title: const Text('التنزيل التلقائي للتحديثات',
                  style: TextStyle(color: C.gold)),
              subtitle: const Text('إيقاف هذه النقطة يلغي كل التحديثات التلقائية',
                  style: TextStyle(fontSize: 11, color: C.goldSoft)),
            ),
            const Divider(color: C.line, height: 1),
            SwitchListTile(
              value: _store,
              onChanged: _master
                  ? (v) async {
                      await updateManager.setAutoStore(v);
                      setState(() => _store = v);
                    }
                  : null,
              activeColor: C.gold,
              activeTrackColor: C.purple,
              title: const Text('تحديث المتجر نفسه',
                  style: TextStyle(color: C.gold)),
            ),
            const Divider(color: C.line, height: 1),
            SwitchListTile(
              value: _apps,
              onChanged: _master
                  ? (v) async {
                      await updateManager.setAutoApps(v);
                      setState(() => _apps = v);
                    }
                  : null,
              activeColor: C.gold,
              activeTrackColor: C.purple,
              title: const Text('تحديثات التطبيقات المثبّتة',
                  style: TextStyle(color: C.gold)),
            ),
          ]),
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
            onPressed: () async {
              await updateManager.check(download: updateManager.master);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(updateManager.lastMessage)),
                );
              }
            },
            child: const Text('فحص التحديثات الآن',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        Text('إصدار المتجر المثبّت: ${updateManager.currentVersion}',
            style: const TextStyle(fontSize: 12, color: C.goldSoft)),
        const SizedBox(height: 8),
        const Text(
          'عند بدء التنزيل يظهر شريط في أعلى الشاشة يمكنك منه الإلغاء أو المتابعة إلى التثبيت.',
          style: TextStyle(fontSize: 11, height: 1.6, color: C.purpleLight),
        ),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.asset('assets/logo.svg', width: 104, height: 104),
        const SizedBox(height: 16),
        const Text('روجا ستور',
            style: TextStyle(
                color: C.gold, fontSize: 27, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('الإصدار ${updateManager.currentVersion}',
            style: const TextStyle(color: C.goldSoft)),
        const SizedBox(height: 6),
        const Text('متجر تطبيقات خاص — أسود، بنفسجي وذهبي',
            style: TextStyle(fontSize: 11, color: C.purpleLight)),
      ]),
    );
  }
}
