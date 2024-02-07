import 'dart:async';
import 'package:flutter/material.dart';
import 'package:neoffice_linux_app_rc522/services/api_provider.dart';
import 'package:neoffice_linux_app_rc522/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:desktop_window/desktop_window.dart';
import 'package:fast_cached_network_image/fast_cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:neoffice_linux_app_rc522/services/checkin_orout_service.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopWindow.setFullScreen(true);

  String storageLocation = (await getApplicationDocumentsDirectory()).path;
  await FastCachedImageConfig.init(
      subDir: storageLocation, clearCacheAfter: Duration(days: 1));

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiProvider>(create: (_) => ApiProvider()),
        ChangeNotifierProvider<CheckinOroutService>(
          create: (context) => CheckinOroutService(
              apiProvider: Provider.of<ApiProvider>(context, listen: false)),
        ),
      ],
      child: MyApp(),
    ),
  );
}

GlobalKey<_MyAppState> myAppStateKey = GlobalKey<_MyAppState>();

class MyApp extends StatefulWidget {
  MyApp({Key? key}) : super(key: myAppStateKey);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void showScannerModal(String barcode) {
    _showModalscanner(context, barcode);
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool isDialogShown = false;
  String barcodeBuffer = '';
  Timer? debounceTimer;
  ApiProvider apiProvider = ApiProvider();
  String? selectedWorksheet;
  List<String> worksheets = [];

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

  void _showModalscanner(BuildContext context, String barcode) async {
    setState(() {
      selectedWorksheet = barcode.trim();
    });

    if (isDialogShown) return;

    setState(() {
      isDialogShown = true;
    });

    worksheets = await apiProvider.getWorksheet(context) ?? [];

    void _showStartWorkDialog(context, String? selectedWorksheet) async {
      List<Map<String, dynamic>> employees =
          await apiProvider.getEmployees(context) ?? [];
      Map<String, dynamic>? selectedEmployee;
      List<Map<String, dynamic>> activityType =
          await apiProvider.getActivityType(context) ?? [];
      Map<String, dynamic>? selectedActivityType;
      bool billable = true;
      TextEditingController billingRateController =
          TextEditingController(text: "0.00");
      String? scannedBarcode;
      if (mounted) {
        setState(() {
          isDialogShown = true;
        });
      }
      if (!mounted) return;
      showDialog(
        context: navigatorKey.currentContext!,
        builder: (BuildContext context) {
          return BarcodeKeyboardListener(
            bufferDuration: Duration(milliseconds: 200),
            onBarcodeScanned: (barcode) {
              setState(() {
                scannedBarcode = barcode.toLowerCase();
                var matchingEmployee = employees.firstWhere(
                  (employee) =>
                      employee['name'].toLowerCase() == scannedBarcode,
                  orElse: () => <String, dynamic>{},
                );
                if (matchingEmployee.isNotEmpty) {
                  selectedEmployee = matchingEmployee;
                  if (matchingEmployee['default_activity_type'] != null) {
                    var matchingActivityType = activityType.firstWhere(
                      (element) =>
                          element['name'] ==
                          matchingEmployee['default_activity_type'],
                      orElse: () => <String, dynamic>{},
                    );
                    if (matchingActivityType.isNotEmpty) {
                      selectedActivityType = matchingActivityType;
                      billingRateController.text =
                          matchingActivityType['billing_rate'].toString() ??
                              "0.00";
                    } else {
                      selectedActivityType = null;
                    }
                  } else {
                    selectedActivityType = null;
                  }
                }
              });
            },
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(5))),
              title: Text("Commencer le travail",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text("Worksheet",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedWorksheet,
                      icon: Icon(Icons.arrow_downward),
                      iconSize: 24,
                      elevation: 16,
                      style: TextStyle(color: Colors.deepPurple),
                      underline: Container(
                        height: 2,
                        color: Colors.deepPurpleAccent,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedWorksheet = newValue;
                        });
                      },
                      items: worksheets
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 2),
                    Text("Employé",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      value: selectedEmployee,
                      items:
                          employees.map<DropdownMenuItem<Map<String, dynamic>>>(
                        (Map<String, dynamic> value) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: value,
                            child: Text(value['name']),
                          );
                        },
                      ).toList(),
                      onChanged: (Map<String, dynamic>? newValue) {
                        setState(() {
                          selectedEmployee = newValue;
                          if (newValue != null &&
                              newValue['default_activity_type'] != null) {
                            var matchingActivityType = activityType.firstWhere(
                              (element) =>
                                  element['name'] ==
                                  newValue['default_activity_type'],
                              orElse: () => <String, dynamic>{},
                            );
                            if (matchingActivityType.isNotEmpty) {
                              selectedActivityType = matchingActivityType;
                              billingRateController.text =
                                  matchingActivityType['billing_rate']
                                          .toString() ??
                                      "0.00";
                            } else {
                              selectedActivityType = null;
                            }
                          } else {
                            selectedActivityType = null;
                          }
                        });
                      },
                    ),
                    SizedBox(height: 2),
                    Text("Type d'activité",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: <Widget>[
                        Flexible(
                          flex: 7,
                          child: DropdownButton<Map<String, dynamic>>(
                            isExpanded: true,
                            value: selectedActivityType,
                            items: activityType
                                .map<DropdownMenuItem<Map<String, dynamic>>>(
                                    (Map<String, dynamic> value) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: value,
                                child: Text(value['name']),
                              );
                            }).toList(),
                            onChanged: (Map<String, dynamic>? newValue) {
                              setState(() {
                                selectedActivityType = newValue;
                                billingRateController.text =
                                    newValue?['billing_rate'].toString() ??
                                        "0.00";
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 10), // Espace entre les widgets
                        Flexible(
                          flex: 3, // 30% de la largeur disponible
                          child: TextField(
                            readOnly: true,
                            controller: billingRateController,
                            decoration: InputDecoration(
                              labelText: "Prix",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    ListTile(
                      title: Text("Facturable",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Switch(
                        value: billable,
                        onChanged: (bool value) {
                          setState(() {
                            billable = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 2),
                    ElevatedButton(
                      onPressed: selectedWorksheet != null &&
                              selectedEmployee != null &&
                              selectedActivityType != null
                          ? () async {
                              // Appel de la fonction startPrimaryAction
                              await Provider.of<ApiProvider>(context,
                                      listen: false)
                                  .startPrimaryAction(
                                selectedWorksheet!,
                                selectedEmployee!['name'],
                                selectedActivityType!['name'],
                                billable,
                                context,
                              );
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Le début du travail a bien été enregistré. Vous pouvez commencer à travailler.'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  isDialogShown = false;
                                });
                              }
                            }
                          : null,
                      child: Text("Commencer le travail",
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromRGBO(16, 98, 254, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text("Annuler"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                )
              ],
            ),
          );
        },
      ).then((value) {
        if (mounted) {
          setState(() {
            isDialogShown = false;
          });
        }
      });
    }

    void _showEndWorkDialog(context, String? selectedWorksheet) async {
      List<Map<String, dynamic>> employees =
          await apiProvider.getEmployees(context) ?? [];
      Map<String, dynamic>? selectedEmployee;
      String? scannedBarcode;

      if (mounted) {
        setState(() {
          isDialogShown = true;
        });
      }
      if (!mounted) return;
      showDialog(
        context: navigatorKey.currentContext!,
        builder: (BuildContext context) {
          return BarcodeKeyboardListener(
            bufferDuration: Duration(milliseconds: 200),
            onBarcodeScanned: (barcode) {
              setState(() {
                scannedBarcode = barcode.toLowerCase();
                var matchingEmployee = employees.firstWhere(
                  (employee) =>
                      employee['name'].toLowerCase() == scannedBarcode,
                  orElse: () => <String, dynamic>{},
                );
                if (matchingEmployee.isNotEmpty) {
                  selectedEmployee = matchingEmployee;
                }
              });
            },
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(5))),
              title: Text("Finir le travail",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text("Employé",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      value: selectedEmployee,
                      items:
                          employees.map<DropdownMenuItem<Map<String, dynamic>>>(
                        (Map<String, dynamic> value) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: value,
                            child: Text(value['name']),
                          );
                        },
                      ).toList(),
                      onChanged: (Map<String, dynamic>? newValue) {
                        setState(() {
                          selectedEmployee = newValue;
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: selectedEmployee != null
                          ? () async {
                              await Provider.of<ApiProvider>(context,
                                      listen: false)
                                  .endPrimaryAction(
                                selectedEmployee!['name'],
                                "",
                                context,
                              );
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'La fin du travail a bien été enregistrée ${selectedEmployee!['name']}.'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  isDialogShown = false;
                                });
                              }
                            }
                          : null,
                      child: Text("Finir le travail",
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromRGBO(16, 98, 254, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text("Annuler"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      ).then((value) {
        if (mounted) {
          setState(() {
            isDialogShown = false;
          });
        }
      });
    }

    print("Selected worksheet: $selectedWorksheet");
    print(selectedWorksheet);
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5))),
          title: Text("Commencer à travailler"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Feuille de travail",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedWorksheet,
                  icon: Icon(Icons.arrow_downward),
                  iconSize: 24,
                  elevation: 16,
                  style: TextStyle(color: Colors.deepPurple),
                  underline: Container(
                    height: 2,
                    color: Colors.deepPurpleAccent,
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedWorksheet = newValue;
                    });
                  },
                  items:
                      worksheets.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
                Text("Commancer",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                ElevatedButton(
                  onPressed: selectedWorksheet != null &&
                          selectedWorksheet!.startsWith("WS-")
                      ? () {
                          Navigator.of(context).pop();
                          _showStartWorkDialog(context, selectedWorksheet);
                        }
                      : null, // Grise le bouton si selectedWorksheet est null ou ne commence pas par "WS-"
                  child: Text("Commencer le travail",
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedWorksheet != null &&
                            selectedWorksheet!.startsWith("WS-")
                        ? Color.fromRGBO(16, 98, 254, 1)
                        : Colors.grey, // Change la couleur si grisé
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text("Finir", style: TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: selectedWorksheet != null &&
                          selectedWorksheet!.startsWith("WS-")
                      ? () {
                          Navigator.of(context).pop();
                          _showEndWorkDialog(context, selectedWorksheet);
                        }
                      : null, // Grise le bouton si selectedWorksheet est null ou ne commence pas par "WS-"
                  child: Text("Finir le travail",
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedWorksheet != null &&
                            selectedWorksheet!.startsWith("WS-")
                        ? Color.fromRGBO(16, 98, 254, 1)
                        : Colors.grey, // Change la couleur si grisé
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Annuler"),
              onPressed: () {
                Navigator.of(context).pop();
                if (mounted) {
                  setState(() {
                    isDialogShown = false;
                  });
                }
              },
            )
          ],
        );
      },
    ).then((value) {
      if (mounted) {
        setState(() {
          isDialogShown = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    MaterialColor customColor = MaterialColor(0xFF1062FE, color);
    Provider.of<CheckinOroutService>(context, listen: false).init(context);
    return BarcodeKeyboardListener(
      bufferDuration: Duration(milliseconds: 200),
      onBarcodeScanned: (barcode) {
        debounceTimer?.cancel();
        barcodeBuffer += barcode + '\n';
        debounceTimer = Timer(Duration(milliseconds: 500), () {
          setState(() {
            _showModalscanner(context, barcodeBuffer);
            barcodeBuffer = '';
          });
        });
      },
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Neoffice',
        theme: ThemeData(
          primarySwatch: customColor,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        supportedLocales: [
          Locale('fr'),
        ],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      ),
      useKeyDownEvent: true,
    );
  }
}
