# دليل إنشاء برنامج التنصيب setup.exe لنظام ويندوز

لقد تم إعداد مشروع **Happy Day POS** لإنشاء ملف تنصيب احترافي لـ Windows بصيغة `setup.exe` (أو `HappyDayPOS_Setup.exe`).

---

## الطرق المتاحة لإنشاء ملف `setup.exe`

### الطريقة الأولى: التشغيل التلقائي على ويندوز (باستخدام `build_setup.bat`)
إذا كان لديك جهاز يعمل بنظام Windows مثبت عليه:
1. **Flutter SDK**
2. **Visual Studio** (مع تفعيل خيار Desktop development with C++)
3. **Inno Setup 6** (يمكن تحميله مجاناً من [موقع Inno Setup الرسمي](https://jrsoftware.org/isdl.php))

**الخطوات:**
1. افتح مجلد المشروع على Windows.
2. اضغط مرتين على الملف `build_setup.bat`.
3. سيقوم السكريبت تلقائياً بـ:
   - تحميل المكتبات (`flutter pub get`).
   - بناء النسخة النهائية للنظام (`flutter build windows --release`).
   - تحويل المخرجات لملف تنصيب وحفظه في: `installer\output\HappyDayPOS_Setup.exe`.

---

### الطريقة الثانية: عن طريق GitHub Actions (تلقائياً بدون الحاجة لنظام Windows)
بما أنك تستخدم جهاز Mac، يمكنك رفع المشروع على **GitHub** وحصولك على ملف `setup.exe` جاهز للتحميل مجاناً من خلال سيرفرات GitHub:

1. ارفع الكود إلى مستودع (Repository) على GitHub.
2. سيقوم ملف التشغيل التلقائي `.github/workflows/build_windows_setup.yml` بالعمل تلقائياً.
3. بعد انتهاء البناء، اذهب إلى تبويب **Actions** في GitHub واضغط على أحدث تشغيل (Workflow run).
4. ستجد ملف `HappyDayPOS_Setup_Windows` جاهزاً للتحميل، ويحتوي على `HappyDayPOS_Setup.exe`.

---

## مكونات ملفات التنصيب المضافة

- **[installer/setup_script.iss](file:///Users/nashwan/development/happy_day_pos/installer/setup_script.iss)**: سكريبت Inno Setup المخصص لتحزيم التطبيق وأيقونته والملفات التابعة له.
- **[build_setup.bat](file:///Users/nashwan/development/happy_day_pos/build_setup.bat)**: سكريبت الدفعة (Batch file) لبناء التطبيق وملف التنصيب بأمر واحد.
- **[.github/workflows/build_windows_setup.yml](file:///Users/nashwan/development/happy_day_pos/.github/workflows/build_windows_setup.yml)**: سكريبت البناء السحابي التلقائي عبر GitHub Actions.
