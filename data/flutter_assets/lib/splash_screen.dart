import 'dart:async';
import 'package:flutter/material.dart';
import 'package:neoffice_linux_app_rc522/animated_background.dart';
import 'package:neoffice_linux_app_rc522/settings_screen.dart';
import 'package:neoffice_linux_app_rc522/dashboard_screen.dart';
import 'package:neoffice_linux_app_rc522/services/api_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _checkSettingsAndNavigate();
  }

  _checkSettingsAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final instanceUrl = prefs.getString('instanceUrl');
    final password = prefs.getString('password');

    if (instanceUrl != null && password != null) {
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      apiProvider.setBaseUrl(instanceUrl);
      final result = await apiProvider.checkauth(password, context);
      if (result.success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SettingsScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SettingsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

