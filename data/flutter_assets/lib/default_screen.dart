import 'package:flutter/material.dart';

class DefaultPage extends StatefulWidget {
  final VoidCallback? onToggleAttendance;

  DefaultPage({this.onToggleAttendance});

  @override
  _DefaultPageState createState() => _DefaultPageState();
}

class _DefaultPageState extends State<DefaultPage> {
  bool _loading = false;


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Default',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                      color: Color(0xFF1B1E24),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

            ],
          ),
        ),
      ),
    );
  }
}
