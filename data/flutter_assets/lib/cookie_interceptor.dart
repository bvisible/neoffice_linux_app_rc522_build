import 'package:http_interceptor/http_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

const String baseUrl = '';

class CookieInterceptor implements InterceptorContract {
  late List<String> _cookies = [];

  List<String> get cookies => _cookies;

  @override
  Future<ResponseData> interceptResponse({required ResponseData data}) async {
    String? cookie = data.headers?['set-cookie'];
    if (cookie != null && cookie.isNotEmpty && !cookie.contains('full_name=Guest')) {
      final newCookies = cookie.split(', ');
      newCookies.forEach((newCookie) {
        _cookies.removeWhere((c) => c.startsWith(newCookie.split('; ')[0]));
        _cookies.add(newCookie);
      });
      await _storeCookies(_cookies);
    }

    //print('Cookies from response: $_cookies');
    return data;
  }


  @override
  Future<RequestData> interceptRequest({required RequestData data}) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedCookies = [];
    _cookies.clear();
    var savedCookiesRaw = prefs.get('cookies');
    if (savedCookiesRaw is List) {
      savedCookies = savedCookiesRaw.cast<String>();
    } else if (savedCookiesRaw is String) {
      savedCookies = savedCookiesRaw.split(',');
    }
    //print('savedCookies: $savedCookies');
    if (savedCookies.isNotEmpty) {
      data.headers['cookie'] = savedCookies.join('; ');
    }
    //print('Cookies from request: $_cookies');

    return data;
  }

  Future<void> _storeCookies(List<String> cookies) async {
    final prefs = await SharedPreferences.getInstance();
    final filteredCookies = cookies.where((c) => !c.contains('full_name=Guest')).toList();
    final cookiesAsString = filteredCookies.join(', ');
    await prefs.setString('cookies', cookiesAsString);
  }

  Future<void> clearCookies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cookies');
    _cookies.clear();
  }

}
