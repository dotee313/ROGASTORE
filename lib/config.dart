/// الإعدادات العامة. لا توجد أي أسرار هنا: مفتاح Supabase anonymity
/// عام بالتصميم، ويُمرّر عبر --dart-define من GitHub Secrets أثناء البناء.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const String allowedEmailDomain = 'fatimiyoun.me';

bool get backendReady =>
    supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

bool isAllowedEmail(String value) =>
    value.trim().toLowerCase().endsWith('@$allowedEmailDomain');
