# روجا ستور

متجر تطبيقات Flutter بتصميم أسود / بنفسجي / ذهبي.

## المصدر الوحيد للبيانات

- عند تفعيل Supabase يقرأ التطبيق جدول `apps` أولاً (وهو ما تعدّله لوحة الأدمن).
- بدون Supabase (أو عند تعذّر الاتصال) يقرأ `apps.json` في جذر المستودع العام عبر:
  `https://raw.githubusercontent.com/dotee313/ROGASTORE/main/apps.json`
- `assets/apps.json` نسخة احتياطية أخيرة تُستخدم عند انقطاع الإنترنت. حدّث الاثنين معاً.

### حقول التطبيق

| الحقل | الوصف |
|---|---|
| `id` | معرّف فريد (يُستخدم أيضاً كاسم ملف التنزيل) |
| `name`, `tagline`, `description`, `category`, `version`, `size` | بيانات العرض |
| `iconUrl` | رابط كامل أو مسار داخل المستودع مثل `assets/logo_shg.svg`. يدعم SVG و PNG/JPG |
| `apkUrl` | **رابط تنزيل مباشر عام** (مثلاً رابط Releases). لا تستخدم روابط Actions artifacts |
| `packageName` | اسم حزمة أندرويد، ويُستخدم لمطابقة التطبيق المثبّت عند فحص التحديثات |
| `screenshots` | روابط صور PNG/JPG أو مسارات نسبية مثل `screenshots/shilagram/01.jpg` (تُحلّ تلقائياً إلى raw المستودع). الصور الحالية مخزّنة في مجلد `screenshots/` |
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
  "version": "0.4.1",
  "apkUrl": "https://github.com/dotee313/ROGASTORE/releases/download/v0.4.1/app-release.apk",
  "notes": "تحسينات وتحديثات"
}
```

ارفع الرقم فقط عندما تنشر إصداراً حقيقياً؛ إذا كان `apkUrl` فارغاً فلن يحدث تنزيل.
عند دفع وسم `v0.4.1` يقوم workflow `release.yml` ببناء APK وإرفاقه بالإصدار تلقائياً.

الإصدار الحالي المفعّل للتحديث الذاتي هو `v0.4.1`، ورابطه المباشر:
`https://github.com/dotee313/ROGASTORE/releases/download/v0.4.1/app-release.apk`
عند نشر إصدار جديد: حدّث `version` و`apkUrl` في هذا الملف، ثم ادفع وسم الإصدار.

## التقييمات والتعليقات

- التقييمات الأولية تأتي من `apps.json`.
- المستخدم غير المسجّل تُحفظ تقييماته محلياً على الجهاز (`shared_preferences`).
- المستخدم المسجّل تُحفظ تقييماته في جدول `reviews` على Supabase فتظهر للجميع، ويمكن للأدمن حذفها من لوحة المطوّر.

## الحسابات وصلاحيات الأدمن (Supabase)

المخطط الكامل موجود في `supabase/schema.sql`. نفّذه من SQL Editor في مشروع Supabase، ثم:

1. افتح `Authentication → Email Templates → Magic Link` واستبدل `{{ .ConfirmationURL }}` بـ `{{ .Token }}`. بهذا يُرسَل للمستخدم رمز من ٦ أرقام بدل رابط التفعيل.
2. سجّل الدخول من تبويب **حسابي** بإيميل `@fatimiyoun.me` (التسجيل مفتوح لهذا النطاق فقط، ويُمنع أي نطاق آخر على مستوى الخادم)، ثم أدخل الرمز المرسل.
3. امنح نفسك صلاحية الأدمن من SQL Editor:

   ```sql
   update public.profiles set role = 'admin'
   where lower(email) = 'yourname@fatimiyoun.me';
   ```

4. أضف السرّين التاليين في `Settings → Secrets and variables → Actions` للمستودع:

   | الاسم | القيمة |
   |---|---|
   | `SUPABASE_URL` | رابط المشروع مثل `https://xxxx.supabase.co` |
   | `SUPABASE_ANON_KEY` | مفتاح `anon` العام من `Project Settings → API` |

5. أعد تشغيل workflow `Build APK` أو ادفع وسم إصدار جديد.

التبويب **حسابي** يظهر فقط رسالة "الحسابات غير مفعّلة لهذا البناء" إذا لم تُضف السرّين.

### لماذا لا يوجد "حساب أدمن سري" داخل التطبيق؟

أي كلمة مرور أو مفتاح تُخبّأ داخل APK يمكن استخراجه بفك التطبيق. لذلك:

- صلاحية الأدمن هي **دور في قاعدة البيانات** (`profiles.role = 'admin'`) يمنحه الخادم.
- التطبيق يسأل الخادم: هل هذا المستخدم أدمن؟ ولا يقرر بنفسه.
- كل عمليات الرفع والتعديل والحذف تتحقق من الصلاحية عبر سياسات RLS على الخادم.
- `anon key` عام بالتصميم؛ الحماية الحقيقية هي RLS، وليس إخفاء المفتاح.
- فعّل 2FA لحسابك من Supabase Auth.

من لوحة المطوّر داخل التطبيق يستطيع الأدمن: تعديل الكتالوج، رفع APK إلى Storage، إدارة المستخدمين ومنح الصلاحيات، وحذف التقييمات.

## البناء

```bash
flutter pub get
flutter create --org com.roga --project-name roga_store --platforms android .
flutter build apk --release \
  --dart-define=SUPABASE_URL="https://xxxx.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="anon-key"
```

في GitHub Actions تُمرَّر القيم تلقائياً من Secrets؛ لا تكتبها في الكود أو المستودع.

مجلد `android/` يُولّد في GitHub Actions ولا يُرفع إلى المستودع.
أداة `librsvg2-bin` تستخدم لتحويل الشعار إلى أيقونة تشغيل قبل البناء.

## تنبيه أمني

إذا كنت قد شاركت توكن GitHub في محادثة أو ملف، قم بإبطاله فوراً من
`Settings → Developer settings → Personal access tokens`.
لا تضع التوكن في الكود أو في ملفات workflow؛ استخدم `GITHUB_TOKEN` الخاص بـ Actions.
