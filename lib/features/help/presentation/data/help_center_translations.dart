// ─── Help Center Translations (Phase 3 — predefined, static) ───────────────
// San3a's Help Center content is intentionally static (no Firestore, no
// backend translation call). This file holds hand-written Arabic and Hebrew
// translations for that fixed English copy, keyed by the same stable
// identifiers already used by the Help Center (UserRole, FaqItem.id). The
// English text always stays the source of truth and remains visible;
// translating only ever means looking up one of these maps.
//
// Not translated here (by design — matches the English source exactly):
// support email/phone, URLs, step numbers, and UserRole values and FaqItem
// ids themselves.
import '../../../../shared/models/models.dart';

/// The only two languages Help Center content can be translated into. San3a
/// stays English-only; this is strictly a content-comprehension aid.
enum HelpTranslationLanguage { ar, he }

/// A translated FAQ question/answer pair for one language.
class HelpFaqTranslation {
  final String question;
  final String answer;
  const HelpFaqTranslation({required this.question, required this.answer});
}

class HelpCenterTranslations {
  HelpCenterTranslations._();

  // ── About San3a — general description ──────────────────────────────────
  static const Map<HelpTranslationLanguage, String> aboutGeneral = {
    HelpTranslationLanguage.ar:
        'San3a هو منصة ذكية تربط العملاء بالمهنيين المحترفين والمقاولين '
            'المهرة لمجموعة واسعة من الخدمات المنزلية والتجارية.\n\n'
            'سواء كنت تحتاج إلى أعمال سباكة أو كهرباء أو نجارة أو طلاء أو أي '
            'خدمة أخرى، فإن San3a يجعل من السهل إيجاد مزودي خدمة موثوقين، '
            'وتقديم الطلبات، وتتبع التقدم، والتواصل في الوقت الفعلي.',
    HelpTranslationLanguage.he:
        'San3a היא פלטפורמה חכמה המקשרת בין לקוחות לבין אנשי מקצוע '
            'מוסמכים וקבלנים למגוון רחב של שירותי בית ועסקים.\n\n'
            'בין אם אתם צריכים אינסטלציה, עבודות חשמל, נגרות, צביעה, או כל '
            'שירות אחר — San3a מאפשרת למצוא בקלות נותני שירות אמינים, לבצע '
            'הזמנות, לעקוב אחר ההתקדמות ולתקשר בזמן אמת.',
  };

  // ── About San3a — role-specific summary (matches _AboutSection) ────────
  static const Map<UserRole, Map<HelpTranslationLanguage, String>>
      aboutRoleSummary = {
    UserRole.customer: {
      HelpTranslationLanguage.ar:
          'تصفح مزودي الخدمة، وأنشئ طلبات الخدمة وتتبعها، وتواصل مع مزودي '
              'الخدمة، وأدر المفضلة والتقييمات والشكاوى.',
      HelpTranslationLanguage.he:
          'עיינו בנותני השירות, צרו ועקבו אחר בקשות שירות, תקשרו עם נותני '
              'השירות, וניהלו את המועדפים, הביקורות והתלונות שלכם.',
    },
    UserRole.professional: {
      HelpTranslationLanguage.ar:
          'أدر ملفك الشخصي، وتخصصاتك، وخدماتك، وتوفرك، والطلبات الواردة، '
              'والتواصل مع العملاء، والتقييمات.',
      HelpTranslationLanguage.he:
          'ניהלו את הפרופיל, התחומים, השירותים, הזמינות, הבקשות הנכנסות, '
              'התקשורת עם הלקוחות והביקורות שלכם.',
    },
    UserRole.contractor: {
      HelpTranslationLanguage.ar:
          'أدر ملف شركتك، وخدماتك، والعمال، وتعيينات العمال، وطلبات '
              'الخدمة، والتواصل مع العملاء، والتقييمات.',
      HelpTranslationLanguage.he:
          'ניהלו את פרופיל החברה, השירותים, העובדים, שיבוצי העובדים, בקשות '
              'השירות, התקשורת עם הלקוחות והביקורות שלכם.',
    },
  };

