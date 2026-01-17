import 'package:flutter/material.dart';

class ShowQrCodeResultWidget extends StatelessWidget {
  final String? data;

  ShowQrCodeResultWidget(this.data);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Qr Code Result"),
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(data!),
        ),
      ),
    );
  }
}
