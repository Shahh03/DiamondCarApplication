import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RenterBookCarVariantPage extends StatefulWidget {
  final String renterId;

  const RenterBookCarVariantPage({super.key, required this.renterId});

  @override
  State<RenterBookCarVariantPage> createState() => _RenterBookCarVariantPageState();
}

class _RenterBookCarVariantPageState extends State<RenterBookCarVariantPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(backgroundColor: Colors.blueAccent, title: const Text('Book Car')),

      body: Center(
        child: Text("Page content here"),
      ),
    );
  }
}