  // ── How to Use — step titles, same order as _HowToUseSection._steps ────
  static const Map<UserRole, Map<HelpTranslationLanguage, List<String>>>
      howToSteps = {
    UserRole.customer: {
      HelpTranslationLanguage.ar: [
        'تصفح فئات الخدمات',
        'عرض المهنيين والمقاولين',
        'أضف مزودي الخدمة إلى المفضلة',
        'أنشئ طلبات خدمة',
        'تتبع طلباتك في الوقت الفعلي',
        'أرسل شكوى عند الحاجة',
        'تحدث مباشرة مع مزودي الخدمة',
      ],
      HelpTranslationLanguage.he: [
        'עיינו בקטגוריות השירותים',
        'צפו באנשי מקצוע ובקבלנים',
        'הוסיפו נותני שירות למועדפים',
        'צרו בקשות שירות',
        'עקבו אחר ההזמנות שלכם בזמן אמת',
        'שלחו תלונה במקרה הצורך',
        'שוחחו ישירות עם נותני השירות',
      ],
    },
    UserRole.professional: {
      HelpTranslationLanguage.ar: [
        'عرض وإدارة الطلبات الواردة',
        'قبول أو رفض الطلبات',
        'أدر الخدمات التي تقدمها',
        'عدّل ملفك الشخصي وتخصصاتك',
        'عرض تقييمات وآراء العملاء',
        'تحدث مع العملاء في أي وقت',
      ],
      HelpTranslationLanguage.he: [
        'צפו וניהלו את הבקשות הנכנסות',
        'אשרו או דחו בקשות',
        'ניהלו את השירותים שאתם מציעים',
        'ערכו את הפרופיל והתחומים שלכם',
        'צפו בביקורות ובדירוגים של הלקוחות',
        'שוחחו עם הלקוחות בכל עת',
      ],
    },
    UserRole.contractor: {
      HelpTranslationLanguage.ar: [
        'أدر وتتبع طلبات الخدمة',
        'أدر العمال والموردين',
        'تتبع الجداول والمواعيد الزمنية',
        'أدر الخدمات التي تقدمها',
        'عدّل ملفك الشخصي ومعلوماتك',
        'تحدث مع العملاء في أي وقت',
      ],
      HelpTranslationLanguage.he: [
        'ניהלו ועקבו אחר בקשות השירות',
        'ניהלו עובדים וספקים',
        'עקבו אחר לוחות זמנים ותזמונים',
        'ניהלו את השירותים שאתם מציעים',
        'ערכו את הפרופיל והמידע שלכם',
        'שוחחו עם הלקוחות בכל עת',
      ],
    },
  };

