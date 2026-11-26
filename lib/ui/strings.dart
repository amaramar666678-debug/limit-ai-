import 'package:flutter/foundation.dart';

/// Lightweight localization for the app UI. English is the default language;
/// Arabic can be selected from Settings.
class AppStrings {
  AppStrings._();

  /// Current language code: `en` (default) or `ar`.
  static final ValueNotifier<String> locale = ValueNotifier<String>('en');

  static bool get isArabic => locale.value == 'ar';
  static String get languageName => isArabic ? 'العربية' : 'English';

  static void setLocale(String code) {
    if (code == 'en' || code == 'ar') locale.value = code;
  }

  static void toggle() => setLocale(isArabic ? 'en' : 'ar');

  static String t(String english, String arabic) => isArabic ? arabic : english;

  // Navigation & common
  static String get chat => t('Chat', 'المحادثة');
  static String get multiMause => 'Multi Mause';
  static String get stop => t('Stop', 'إيقاف');
  static String get cancel => t('Cancel', 'إلغاء');
  static String get delete => t('Delete', 'حذف');
  static String get settings => t('Settings', 'الإعدادات');
  static String get chooseModel => t('Choose model', 'اختر النموذج');
  static String get language => t('Language', 'اللغة');
  static String get escNote => t(
        'Press Esc to stop instantly during execution.',
        'اضغط Esc للإيقاف الفوري أثناء التنفيذ.',
      );

  // Session deletion
  static String get deleteChatTitle => t('Delete conversation?', 'حذف المحادثة؟');
  static String get deleteSessionTitle => t('Delete session?', 'حذف الجلسة؟');
  static String deleteChatBody(String title) => t(
        '«$title» will be deleted from OpenCode. This cannot be undone.',
        'سيتم حذف «$title» من OpenCode. لا يمكن التراجع.',
      );
  static String deleteSessionBody(String title) => t(
        '«$title» will be permanently deleted from OpenCode.',
        'سيتم حذف «$title» نهائياً من OpenCode.',
      );
  static String get deleteChatTooltip => t('Delete conversation', 'حذف المحادثة');
  static String get deleteSessionTooltip => t('Delete session', 'حذف الجلسة');

  // Empty state ideas
  static String get ideaReview => t('Review the project and explain its structure', 'راجع المشروع واشرح هيكله');
  static String get ideaFix => 'Fix bugs and run tests';
  static String get ideaTask => t('Run a task in the current project', 'نفّذ مهمة في المشروع الحالي');

  // Multi Mause — header & status
  static String get mouseSubtitle => t(
        'Ten cursors perform real clicks at different positions at high speed',
        'عشرة مؤشرات تنفّذ النقرات في مواضع مختلفة بسرعة فائقة',
      );
  static String get notSupported => t('Unsupported', 'غير مدعوم');
  static String get windowsReady => t('Windows ready', 'Windows جاهز');
  static String get tenCursors => '10 cursors';

  // Preview & precision
  static String get preview => t('Preview', 'المعاينة');
  static String get previewPaused => t('Preview paused', 'المعاينة متوقفة');
  static String get locatingPointer => t('Locating pointer...', 'جارٍ تحديد موضع المؤشر...');
  static String position(num x, num y) => t(
        'Position: ${x.round()} × ${y.round()}',
        'الموضع: ${x.round()} × ${y.round()}',
      );
  static String get capturePointer => t('Capture pointer', 'التقاط المؤشر');
  static String get preciseControl => t('Precise control:', 'تحكم دقيق:');
  static String get move => t('Move', 'نقل');
  static String get click => t('Click', 'نقر');
  static String get invalidCoords => t(
        'Enter X and Y as whole numbers.',
        'أدخل إحداثيات X و Y كأرقام صحيحة.',
      );

  // Controls
  static String get pattern => t('Pattern', 'النمط');
  static String get spacing => t('Spacing', 'المسافة');
  static String get clickInterval => t('Interval between clicks', 'الفاصل بين النقرات');
  static String get doubleClick => t('Double click', 'نقر مزدوج');
  static String get realClicksNote => t(
        'Real clicks are sent to the desktop. Press Esc or Stop at any time.',
        'تنفّذ نقرات حقيقية على سطح المكتب. اضغط Esc أو زر الإيقاف في أي وقت.',
      );
  static String startingIn(int n) => t('Start in $n', 'البدء بعد $n');
  static String get executing => t('Executing...', 'جارٍ التنفيذ...');
  static String get runTenClicks => t('Run 10 clicks', 'تشغيل 10 نقرات');
  static String get patternRow => t('Row', 'أفقي');
  static String get patternColumn => t('Column', 'عمودي');
  static String get patternGrid => t('5×2 grid', 'شبكة 5×2');
  static String get patternCircle => t('Circle', 'دائرة');
  static String get patternDiagonal => t('Diagonal', 'قطري');

