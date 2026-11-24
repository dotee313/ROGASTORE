# روجا ستور

متجر تطبيقات Flutter بتصميم أسود / بنفسجي / ذهبي.

## المصدر الوحيد للبيانات

- `apps.json` في جذر المستودع العام هو الكتالوج الذي يقرأه التطبيق عبر:
  `https://raw.githubusercontent.com/dotee313/ROGASTORE/main/apps.json`
- `assets/apps.json` نسخة احتياطية تُستخدم فقط عند انقطاع الإنترنت. حدّث الاثنين معاً.

### حقول التطبيق

| الحقل | الوصف |
|---|---|
| `id` | معرّف فريد (يُستخدم أيضاً كاسم ملف التنزيل) |
| `name`, `tagline`, `description`, `category`, `version`, `size` | بيانات العرض |
| `iconUrl` | رابط كامل أو مسار داخل المستودع مثل `assets/logo_shg.svg`. يدعم SVG و PNG/JPG |
| `apkUrl` | **رابط تنزيل مباشر عام** (مثلاً رابط Releases). لا تستخدم روابط Actions artifacts |
| `packageName` | اسم حزمة أندرويد، ويُستخدم لمطابقة التطبيق المثبّت عند فحص التحديثات |
| `screenshots` | روابط صور PNG/JPG |
| `reviews` | تقييمات أولية اختيارية (`author`, `rating`, `text`, `date`) |

مثال على رابط APK صالح:
`https://github.com/d90f90y90-code/Shilagram/releases/download/latest/shilagram.apk`

## التحديثات التلقائية

- من تبويب **الإعدادات** يمكن إيقاف:
  - التنزيل التلقائي بالكامل.
  - تحديث المتجر نفسه فقط.
  - تحديثات التطبيقات المثبّتة فقط.
- أثناء أي تنزيل يظهر شريط أعلى الشاشة فيه **إلغاء** أو **تثبيت**.
- فحص المتجر نفسه يتم عبر `store_update.json`:

```json
{
  "version": "0.3.0",
  "apkUrl": "https://github.com/dotee313/ROGASTORE/releases/download/v0.3.0/app-release.apk",
  "notes": "تحسينات وتحديثات"
}
```

ارفع الرقم فقط عندما تنشر إصداراً حقيقياً؛ إذا كان `apkUrl` فارغاً فلن يحدث تنزيل.
عند دفع وسم `v0.3.0` يقوم workflow `release.yml` ببناء APK وإرفاقه بالإصدار تلقائياً.

## التقييمات والتعليقات

التقييمات المضافة من المستخدم تُحفظ محلياً على الجهاز (`shared_preferences`).
التقييمات الموجودة في `apps.json` تظهر كتقييمات أولية. لا يوجد خادم مشترك بعد.

## البناء

```bash
flutter pub get
flutter create --org com.roga --project-name roga_store --platforms android .
flutter build apk --release
```

مجلد `android/` يُولّد في GitHub Actions ولا يُرفع إلى المستودع.
أداة `librsvg2-bin` تستخدم لتحويل الشعار إلى أيقونة تشغيل قبل البناء.

## تنبيه أمني

إذا كنت قد شاركت توكن GitHub في محادثة أو ملف، قم بإبطاله فوراً من
`Settings → Developer settings → Personal access tokens`.
لا تضع التوكن في الكود أو في ملفات workflow؛ استخدم `GITHUB_TOKEN` الخاص بـ Actions.
