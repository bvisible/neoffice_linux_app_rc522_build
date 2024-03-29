import 'package:flutter/material.dart';
import 'package:neoffice_linux_app_rc522/services/api_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:neoffice_linux_app_rc522/dashboard_screen.dart';
import 'package:vk/vk.dart';
import 'dart:io';


class SettingsScreen extends StatefulWidget {
  SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _instanceUrlController = TextEditingController(text: 'https://');
  final _passwordController = TextEditingController();
  final _locationDeviceIdController = TextEditingController(text: 'Timbreuse');
  bool _showVirtualKeyboardInstanceUrl = false;
  bool _showVirtualKeyboardPassword = false;
  bool _showVirtualKeyboardLocationDeviceId = false;
  bool _showVirtualKeyboardWifiName = false;
  bool _showVirtualKeyboardWifiPassword = false;
  String? _errorMessage;
  bool _obscureText = true;
  bool _obscureTextWifi = true;
  bool _isShiftEnabled = false;
  final _wifiNameController = TextEditingController();
  final _wifiPasswordController = TextEditingController();

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  Future<void> _settingscheck(BuildContext context) async {
    if (_formKey.currentState != null &&
        _formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      String instanceUrl = _instanceUrlController.text;
      if (!instanceUrl.startsWith("https://")) {
        instanceUrl = "https://" + instanceUrl;
      }
      Uri parsedUrl = Uri.parse(instanceUrl);
      instanceUrl = Uri(
        scheme: parsedUrl.scheme,
        host: parsedUrl.host,
        port: parsedUrl.port,
      ).toString();

      instanceUrl = instanceUrl.split("?")[0];
      instanceUrl = instanceUrl.split("#")[0];

      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      apiProvider.setBaseUrl(instanceUrl);
      await _saveData();
      final result = await apiProvider.checkauth(_passwordController.text, context);
      if (result.success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()),
        );
      } else {
        _showError(result.errorMessage ?? 'Échec de la connexion.');
      }
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    String instanceUrl = _instanceUrlController.text;
    if (!instanceUrl.startsWith("https://")) {
      instanceUrl = "https://" + instanceUrl;
    }
    Uri parsedUrl = Uri.parse(instanceUrl);
    instanceUrl = Uri(
      scheme: parsedUrl.scheme,
      host: parsedUrl.host,
      port: parsedUrl.port,
    ).toString();

    instanceUrl = instanceUrl.split("?")[0];

    prefs.setString('instanceUrl', instanceUrl);
    prefs.setString('password', _passwordController.text);
    prefs.setString('locationDeviceId', _locationDeviceIdController.text);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? instanceUrl = prefs.getString('instanceUrl');
    String? password = prefs.getString('password');

    if (instanceUrl != null && password != null) {
      _instanceUrlController.text = instanceUrl;
      _passwordController.text = password;
    }

