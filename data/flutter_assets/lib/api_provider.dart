import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';
import 'package:neoffice_linux_app_rc522/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cookie_interceptor.dart';

class LoginResultApp {
  final bool success;
  final String? errorMessage;
  final Map<String, String>? headers;

  LoginResultApp({
    required this.success,
    this.errorMessage,
    this.headers,
  });
}

class LoginResult {
  final bool success;
  final String? errorMessage;
  final Map<String, String>? headers;

  LoginResult({
    required this.success,
    this.errorMessage,
    this.headers,
  });
}

class ApiProvider extends ChangeNotifier {
  String _baseUrl = '';
  String? _loggedInUserId;
  Map<String, dynamic>? _loggedInUserInfo;
  final http.Client _client =
      InterceptedClient.build(interceptors: [CookieInterceptor()]);
  List<String> _cookies = [];
  List<String> get cookies => _cookies;
  String? _password;
  String? _locationDeviceId;

  String getCookies(LoginResultApp LoginResultApp) {
    if (LoginResultApp.headers != null &&
        LoginResultApp.headers!.containsKey('set-cookie')) {
      return LoginResultApp.headers!['set-cookie']!;
    } else {
      return '';
    }
  }

  Future<String> get selectedProfile async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selectedProfile') ?? 'Caisse';
  }

  void setBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }

  void _handleError(BuildContext context, String message) {
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SettingsScreen()),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 5),
      ),
    );
    throw Exception(message);
  }

  dynamic _handleResponse(http.Response response, BuildContext context) {
    switch (response.statusCode) {
      case 200:
        return json.decode(response.body);
      case 403:
        _handleError(
          context,
          "La session est expirée ou vous n'avez pas les droits pour accéder à cette application.",
        );
        break;
      default:
        if (response.body.contains("Guest")) {
          _handleError(
            context,
            "La session est expirée ou vous n'avez pas les droits pour accéder à cette application.",
          );
        } else {
          throw Exception(
            'Erreur lors de la récupération des données (code d\'état: ${response.statusCode}, réponse: ${response.body})',
          );
        }
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _password = prefs.getString('password');
    String? instanceUrl = prefs.getString('instanceUrl');
    _locationDeviceId = prefs.getString('locationDeviceId');

    if (instanceUrl != null) {
      _baseUrl = '$instanceUrl/api';
    } else {
      _baseUrl = '';
    }
  }

  Future<void> initProvider() async {
    await _loadData();
  }

  Future<dynamic> get(String url, BuildContext context) async {
    try {
      final response = await _client.get(Uri.parse(_baseUrl + url));
      return _handleResponse(response, context);
    } catch (e) {
      print('Error during data retrieval: $e');
      throw Exception('Error during data retrieval.');
    }
  }

  Future<LoginResult> checkauth(String password, BuildContext context) async {
    //print('SE logging in...');

    if (_baseUrl.isEmpty || !_baseUrl.startsWith("http")) {
      print("Error: _baseUrl is not initialized or incorrect: $_baseUrl");
      return LoginResult(success: false, errorMessage: "URL is not set up properly.");
    }

    try {
      String basicAuth = 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:${password}'));
      final response = await _client.post(
        Uri.parse(_baseUrl + '/api/method/frappe.auth.get_logged_user'),
        headers: <String, String>{
          'Authorization': basicAuth,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      //print("Sent Authorization header: $basicAuth");
      //print("Received response with status code: ${response.statusCode}");

      if (response.statusCode == 200) {
        return LoginResult(success: true);
      } else {
        return LoginResult(
            success: false,
            errorMessage: 'Échec de la connexion. Status code: ${response.statusCode}'
        );
      }
    } catch (e, stacktrace) {
      print("Erreur lors de la connexion : $e");
      print("Stacktrace : $stacktrace");
      return LoginResult(success: false, errorMessage: e.toString());
    }
  }

  Future<String?> getMostRecentCheckinType(String employeeLink, BuildContext context) async {
    //print('getMostRecentCheckinType');
    if (employeeLink.isEmpty) {
      throw Exception('Aucun employé sélectionné');
    }

    await _loadData();

    final String basicAuth = 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password'));
    final Uri uri = Uri.parse(_baseUrl + '/resource/Employee Checkin')
        .replace(queryParameters: {
      'fields': '["name", "log_type"]',
      'filters': '[["Employee Checkin","employee","=","$employeeLink"],["Employee Checkin", "time", "Timespan","today"]]',
      'order_by': 'time desc'
    });

    final response = await _client.get(
      uri,
      headers: <String, String>{
        'Authorization': basicAuth,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      //print("Server Response: ${response.body}");

      final data = jsonDecode(response.body);
      if (data['data'].isEmpty) {
        return null;
      } else {
        return data['data'][0]['log_type'];
      }

    } else if (response.statusCode == 403) {
      _handleError(
        context,
        "La session est expirée ou vous n'avez pas les droits pour accéder à cette application.",
      );
      throw Exception('Erreur 403 - Accès refusé');
    } else {
      throw Exception('Erreur lors de la récupération des données (code d\'état: ${response.statusCode})');
    }
  }

  Future<bool> createEmployeeCheckin(String employeeLink, String time, BuildContext context) async {
    //print('createEmployeeCheckin');
    if (employeeLink.isEmpty) {
      throw Exception('Aucun employé sélectionné');
    }

    await _loadData();

    final attendance = await getAttendanceToday(employeeLink, context);
    final attendanceValue = attendance != null && attendance.containsKey('name')
        ? attendance['name']
        : null;

    final String basicAuth = 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password'));
    final Uri uri = Uri.parse(_baseUrl + '/resource/Employee Checkin');

    final response = await _client.post(
      uri,
      headers: <String, String>{
        'Authorization': basicAuth,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'employee': employeeLink,
        'time': time,
        'log_type': 'IN',
        'attendance': attendanceValue,
        'device_id': _locationDeviceId,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 403) {
      _handleError(
        context,
        "La session est expirée ou vous n'avez pas les droits pour accéder à cette application.",
      );
      throw Exception('Erreur 403 - Accès refusé');
    } else {
      throw Exception('Erreur lors de la création du Checkin (code d\'état: ${response.statusCode})');
    }
  }

  Future<bool> createEmployeeCheckout(String employeeLink, String time, BuildContext context) async {
    //print('createEmployeeCheckout');
    if (employeeLink.isEmpty) {
      throw Exception('Aucun employé sélectionné');
    }

    await _loadData();

    final attendance = await getAttendanceToday(employeeLink, context);
    final attendanceValue = attendance != null && attendance.containsKey('name')
        ? attendance['name']
        : null;

    final String basicAuth = 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password'));

    final response = await _client.post(
      Uri.parse(_baseUrl + '/resource/Employee Checkin'),
      headers: <String, String>{
        'Authorization': basicAuth,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'employee': employeeLink,
        'time': time,
        'log_type': 'OUT',
        'attendance': attendanceValue,
        'device_id': _locationDeviceId,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 403) {
      _handleError(
        context,
        "La session est expirée ou vous n'avez pas les droits pour accéder à cette application.",
      );
      throw Exception('Erreur 403 - Accès refusé');
    } else {
      throw Exception('Erreur lors de la création du checkout (code d\'état: ${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>?> getEmployeeInfoByDeviceId(List<String> fields, String attendanceDeviceId, BuildContext context) async {
    //print("getEmployeeInfoByDeviceId");

    await _loadData();

    final String basicAuth = 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password'));
    final Uri uri = Uri.parse(_baseUrl + '/resource/Employee')
        .replace(queryParameters: {
      'fields': jsonEncode(fields),
      'filters': '[["attendance_device_id","=","$attendanceDeviceId"]]',
      'limit': '1'
    });

    final response = await _client.get(
      uri,
      headers: <String, String>{
        'Authorization': basicAuth,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.isEmpty || data['data'].isEmpty) {
        return null;
      } else {
        return data['data'][0];
      }
    } else if (response.statusCode == 403) {
      _handleError(
        context,
        "La session est expirée ou vous n'avez pas les droits pour accéder à cette ressource.",
      );
      throw Exception('Erreur 403 - Accès refusé');
    } else {
      throw Exception('Erreur lors de la récupération des données (code d\'état: ${response.statusCode})');
    }
  }


  Future<Map<String, dynamic>?> getAttendanceToday(String employeeLink, BuildContext context) async {
    //print('getAttendanceToday');
    if (employeeLink.isEmpty) {
      throw Exception('Aucun employé sélectionné');
    }

    await _loadData();

    final String basicAuth = 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password'));
    final Uri uri = Uri.parse(_baseUrl + '/resource/Attendance')
        .replace(queryParameters: {
      'filters': '[["Attendance","employee","=","$employeeLink"],["Attendance","attendance_date","Timespan","today"]]'
    });

    final response = await _client.get(
      uri,
      headers: <String, String>{
        'Authorization': basicAuth,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final attendance = json.decode(response.body);
      if (attendance['data'].length > 0) {
        return attendance['data'][0];
      } else {
        return null;
      }
    } else if (response.statusCode == 403) {
      _handleError(
        context,
        "La session est expirée ou vous n'avez pas les droits pour accéder à cette application.",
      );
      throw Exception('Erreur 403 - Accès refusé');
    } else {
      throw Exception('Erreur lors de la récupération des données (code d\'état: ${response.statusCode})');
    }
  }

  Future<String> employeeCheckinCheckout(String employee, String deviceId, bool autoAttendance, BuildContext context) async {
    //print('employeeCheckinCheckout');
    if (employee.isEmpty) {
      throw Exception('Aucun employé sélectionné');
    }

    await _loadData();

    final String basicAuth = 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password'));
    final Uri uri = Uri.parse(_baseUrl + '/method/neoffice_theme.events.employee_checkin_checkout');

    final response = await _client.post(
      uri,
      headers: <String, String>{
        'Authorization': basicAuth,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'employee': employee,
        'device_id': deviceId,
        'auto_attendance': autoAttendance,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message'];
    } else if (response.statusCode == 403) {
      _handleError(
        context,
        "La session est expirée ou vous n'avez pas les droits pour accéder à cette application.",
      );
      throw Exception('Erreur 403 - Accès refusé');
    } else {
      throw Exception('Erreur lors de l\'appel de employee_checkin_checkout (code d\'état: ${response.statusCode})');
    }
  }

  Future<List<String>?> getAds(BuildContext context) async {
    await _loadData();
    try {
        final response = await _client.get(
            Uri.parse(_baseUrl + '/resource/In-App Ads?fields=["name", "image", "enabled"]'),
            headers: <String, String>{
                'Authorization': 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password')),
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            },
        );
        final responseJson = _handleResponse(response, context);
        List<String> imageUrls = [];
        _baseUrl = _baseUrl.replaceAll('/api', '');
        for (var ad in responseJson['data']) {
            if (ad['enabled'] == 1) {
                imageUrls.add(_baseUrl + ad['image']);
            }
        }
        return imageUrls;
    } catch (e) {
        print("Erreur lors de la récupération du slider : $e");
        return [];
    }
  }

  Future<List<String>?> getProfile(BuildContext context) async {
    await _loadData();
    try {
        final response = await _client.get(
            Uri.parse(_baseUrl + '/resource/POS Profile?fields=["name"]'),
            headers: <String, String>{
                'Authorization': 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password')),
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            },
        );
        final responseJson = _handleResponse(response, context);
        List<String> profileName = [];
        for (var pr in responseJson['data']) {
            profileName.add(pr['name']);
        }
        return profileName;
    } catch (e) {
        print("Erreur lors de la récupération des profiles : $e");
        return [];
    }
  }

  Future<PaymentInfo?> getTwintPayment(BuildContext context) async {
    await _loadData();
    try {
        final response = await _client.get(
            Uri.parse(_baseUrl + '/resource/TWINT Payment Request?fields=["name","url","payment_status","pos_profile","payment_initiated"]'),
            headers: <String, String>{
                'Authorization': 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password')),
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            },
        );
        final responseJson = _handleResponse(response, context);
        responseJson['data'].sort((a, b) {
            var dateA = a['payment_initiated'] != null ? DateTime.parse(a['payment_initiated']) : null;
            var dateB = b['payment_initiated'] != null ? DateTime.parse(b['payment_initiated']) : null;
            if (dateA == null || dateB == null) {
                if (dateA == null && dateB == null) return 0;
                return dateA == null ? -1 : 1;
            }
            return dateB.compareTo(dateA); // Reverse the order here
        });
        PaymentInfo? oldestPayment;
        for (var pay in responseJson['data']) {
            if ((pay['payment_status'] == "" || pay['payment_status'] == "IN_PROGRESS") && pay['pos_profile'] == selectedProfile) {
                oldestPayment = PaymentInfo(url: pay['url'], name: pay['name']);
                break;
            }
        }
        return oldestPayment;
    } catch (e) {
        print("Erreur lors de la récupération des getTwintPayment : $e");
        return null;
    }
  }

  Future<String?> getTwintPaymentStatus(String paymentId, BuildContext context) async {
    await _loadData();
    try {
        final response = await _client.get(
            Uri.parse(_baseUrl + '/resource/TWINT Payment Request/$paymentId'),
            headers: <String, String>{
                'Authorization': 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password')),
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            },
        );
        final responseJson = _handleResponse(response, context);
        return responseJson['data']['payment_status'];
    } catch (e) {
        print("Erreur lors de la récupération du statut de paiement : $e");
        return null;
    }
  }

  Future<String?> getPosCart(String profile, BuildContext context) async {
    await _loadData();
    try {
        final response = await _client.get(
            Uri.parse(_baseUrl + '/method/neoffice_theme.events.pos_read_json_file?pos_profile=$profile'),
            headers: <String, String>{
                'Authorization': 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password')),
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            },
        );
        final responseJson = _handleResponse(response, context);
        // Convert the message to a string
        return jsonEncode(responseJson['message']);
    } catch (e) {
        print("Erreur lors de la récupération du panier : $e");
        return null;
    }
  }

  Future<bool> createCustomer(
    String customerName,
    String email,
    bool isCompany,
    String streetandNumber,
    String pincode,
    String city,
    String? mobile,
    String country,
    BuildContext context) async {
    await _loadData();
    try {
        final response = await _client.post(
            Uri.parse(_baseUrl + '/method/neoffice_theme.events.create_customer?isCompany=$isCompany&customer_name=$customerName&email_id=$email&company&address_line1=$streetandNumber&pincode=$pincode&city=$city&mobile_no=$mobile&country=$country'),
            headers: <String, String>{
                'Authorization': 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password')),
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            },
        );
        final responseJson = _handleResponse(response, context);
        if (responseJson['_server_messages'] != null &&
            responseJson['_server_messages'].contains('Changed customer name to')) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('L\'adresse e-mail existe déjà.'),
                    backgroundColor: Colors.red,
                ),
            );
            return false;
        } else {
            return true;
        }
    } catch (e) {
        print("Erreur lors de la création du client : $e");
        return false;
    }
  }


  /*  
  Future<bool> hasAttendanceToday(String employeeLink, BuildContext context) async {
    //print("hasAttendanceToday");
    if (employeeLink.isEmpty) {
      throw Exception('Aucun employé sélectionné');
    }

    await _loadData();

    final String basicAuth = 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password'));
    final Uri uri = Uri.parse(_baseUrl + '/resource/Attendance');

    final response = await _client.get(
      uri,
      headers: <String, String>{
        'Authorization': basicAuth,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final attendance = jsonDecode(response.body);
      return attendance['data'].length > 0;
    } else if (response.statusCode == 403) {
      _handleError(
        context,
        "La session est expirée ou vous n'avez pas les droits pour accéder à cette application.",
      );
      throw Exception('Erreur 403 - Accès refusé');
    } else {
      throw Exception('Erreur lors de la récupération des données (code d\'état: ${response.statusCode})');
    }
  }


  Future<bool> createAttendance(String employeeLink, String date, String status, BuildContext context) async {
    //print('createAttendance');
    if (employeeLink.isEmpty) {
      throw Exception('Aucun employé sélectionné');
    }

    await _loadData();

    final String basicAuth = 'Basic ' + base64Encode(utf8.encode('06fd969c2755b58:$_password'));
    final Uri uri = Uri.parse(_baseUrl + '/resource/Attendance');

    final response = await _client.post(
      uri,
      headers: <String, String>{
        'Authorization': basicAuth,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'employee': employeeLink,
        'attendance_date': date,
        'status': status,
        'docstatus': 1,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 403) {
      _handleError(
        context,
        "La session est expirée ou vous n'avez pas les droits pour accéder à cette application.",
      );
      throw Exception('Erreur 403 - Accès refusé');
    } else {
      throw Exception('Erreur lors de la création de l\'Attendance (code d\'état: ${response.statusCode})');
    }
  }
  */

}

class PaymentInfo {
  final String url;
  final String name;

  PaymentInfo({required this.url, required this.name});
}