  // AI team control
  static String get aiTeamControl => t('Agent team control', 'التحكم الجماعي بالوكيل');
  static String get teamOfTen => t('Team of 10', 'فريق من 10');
  static String get aiTeamDescription => t(
        'Describe a task — e.g. "open Chrome and search for cat images" or "play agar.io" — and it is sent to the agent while the ten-cursor team carries it out on the desktop.',
        'اكتب المهمة للوكيل — مثلاً: «افتح كروم وابحث عن صور قطط» أو «العب لعبة agar.io» — فيرسلها إلى الوكيل ويبدأ الفريق بتنفيذها على سطح المكتب.',
      );
  static String get aiTaskHint => t(
        'Type a command, e.g. open Chrome and search for cat images',
        'اكتب أمراً، مثلاً: افتح كروم وابحث عن صور قطط',
      );
  static String get pressEnterToStart => t(
        'The team starts when you press Enter (Shift+Enter adds a line).',
        'يبدأ الفريق عند الضغط على Enter (وShift+Enter لإضافة سطر).',
      );
  static String cursorProgress(int i) => t('Cursor ${i + 1}/10', 'المؤشر ${i + 1}/10');
  static String get teamWorking => t('Team working...', 'الفريق يعمل...');
  static String get runTeam => t('Send to agent & run team', 'أرسل للوكيل وشغّل الفريق');

  // Mouse task labels
  static String get launchChrome => t('Open Chrome and load page', 'فتح كروم وتحميل الصفحة');
  static String get waitResults => t('Waiting for results', 'انتظار جاهزية النتائج');
  static String checkImage(int i) => t('Check image $i', 'فحص الصورة $i');
  static String checkResult(int i) => t('Check result $i', 'فحص النتيجة $i');
  static String get imageSearch => t('Team image search', 'بحث جماعي عن صور');
  static String get infoSearch => t('Team info search', 'بحث جماعي عن معلومات');
  static String imagesLabel(String q) => t('Images: $q', 'صور: $q');
  static String infoLabel(String q) => t('Info: $q', 'معلومات: $q');
  static String get teamClicks => t('Team run with 10 cursors', 'تنفيذ جماعي بـ 10 مؤشرات');

  // Mouse-driven games
  static String get agarGame => t('Agar.io steer', 'تحكّم بلعبة Agar.io');
  static String get agarDescription => t(
        'Opens agar.io, starts a round, then plays with human-like mouse moves and occasional clicks. Press Esc to stop.',
        'يفتح agar.io، يبدأ الجولة، ثم يلعب بحركات ماوس تشبه الإنسان مع نقرات متفرقة. اضغط Esc للإيقاف.',
      );
  static String get launchAgar => t('Open agar.io', 'فتح agar.io');
  static String get clickPlay => t('Click Play', 'الضغط على Play');
  static String get focusGame => t('Focus game canvas', 'تفعيل ساحة اللعب');
  static String get steerCell => t('Steering cell - Esc to stop', 'توجيه الخلية - Esc للإيقاف');
  static String get playingHuman => t('Playing like a human - Esc to stop', 'يلعب مثل الإنسان - Esc للإيقاف');

  // Task status
  static String get taskFinished => t('Task finished', 'انتهت المهمة');
  static String get taskStopped => t('Task stopped', 'تم إيقاف المهمة');
  static String get cursorsActive => t('10 cursors active', '10 مؤشرات نشطة');
  static String clickDescription(bool doubleClick) => t(
        'Real ${doubleClick ? 'double ' : ''}clicks using the selected pattern',
        'نقرات ${doubleClick ? 'مزدوجة' : 'عادية'} حقيقية حسب النمط المختار',
      );
  static String cursorLabel(int i) => t('Cursor $i', 'المؤشر $i');
}