    String? locationDeviceId = prefs.getString('locationDeviceId');
    if (locationDeviceId != null) {
      _locationDeviceIdController.text = locationDeviceId ?? 'Timbreuse';
    }

  }

  Future<void> _connectToWifi() async {
    String wifiName = _wifiNameController.text;
    String wifiPassword = _wifiPasswordController.text;

    // Afficher un SnackBar pour informer l'utilisateur que la vérification est en cours
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Vérification en cours...'),
        duration: Duration(seconds: 2), // Afficher le SnackBar pour une durée limitée
      ),
    );

    // Attendre que le SnackBar soit affiché pendant un moment avant de continuer
    await Future.delayed(Duration(seconds: 2));

    // Exécuter la commande de connexion au WiFi
    ProcessResult result = await Process.run('nmcli', ['dev', 'wifi', 'connect', wifiName, 'password', wifiPassword]);

    // Afficher le résultat de la connexion
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.exitCode == 0 ? 'Connecté avec succès au WiFi' : 'Erreur lors de la connexion au WiFi'),
      ),
    );
  }

  @override
  void dispose() {
    _instanceUrlController.dispose();
    _passwordController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset('assets/images/logo-neoffice.svg', width: 150),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showVirtualKeyboardInstanceUrl = false;
            _showVirtualKeyboardPassword = false;
            _showVirtualKeyboardLocationDeviceId = false;
            _showVirtualKeyboardWifiName = false;
            _showVirtualKeyboardWifiPassword = false;
        });
      },
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Paramètre de l'unité centrale",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1E24),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Connectez-vous avec les accès tier de votre instance :',
                style: TextStyle(fontSize: 16, color: Color(0xFF1B1E24)),
              ),
              SizedBox(height: 10),
              if (_errorMessage != null)
                Container(
                  padding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    color: Colors.redAccent,
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              SizedBox(height: 20),
              TextFormField(
                controller: _wifiNameController,
                onTap: () {
                  setState(() {
                    _showVirtualKeyboardInstanceUrl = false;
                    _showVirtualKeyboardPassword = false;
                    _showVirtualKeyboardLocationDeviceId = false;
                    _showVirtualKeyboardWifiName = true;
                    _showVirtualKeyboardWifiPassword = false;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Nom du WiFi',
                  filled: true,
                  labelStyle: TextStyle(color: Color(0xFF1B1E24)),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1B1E24)),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                keyboardType: TextInputType.text,
                style: TextStyle(color: Color(0xFF1B1E24)),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom du WiFi';
                  }
                  return null;
                },
              ),
              if (_showVirtualKeyboardWifiName)
                Container(
                  color: Colors.grey.shade900,
                  child: VirtualKeyboard(
                    height: 300,
                    type: VirtualKeyboardType.Alphanumeric,
                    textController: _wifiNameController,
                  ),
                ),
              SizedBox(height: 16),
              TextFormField(
                controller: _wifiPasswordController,
                onTap: () {
                  setState(() {
                    _showVirtualKeyboardInstanceUrl = false;
                    _showVirtualKeyboardPassword = false;
                    _showVirtualKeyboardLocationDeviceId = false;
                    _showVirtualKeyboardWifiName = false;
                    _showVirtualKeyboardWifiPassword = true;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Mot de passe du WiFi',
                  filled: true,
                  labelStyle: TextStyle(color: Color(0xFF1B1E24)),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1B1E24)),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureTextWifi = !_obscureTextWifi;
                      });
                    },
                    child: Icon(
                      _obscureTextWifi
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Color(0xFF1B1E24),
                    ),
                  ),
                ),
                obscureText: _obscureTextWifi,
                style: TextStyle(color: Color(0xFF1B1E24)),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le mot de passe du WiFi';
                  }
                  return null;
                },
              ),
              if (_showVirtualKeyboardWifiPassword)
                Container(
                  color: Colors.grey.shade900,
                  child: VirtualKeyboard(
                    height: 300,
                    type: VirtualKeyboardType.Alphanumeric,
                    textController: _wifiPasswordController,
                  ),
                ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _connectToWifi,
                child: Text('Se connecter au WiFi'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _instanceUrlController,
                      onTap: () {
                        setState(() {
                          _showVirtualKeyboardInstanceUrl = true;
                          _showVirtualKeyboardPassword = false;
                          _showVirtualKeyboardLocationDeviceId = false;
                          _showVirtualKeyboardWifiName = false;
                          _showVirtualKeyboardWifiPassword = false;
                        });
                      },
                      decoration: InputDecoration(
                        labelText:
                        'URL de l\'instance Neoffice (ex: monentreprise.neoffice.me)',
                        filled: true,
                        labelStyle: TextStyle(color: Color(0xFF1B1E24)),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1B1E24)),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      keyboardType: TextInputType.url,
                      style: TextStyle(color: Color(0xFF1B1E24)),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer l\'URL de l\'instance Neoffice';
                        }
                        return null;
                      },
                    ),
                    if (_showVirtualKeyboardInstanceUrl)
                      Container(
                        color: Colors.grey.shade900,
                        child: VirtualKeyboard(
                          height: 300,
                          type: VirtualKeyboardType.Alphanumeric,
                          textController: _instanceUrlController,
                        ),
                      ),

                    SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      onTap: () {
                        setState(() {
                          _showVirtualKeyboardInstanceUrl = false;
                          _showVirtualKeyboardLocationDeviceId = false;
                          _showVirtualKeyboardPassword = true;
                          _showVirtualKeyboardWifiName = false;
                          _showVirtualKeyboardWifiPassword = false;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        filled: true,
                        labelStyle: TextStyle(color: Color(0xFF1B1E24)),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1B1E24)),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                          child: Icon(
                            _obscureText
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Color(0xFF1B1E24),
                          ),
                        ),
                      ),
                      obscureText: _obscureText,
                      style: TextStyle(color: Color(0xFF1B1E24)),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre mot de passe';
                        }
                        return null;
                      },
                    ),
                    if (_showVirtualKeyboardPassword)
                      Container(
                        color: Colors.grey.shade900,
                        child: VirtualKeyboard(
                          height: 300, 
                          type: VirtualKeyboardType.Alphanumeric,
                          textController: _passwordController,
                        ),
                      ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _locationDeviceIdController,
                      onTap: () {
                        setState(() {
                          _showVirtualKeyboardInstanceUrl = false;
                          _showVirtualKeyboardPassword = false;
                          _showVirtualKeyboardLocationDeviceId = true;
                          _showVirtualKeyboardWifiName = false;
                          _showVirtualKeyboardWifiPassword = false;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Location / Device ID',
                        filled: true,
                        labelStyle: TextStyle(color: Color(0xFF1B1E24)),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1B1E24)),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      keyboardType: TextInputType.text,
                      style: TextStyle(color: Color(0xFF1B1E24)),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer la Location / Device ID';
                        }
                        return null;
                      },
                    ),
                    if (_showVirtualKeyboardLocationDeviceId)
                      Container(
                        color: Colors.grey.shade900,
                        child: VirtualKeyboard(
                          height: 300, 
                          type: VirtualKeyboardType.Alphanumeric,
                          textController: _locationDeviceIdController,
                        ),
                      ),


                    SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _settingscheck(context),
                        child: Text('Sauvegarder'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
