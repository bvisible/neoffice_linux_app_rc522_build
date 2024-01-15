import 'package:flutter/material.dart';
import 'package:neoffice_linux_app_rc522/services/api_provider.dart';
import 'package:neoffice_linux_app_rc522/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:desktop_window/desktop_window.dart';
import 'package:fast_cached_network_image/fast_cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:neoffice_linux_app_rc522/services/checkin_orout_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopWindow.setFullScreen(true);

  String storageLocation = (await getApplicationDocumentsDirectory()).path;
  await FastCachedImageConfig.init(subDir: storageLocation, clearCacheAfter: const Duration(days: 1));

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiProvider>(create: (_) => ApiProvider()),
        ChangeNotifierProvider<CheckinOroutService>(
          create: (context) => CheckinOroutService(apiProvider: Provider.of<ApiProvider>(context, listen: false)),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  Map<int, Color> color = {
    50: Color.fromRGBO(16, 98, 254, .1),
    100: Color.fromRGBO(16, 98, 254, .2),
    200: Color.fromRGBO(16, 98, 254, .3),
    300: Color.fromRGBO(16, 98, 254, .4),
    400: Color.fromRGBO(16, 98, 254, .5),
    500: Color.fromRGBO(16, 98, 254, .6),
    600: Color.fromRGBO(16, 98, 254, .7),
    700: Color.fromRGBO(16, 98, 254, .8),
    800: Color.fromRGBO(16, 98, 254, .9),
    900: Color.fromRGBO(16, 98, 254, 1),
  };

  @override
  Widget build(BuildContext context) {
    MaterialColor customColor = MaterialColor(0xFF1062FE, color);
    Provider.of<CheckinOroutService>(context, listen: false).init(context);
    return MaterialApp(
      title: 'Neoffice',
      theme: ThemeData(
        primarySwatch: customColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      supportedLocales: [
        const Locale('fr'),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}