  // ── How to Use — role-specific summary box (matches provider defaults
  // for customerHelp/professionalHelp/contractorHelp) ────────────────────
  static const Map<UserRole, Map<HelpTranslationLanguage, String>>
      howToRoleSummary = {
    UserRole.customer: {
      HelpTranslationLanguage.ar: 'بصفتك عميلاً يمكنك:\n'
          '• تصفح فئات الخدمات وإيجاد المهنيين\n'
          '• إنشاء طلبات خدمة مع التفاصيل والصور\n'
          '• تتبع طلباتك في الوقت الفعلي\n'
          '• التحدث مباشرة مع مزودي الخدمة\n'
          '• إضافة مزودي الخدمة إلى المفضلة\n'
          '• تقديم شكوى عند الحاجة',
      HelpTranslationLanguage.he: 'בתור לקוח תוכלו:\n'
          '• לעיין בקטגוריות השירותים ולמצוא אנשי מקצוע\n'
          '• ליצור בקשות שירות עם פרטים ותמונות\n'
          '• לעקוב אחר ההזמנות שלכם בזמן אמת\n'
          '• לשוחח ישירות עם נותני השירות\n'
          '• להוסיף נותני שירות למועדפים\n'
          '• להגיש תלונה במקרה הצורך',
    },
    UserRole.professional: {
      HelpTranslationLanguage.ar: 'بصفتك محترفاً يمكنك:\n'
          '• عرض وإدارة طلبات الخدمة الواردة\n'
          '• قبول أو رفض الطلبات\n'
          '• إدارة خدماتك وأسعارها\n'
          '• تعديل ملفك الشخصي وتخصصاتك ومنطقة عملك\n'
          '• التحدث مع العملاء في أي وقت\n'
          '• عرض تقييماتك وآراء العملاء',
      HelpTranslationLanguage.he: 'בתור איש מקצוע תוכלו:\n'
          '• לצפות בבקשות השירות הנכנסות ולנהל אותן\n'
          '• לאשר או לדחות בקשות\n'
          '• לנהל את השירותים שלכם והתמחור שלהם\n'
          '• לערוך את הפרופיל, התחומים ואזור העבודה שלכם\n'
          '• לשוחח עם הלקוחות בכל עת\n'
          '• לצפות בדירוגים ובביקורות שלכם',
    },
    UserRole.contractor: {
      HelpTranslationLanguage.ar: 'بصفتك مقاولاً يمكنك:\n'
          '• إدارة وتتبع جميع طلبات الخدمة\n'
          '• إدارة فريق العمال الخاص بك\n'
          '• تتبع الجداول والمواعيد الزمنية للمشاريع\n'
          '• إدارة الخدمات التي تقدمها شركتك\n'
          '• التحدث مع العملاء في أي وقت\n'
          '• عرض ملف شركتك وتقييماتها',
      HelpTranslationLanguage.he: 'בתור קבלן תוכלו:\n'
          '• לנהל ולעקוב אחר כל בקשות השירות\n'
          '• לנהל את צוות העובדים שלכם\n'
          '• לעקוב אחר לוחות זמנים ותזמוני פרויקטים\n'
          '• לנהל את השירותים שהחברה שלכם מציעה\n'
          '• לשוחח עם הלקוחות בכל עת\n'
          '• לצפות בפרופיל החברה ובדירוגים שלה',
    },
  };

