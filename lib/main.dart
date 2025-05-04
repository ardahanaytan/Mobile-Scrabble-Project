import 'package:flutter/material.dart';
import 'package:flutter_application_1/provider/room_data_provide.dart';
import 'package:flutter_application_1/screens/lobi_screen.dart';
import 'package:flutter_application_1/screens/register_screen.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/user_home_screen.dart';
import 'package:flutter_application_1/utils/colors.dart';
import 'package:flutter_application_1/screens/main_menu_screen.dart';
import 'package:flutter_application_1/screens/game_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print("HATA: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => RoomDataProvider(),
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData.dark().copyWith(
          useMaterial3: false,
          scaffoldBackgroundColor: bgColor,
        ),
        initialRoute: MainMenuScreen.routeName,
        routes: {
          MainMenuScreen.routeName: (context) => const MainMenuScreen(),
          LoginScreen.routeName: (context) => const LoginScreen(),
          RegisterScreen.routeName: (context) => const RegisterScreen(), // default değer
        },
        onGenerateRoute: (settings) {
          if (settings.name == LobbyScreen.routeName) {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => LobbyScreen(kullaniciAdi: args['kullaniciAdi']),
            );
          }

          if (settings.name == GameScreen.routeName) {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => GameScreen(kullaniciAdi: args['kullaniciAdi']),
            );
          }

          if (settings.name == UserHomeScreen.routeName) {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => UserHomeScreen(
                kullaniciAdi: args['kullaniciAdi'],
                kazanilanOyun: args['kazanilanOyun'],
                toplamOyun: args['toplamOyun'],
              ),
            );
          }

          return null;
        },
      ),
    );
  }
}
