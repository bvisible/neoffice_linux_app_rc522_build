import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neoffice_linux_app_rc522/services/api_provider.dart';
import 'package:neoffice_linux_app_rc522/settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:neoffice_linux_app_rc522/models/weather_data_current.dart';
import 'package:neoffice_linux_app_rc522/utils/custom_colors.dart';
import 'package:neoffice_linux_app_rc522/widgets/current_weather_widget.dart';
import 'package:fast_cached_network_image/fast_cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_analog_clock/flutter_analog_clock.dart';
import 'package:neoffice_linux_app_rc522/second_screen/second_screen_view.dart';
import 'package:neoffice_linux_app_rc522/services/checkin_orout_service.dart';
import 'package:provider/provider.dart';
import 'package:neoffice_linux_app_rc522/main.dart';

class Background extends StatefulWidget {
  @override
  _BackgroundState createState() => _BackgroundState();
}

class _BackgroundState extends State<Background>
    with SingleTickerProviderStateMixin {
  //late final AnimationController _controller;
  late Future<String> _imageUrlFuture;

  @override
  void initState() {
    super.initState();
    //_controller = AnimationController(vsync: this);
    _imageUrlFuture = fetchImageUrl(
        'https://bing.biturl.top/?resolution=1920&format=json&index=0&mkt=random');
  }

  @override
  void dispose() {
    //_controller.dispose();
    super.dispose();
  }

  Future<String> fetchImageUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['url'] as String;
    } else {
      throw Exception('Failed to load image URL');
    }
  }

  Future<void> _initFastCachedImage() async {
    String storageLocation = (await getApplicationDocumentsDirectory()).path;
    await FastCachedImageConfig.init(
        subDir: storageLocation, clearCacheAfter: const Duration(days: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<String>(
          future: _imageUrlFuture,
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container();
            } else if (snapshot.hasError) {
              return Text('Erreur : ${snapshot.error}');
            } else {
              return FastCachedImage(
                url: snapshot.data!,
                fit: BoxFit.cover,
                height: double.infinity,
                width: double.infinity,
                alignment: Alignment.center,
              );
            }
          },
        )
      ],
    );
  }
}

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _logoUrl = '';
  late SharedPreferences _prefs;
  String _instanceUrl = '';
  String? _employeeInfo;
  String? _currentTime;
  ApiProvider apiProvider = ApiProvider();
  String _currentDateTime = '';
  Map<String, DateTime> _lastScannedIds = {};
  String _version = '';
  DateTime? _lastCallTime;
  String? _remainingTime;
  String? _weatherData;
  WeatherDataCurrent? _weatherDataCurrent;
  Timer? _timerWeather;
  Timer? _dateTimeTimer;
  Future<int?>? _posValueFuture;
  Future<int?>? _worksheetValueFuture;

  @override
  void initState() {
    super.initState();
    _loadLogoUrl();
    _getVersion();
    _updateCurrentDateTime();
    _fetchWeatherData();
    _timerWeather =
        Timer.periodic(Duration(minutes: 5), (Timer t) => _fetchWeatherData());
    _dateTimeTimer = Timer.periodic(
        Duration(seconds: 1), (timer) => _updateCurrentDateTime());
    _posValueFuture = apiProvider.getNeoConfig("pos", context);
    _worksheetValueFuture = apiProvider.getNeoConfig("worksheet", context);
  }

  _getVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
    });
  }

  Future<void> _fetchWeatherData() async {
    try {
      // Obtenez l'adresse IP de l'appareil
      final responseIp =
          await http.get(Uri.parse('https://api.ipify.org?format=json'));
      final ip = jsonDecode(responseIp.body)['ip'];
      // Obtenez la latitude et la longitude en utilisant l'API ipapi
      final responseLatLong =
          await http.get(Uri.parse('https://ipapi.co/$ip/latlong/'));
      final latLong = responseLatLong.body.split(',');
      // Obtenez les données météo en utilisant FetchWeatherAPI
      final fetchWeatherAPI = FetchWeatherAPI();
      final weatherData = await fetchWeatherAPI.processData(
          double.parse(latLong[0]), double.parse(latLong[1]));
      // Mettez à jour _weatherDataCurrent avec les données météo
      setState(() {
        _weatherDataCurrent = weatherData;
      });
    } catch (e) {
      print('Erreur lors de la récupération des données météo : $e');
    }
  }

  void _updateCurrentDateTime() {
    setState(() {
      _currentDateTime = DateFormat('HH:mm:ss dd-MM-yy').format(DateTime.now());
    });
  }

  _loadLogoUrl() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _instanceUrl = _prefs.getString('instanceUrl') ?? '';
      _logoUrl = '$_instanceUrl/web/wp-content/files/logo-default.png';
    });
  }

  Widget _buildBlurBoxGlobal({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0),
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: Color(0xFFEDEDED).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBlurBox({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(1),
          border: Border.all(
            color: Color(0xFFEDEDED), // Hex color code for ededed
            width: 1, // Width of the border
          ),
          borderRadius: BorderRadius.circular(10.0), // Match with ClipRRect
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<CheckinOroutService>(context, listen: false).init(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Background(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(50.0, 60.0, 50.0, 50.0),
            child: _buildBlurBoxGlobal(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 150,
                            child: _buildBlurBox(
                              child: Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(left: 10),
                                    child: Image.asset(
                                        'assets/images/emoji_hello.png',
                                        height: 35,
                                        width: 35),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 25,
                                          color: CustomColors.textColorBlack,
                                        ),
                                        children: <TextSpan>[
                                          TextSpan(
                                            text: 'Bonjour,\n',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          TextSpan(
                                            text:
                                                'Veuillez scanner votre badge...',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 20.0),
                        SizedBox(
                          height: 150,
                          width: 150,
                          child: _buildBlurBox(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: AnalogClock(
                                dateTime: DateTime.now(),
                                isKeepTime: true,
                                child: Align(
                                  alignment: FractionalOffset(0.5, 0.75),
                                  child: Text(
                                    DateFormat('dd-MM-yy')
                                        .format(DateTime.now()),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.0),
                    Row(
                      children: [
                        SizedBox(
                          height: 150,
                          width: 150,
                          child: _buildBlurBox(
                            child: _weatherDataCurrent != null
                                ? CurrentWeatherWidget(
                                    weatherDataCurrent: _weatherDataCurrent!)
                                : Container(),
                          ),
                        ),
                        SizedBox(width: 20.0),
                        FutureBuilder<int?>(
                          future: _posValueFuture,
                          builder: (BuildContext context,
                              AsyncSnapshot<int?> snapshot) {
                            if (snapshot.hasData && snapshot.data == 1) {
                              return SizedBox(
                                height: 150,
                                width: 150,
                                child: _buildBlurBox(
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                SecondscreenPage()),
                                      );
                                    },
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        Image.asset('assets/icons/cart.png',
                                            height: 80, width: 80),
                                        SizedBox(width: 5.0),
                                        Text('Second écran'),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return SizedBox.shrink();
                            }
                          },
                        ),
                        SizedBox(width: 20.0),
                        FutureBuilder<int?>(
                          future: _worksheetValueFuture,
                          builder: (BuildContext context,
                              AsyncSnapshot<int?> snapshot) {
                            if (snapshot.hasData && snapshot.data == 1) {
                              return SizedBox(
                                height: 150,
                                width: 150,
                                child: _buildBlurBox(
                                  child: InkWell(
                                    onTap: () {
                                      myAppStateKey.currentState
                                          ?.showScannerModal("nobarcode");
                                    },
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        Image.asset(
                                            'assets/icons/worksheet.png',
                                            height: 80,
                                            width: 80),
                                        SizedBox(width: 5.0),
                                        Text('Feuille de travail'),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return SizedBox.shrink();
                            }
                          },
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(top: 0, left: 10, right: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _logoUrl.isNotEmpty
                    ? Image.network(
                        _logoUrl,
                        height: 40,
                        fit: BoxFit.cover,
                      )
                    : Container(),
                IconButton(
                  icon: Text(
                    String.fromCharCode(Icons.settings.codePoint),
                    style: TextStyle(
                      fontFamily: Icons.settings.fontFamily,
                      fontSize: 30.0,
                      color: Colors.black,
                      shadows: [
                        Shadow(
                          offset: Offset(0.5, 0.5),
                          color: Colors.white,
                          blurRadius: 0,
                        ),
                        Shadow(
                          offset: Offset(-0.5, 0.5),
                          color: Colors.white,
                          blurRadius: 0,
                        ),
                        Shadow(
                          offset: Offset(0.5, -0.5),
                          color: Colors.white,
                          blurRadius: 0,
                        ),
                        Shadow(
                          offset: Offset(-0.5, -0.5),
                          color: Colors.white,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsScreen()),
                    );
                  },
                )
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Text(
              "V: $_version",
              style: TextStyle(
                fontSize: 15,
                color: Colors.black,
                shadows: [
                  Shadow(
                    // Bottom-left shadow
                    offset: Offset(-0.5, -0.5),
                    color: Colors.white,
                  ),
                  Shadow(
                    // Bottom-right shadow
                    offset: Offset(0.5, -0.5),
                    color: Colors.white,
                  ),
                  Shadow(
                    // Top-left shadow
                    offset: Offset(-0.5, 0.5),
                    color: Colors.white,
                  ),
                  Shadow(
                    // Top-right shadow
                    offset: Offset(0.5, 0.5),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dateTimeTimer?.cancel();
    _timerWeather?.cancel();
    super.dispose();
  }
}

class FetchWeatherAPI {
  WeatherDataCurrent? weatherDataCurrent;

  Future<WeatherDataCurrent?> processData(double lat, double lon) async {
    final url =
        'http://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=a26830876b151b5f0e07f8459e31cbab';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse != null) {
        weatherDataCurrent = WeatherDataCurrent.fromJson(jsonResponse);
      } else {
        print('La réponse JSON est null');
      }
    } else {
      print(
          'Erreur lors de la récupération des données météo : ${response.statusCode}');
    }
    return weatherDataCurrent;
  }
}
