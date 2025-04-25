import 'package:flutter/material.dart';
import 'package:flutter_application_1/responsive/responsive.dart';
import 'package:flutter_application_1/screens/register_screen.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/widgets/custom_button.dart';

class MainMenuScreen extends StatelessWidget {
  static String routeName = '/main-menu';
  const MainMenuScreen({Key? key}) : super(key: key);

  void registerScreen(BuildContext context) {
    Navigator.pushNamed(context, RegisterScreen.routeName);
  }

  void loginScreen(BuildContext context) {
    Navigator.pushNamed(context, LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Responsive(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomButton(
              onTap: () => loginScreen(context), 
              text: 'Giriş Yap',
            ),
            SizedBox(height: 20),
            CustomButton(
              onTap: () => registerScreen(context), 
              text: 'Kayıt Ol',
            ),
          ],
        ),
      ),
    );
  }
}