  // ── Quick Support FAQ — by stable FaqItem.id ────────────────────────────
  static const Map<String, Map<HelpTranslationLanguage, HelpFaqTranslation>>
      faq = {
    'f_common_profile': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أعدّل ملفي الشخصي؟',
        answer: 'افتح الملف الشخصي، واختر "تعديل الملف الشخصي"، وحدّث '
            'المعلومات المتاحة، ثم احفظ التغييرات.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני עורך את הפרופיל שלי?',
        answer: "פתחו את הפרופיל, בחרו ב'ערוך פרופיל', עדכנו את המידע "
            'הזמין, ולאחר מכן שמרו את השינויים.',
      ),
    },
    'f_common_complaint': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أرسل شكوى؟',
        answer: 'افتح "شكاواي"، وأنشئ شكوى جديدة، واختر السبب المناسب، '
            'وقدّم التفاصيل، ثم أرسلها.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני שולח תלונה?',
        answer: "פתחו את 'התלונות שלי', צרו תלונה חדשה, בחרו בסיבה "
            'המתאימה, מסרו את הפרטים, ושלחו אותה.',
      ),
    },
    'f_common_notifications': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف تعمل الإشعارات؟',
        answer: 'يعرض قسم الإشعارات التحديثات المهمة حول طلباتك وشكاواك '
            'وتقييماتك وطلبات الفئات وأي نشاط آخر ذو صلة بحسابك.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד פועלות ההתראות?',
        answer: 'בחלק ההתראות מוצגים עדכונים חשובים לגבי ההזמנות, '
            'התלונות, הביקורות, בקשות הקטגוריות ופעילות חשבון רלוונטית '
            'אחרת.',
      ),
    },
    'f_common_translate': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أترجم المحتوى المدعوم؟',
        answer: 'واجهة تطبيق San3a باللغة الإنجليزية فقط. قد يظهر في بعض '
            'المحتوى المدعوم إجراء ترجمة يمكنه عرضه بالعربية أو العبرية — '
            'وهذا لا يغيّر لغة واجهة التطبيق.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מתרגם תוכן נתמך?',
        answer: 'מנשק האפליקציה San3a הוא באנגלית בלבד. בתוכן נתמך מסוים '
            'עשויה להופיע אפשרות תרגום שמציגה אותו בערבית או בעברית — '
            'הדבר אינו משנה את שפת המנשק של האפליקציה.',
      ),
    },
    'f_customer_request': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أنشئ طلب خدمة؟',
        answer: 'تصفح الفئات أو مزودي الخدمة، أو استخدم مسار الطلب '
            'المتاح، ثم اختر الخدمات التي تحتاجها، وأدخل التفاصيل '
            'والمنطقة والتاريخ المفضل، ثم أرسل طلبك.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני יוצר בקשת שירות?',
        answer: 'עיינו בקטגוריות או בנותני השירות, או השתמשו בתהליך '
            'הבקשה הזמין, ואז בחרו את השירותים הדרושים לכם, הזינו את '
            'הפרטים, האזור והתאריך המועדף, ושלחו את הבקשה.',
      ),
    },
    'f_customer_edit_cancel': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أعدّل أو ألغي طلباً؟',
        answer: 'افتح الطلب من قائمة طلباتك. تعتمد الإجراءات المتاحة '
            'لتعديله أو إلغائه على الحالة الحالية للطلب.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני עורך או מבטל הזמנה?',
        answer: 'פתחו את ההזמנה מרשימת ההזמנות שלכם. הפעולות הזמינות '
            'לעריכה או לביטול תלויות בסטטוס הנוכחי של ההזמנה.',
      ),
    },
    'f_customer_contact': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أتواصل مع مزود خدمة؟',
        answer: 'افتح الملف الشخصي لمزود الخدمة، أو طلباً نشطاً أو '
            'محادثة، واستخدم إجراء الدردشة أو الاتصال المتاح.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מתקשר עם נותן שירות?',
        answer: 'פתחו את הפרופיל של נותן השירות, או הזמנה פעילה או שיחה, '
            'והשתמשו באפשרות הצ\'אט או השיחה הזמינה.',
      ),
    },
    'f_customer_favorites': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أضيف مزود خدمة إلى المفضلة؟',
        answer: 'استخدم إجراء المفضلة على بطاقة أو ملف مزود الخدمة '
            'المدعوم لإضافته إلى المفضلة أو إزالته منها.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מוסיף נותן שירות למועדפים?',
        answer: 'השתמשו באפשרות המועדפים בכרטיס או בפרופיל של נותן '
            'השירות הנתמך כדי להוסיף או להסיר אותו מהמועדפים שלכם.',
      ),
    },
    'f_customer_review': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أترك تقييماً؟',
        answer: 'التقييمات متاحة من خلال مسار الخدمة المكتملة أو مسار '
            'مزود الخدمة، حيث يكون ذلك مدعوماً.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני משאיר ביקורת?',
        answer: 'ביקורות זמינות בתהליך השירות המושלם או בתהליך נותן '
            'השירות, במקומות שבהם הדבר נתמך.',
      ),
    },
    'f_professional_services': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أدير خدماتي وأسعاري؟',
        answer: 'افتح ملفك الشخصي واستخدم قسم الخدمات لإضافة الخدمات '
            'التي تقدمها أو تعديلها أو إزالتها وتحديد أسعارها.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מנהל את השירותים והמחירים שלי?',
        answer: 'פתחו את הפרופיל שלכם והשתמשו בחלק השירותים כדי להוסיף, '
            'לערוך או להסיר שירותים שאתם מציעים ולקבוע את מחיריהם.',
      ),
    },
    'f_professional_specialties': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أحدّث تخصصاتي ومنطقة عملي؟',
        answer: 'افتح الملف الشخصي ← تعديل الملف الشخصي لتحديث تخصصاتك '
            'ومنطقة عملك.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מעדכן את התחומים ואזור העבודה שלי?',
        answer: 'פתחו פרופיל ← ערוך פרופיל כדי לעדכן את התחומים ואזור '
            'העבודה שלכם.',
      ),
    },
    'f_professional_availability': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أحدد توفري وساعات عملي؟',
        answer: 'افتح الملف الشخصي ← تعديل الملف الشخصي لتحديد أيام '
            'وساعات عملك.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני קובע את הזמינות ושעות העבודה שלי?',
        answer: 'פתחו פרופיל ← ערוך פרופיל כדי לקבוע את ימי ושעות '
            'העבודה שלכם.',
      ),
    },
    'f_professional_accept': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أقبل أو أرفض طلب خدمة؟',
        answer: 'افتح الطلب من قائمة طلباتك واستخدم إجراء القبول أو '
            'الرفض الظاهر للطلبات المعلقة.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מאשר או דוחה בקשת שירות?',
        answer: 'פתחו את הבקשה מרשימת ההזמנות שלכם והשתמשו באפשרות '
            'אישור או דחייה המוצגת לבקשות בהמתנה.',
      ),
    },
    'f_professional_complete': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أكمل طلباً؟',
        answer: 'افتح الطلب الجاري تنفيذه واستخدم إجراء الإكمال بعد '
            'انتهاء العمل.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני משלים הזמנה?',
        answer: 'פתחו את ההזמנה שבתהליך והשתמשו באפשרות ההשלמה לאחר '
            'סיום העבודה.',
      ),
    },
    'f_professional_chat': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أتواصل مع عميل؟',
        answer: 'استخدم إجراء الدردشة على الطلب لإرسال رسالة مباشرة إلى '
            'العميل.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מתקשר עם לקוח?',
        answer: 'השתמשו באפשרות הצ\'אט בהזמנה כדי לשלוח הודעה ישירה '
            'ללקוח.',
      ),
    },
    'f_contractor_worker_add': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أضيف أو أعدّل عاملاً؟',
        answer: 'افتح قسم العمال من الملف الشخصي لإضافة عامل جديد أو '
            'تعديل تفاصيل عامل موجود.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מוסיף או עורך עובד?',
        answer: 'פתחו את חלק העובדים מהפרופיל כדי להוסיף עובד חדש או '
            'לערוך פרטים של עובד קיים.',
      ),
    },
    'f_contractor_worker_assign': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أعيّن عمالاً لطلب؟',
        answer: 'افتح تفاصيل الطلب واستخدم إجراء تعيين العمال لتعيين '
            'عامل واحد أو أكثر له.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני משבץ עובדים להזמנה?',
        answer: 'פתחו את פרטי ההזמנה והשתמשו באפשרות שיבוץ העובדים כדי '
            'לשבץ לה עובד אחד או יותר.',
      ),
    },
    'f_contractor_worker_missing': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'لماذا لا يظهر عامل في قائمة التعيين؟',
        answer: 'تُصفَّى قائمة التعيين لتشمل فقط العمال الذين تتطابق '
            'تخصصاتهم مع التخصصات التي تتطلبها الخدمات المحددة في الطلب.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'מדוע עובד אינו מופיע ברשימת השיבוץ?',
        answer: 'רשימת השיבוץ מסוננת לעובדים שהתחומים שלהם תואמים '
            'לתחומים הנדרשים על ידי השירותים שנבחרו בהזמנה.',
      ),
    },
    'f_contractor_worker_change': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أغيّر العمال خلال طلب قيد التنفيذ؟',
        answer: 'افتح تفاصيل الطلب وحدّث تعيين العمال لتبديل العمال أو '
            'إزالتهم حسب الحاجة.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מחליף עובדים במהלך הזמנה בתהליך?',
        answer: 'פתחו את פרטי ההזמנה ועדכנו את שיבוץ העובדים כדי להחליף '
            'או להסיר עובדים לפי הצורך.',
      ),
    },
    'f_contractor_return_pending': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أعيد طلباً إلى حالة معلق؟',
        answer: 'افتح تفاصيل الطلب واستخدم "إلغاء تعيين الجميع والإرجاع '
            'إلى معلق" لإلغاء تعيين جميع العمال وإرجاع الطلب إلى حالة '
            'معلق.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מחזיר הזמנה למצב בהמתנה?',
        answer: "פתחו את פרטי ההזמנה והשתמשו ב'בטל שיבוץ לכולם והחזר "
            "להמתנה' כדי לבטל את שיבוץ כל העובדים ולהחזיר את ההזמנה "
            'למצב בהמתנה.',
      ),
    },
    'f_contractor_services': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أدير خدمات وتخصصات شركتي؟',
        answer: 'افتح ملفك الشخصي لإدارة الخدمات والتخصصات التي تقدمها '
            'شركتك.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מנהל את שירותי החברה והתחומים שלה?',
        answer: 'פתחו את הפרופיל שלכם כדי לנהל את השירותים והתחומים '
            'שהחברה שלכם מציעה.',
      ),
    },
    'f_contractor_chat': {
      HelpTranslationLanguage.ar: HelpFaqTranslation(
        question: 'كيف أتواصل مع عميل؟',
        answer: 'استخدم إجراء الدردشة على الطلب لإرسال رسالة مباشرة إلى '
            'العميل.',
      ),
      HelpTranslationLanguage.he: HelpFaqTranslation(
        question: 'כיצד אני מתקשר עם לקוח?',
        answer: 'השתמשו באפשרות הצ\'אט בהזמנה כדי לשלוח הודעה ישירה '
            'ללקוח.',
      ),
    },
  };

  // ── Smart Features — AI Service Assistant (shown to Customer only, matches
  // _SmartFeaturesSection._aiAssistantBody) ───────────────────────────────
  static const Map<HelpTranslationLanguage, String> smartAiAssistant = {
    HelpTranslationLanguage.ar:
        'يساعدك مساعد الخدمة الذكي (AI) على إيجاد فئة الخدمة المناسبة '
            'ومزودي الخدمة بشكل أسرع.\n\n'
            'من خلاله يمكنك:\n'
            '• وصف مشكلة الخدمة التي تواجهها بأسلوبك الخاص\n'
            '• الحصول على فئة خدمة مقترحة مع سبب واضح لهذا الاقتراح\n'
            '• تحسين النتيجة مرة واحدة عبر الإجابة عن بعض الأسئلة '
            'الإضافية عند ظهورها\n'
            '• اختيار تفضيل مزود الخدمة: كلاهما، محترف، أو مقاول\n'
            '• اختيار تفضيل الموقع: أي موقع أو نفس المدينة\n'
            '• اختيار تفضيل الميزانية: أي ميزانية أو ميزانية محددة\n'
            '• إضافة ملاحظات إضافية اختيارية حول طلبك\n'
            '• رؤية مزودي خدمة حقيقيين مطابقين بناءً على المعايير التي '
            'اخترتها\n'
            '• فتح الملف الشخصي لأحد مزودي الخدمة المقترحين لمعرفة المزيد\n'
            '• المتابعة لإنشاء طلب خدمة مباشرة من مزود خدمة مقترح\n\n'
            'لا يقوم الاقتراح الذكي أبداً بإنشاء أو إرسال طلب تلقائياً. '
            'عليك دائماً مراجعة النتيجة، واختيار مزود الخدمة، وإكمال '
            'تفاصيل الطلب، ثم إرساله بنفسك.\n\n'
            'قد لا تكون الاقتراحات مثالية دائماً، لذا يُرجى التحقق من '
            'الفئة ومزود الخدمة المقترحين قبل المتابعة.',
    HelpTranslationLanguage.he:
        'עוזר שירות ה-AI עוזר לכם למצוא את קטגוריית השירות ואת נותני '
            'השירות המתאימים במהירות רבה יותר.\n\n'
            'באמצעותו תוכלו:\n'
            '• לתאר את בעיית השירות שלכם במילים שלכם\n'
            '• לקבל קטגוריית שירות מוצעת עם הסבר ברור לבחירה זו\n'
            '• לשפר את התוצאה פעם אחת על ידי מענה על כמה שאלות המשך, '
            'כאשר הן מוצגות\n'
            '• לבחור העדפת נותן שירות: שניהם, איש מקצוע, או קבלן\n'
            '• לבחור העדפת מיקום: כל מיקום או אותה עיר\n'
            '• לבחור העדפת תקציב: כל תקציב או תקציב מסוים\n'
            '• להוסיף הערות נוספות אופציונליות לבקשה שלכם\n'
            '• לראות נותני שירות אמיתיים המתאימים לפי הקריטריונים '
            'שבחרתם\n'
            '• לפתוח את הפרופיל של נותן שירות מוצע כדי ללמוד עוד\n'
            '• להמשיך ליצירת בקשת שירות ישירות מנותן שירות מוצע\n\n'
            'ההצעה החכמה אינה יוצרת או שולחת הזמנה באופן אוטומטי לעולם. '
            'עליכם תמיד לבדוק את התוצאה, לבחור נותן שירות, להשלים את '
            'פרטי הבקשה, ולשלוח אותה בעצמכם.\n\n'
            'ההצעות לא תמיד מושלמות, לכן יש לוודא את הקטגוריה ונותן '
            'השירות המוצעים לפני שממשיכים.',
  };

  // ── Smart Features — Content Translation (shown to Customer, Professional
  // and Contractor, matches _SmartFeaturesSection._translationBody) ──────
  static const Map<HelpTranslationLanguage, String> smartContentTranslation = {
    HelpTranslationLanguage.ar:
        'واجهة تطبيق San3a باللغة الإنجليزية فقط حالياً.\n\n'
            'قد يظهر في بعض المحتوى المدعوم — مثل بعض النصوص التي '
            'ينشئها المستخدمون أو النصوص التعريفية — إجراء ترجمة. '
            'وحيثما يكون متاحاً، يمكنك:\n'
            '• اختيار العربية أو العبرية لذلك المحتوى\n'
            '• الاستمرار في رؤية النص الإنجليزي الأصلي في الوقت نفسه\n'
            '• عرض النص المترجم في قسم منفصل أسفله\n'
            '• استخدام "إخفاء الترجمة" للعودة إلى عرض النص الأصلي فقط\n\n'
            'تتوقف إمكانية الترجمة على الصفحة أو المحتوى المحدد — فليس '
            'كل نص في التطبيق يحتوي على إجراء ترجمة. استخدام هذه الميزة '
            'لا يغيّر أبداً لغة واجهة التطبيق بشكل عام.',
    HelpTranslationLanguage.he:
        'מנשק אפליקציית San3a הוא כרגע באנגלית בלבד.\n\n'
            'בתוכן נתמך מסוים — כגון טקסט מסוים שנוצר על ידי משתמשים או '
            'טקסט מידע — עשויה להופיע אפשרות תרגום. במקומות שבהם היא '
            'זמינה, תוכלו:\n'
            '• לבחור ערבית או עברית עבור אותו תוכן\n'
            '• להמשיך לראות את הטקסט האנגלי המקורי במקביל\n'
            '• לצפות בטקסט המתורגם בחלק נפרד מתחתיו\n'
            '• להשתמש ב\'הסתר תרגום\' כדי לחזור לתצוגת המקור בלבד\n\n'
            'זמינות התרגום תלויה במסך או בתוכן הספציפי — לא בכל טקסט '
            'באפליקציה קיימת אפשרות תרגום. השימוש בה אינו משנה לעולם את '
            'שפת מנשק האפליקציה הכללית.',
  };
}
