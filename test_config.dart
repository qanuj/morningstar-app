// Quick test to verify API configuration
import 'lib/config/app_config.dart';

void main() {
  print('🔧 App Configuration Test');
  print('Environment: ${AppConfig.isProduction ? "Production" : "Development"}');
  print('API Base URL: ${AppConfig.apiBaseUrl}');
  print('Expected Production URL: https://duggy.app/api');
  
  if (AppConfig.isProduction && AppConfig.apiBaseUrl == 'https://duggy.app/api') {
    print('✅ Production configuration is correct!');
  } else if (!AppConfig.isProduction && AppConfig.apiBaseUrl.contains('192.168')) {
    print('✅ Development configuration is correct!');
  } else {
    print('❌ Configuration mismatch detected!');
  }
}