import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/theme/app_theme.dart';
import 'data/services/phone_whatsapp_sync_service.dart';
import 'ui/views/phone_whatsapp_dashboard_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await [
      Permission.phone,
      Permission.notification,
      Permission.microphone,
      Permission.sms,
      Permission.contacts,
    ].request();
  } catch (_) {}

  runApp(const MobilePhoneWhatsAppApp());
}

class MobilePhoneWhatsAppApp extends StatelessWidget {
  const MobilePhoneWhatsAppApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PhoneWhatsAppSyncService>(
      create: (_) => PhoneWhatsAppSyncService(),
      child: MaterialApp(
        title: 'mobilePhoeWhtsapp - Communication Activity Sync',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const PhoneWhatsAppDashboardView(),
      ),
    );
  }
}
