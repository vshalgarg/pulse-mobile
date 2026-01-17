import 'package:flutter/material.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeCreatorWidget extends StatefulWidget {
  const QrCodeCreatorWidget({Key? key}) : super(key: key);

  @override
  State<QrCodeCreatorWidget> createState() => _QrCodeCreatorWidgetState();
}

class _QrCodeCreatorWidgetState extends State<QrCodeCreatorWidget> {
  final inputText = TextEditingController();

  @override
  void dispose() {
    inputText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              QrImageView(
                data: inputText.text,
                size: 200,
                // backgroundColor: Colors.white,
              ),
              const SizedBox(height: 40),
              _buildTextField(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField() => TextFormField(
        controller: inputText,
        style: kTextStyle(
          fontSize: kFontSize20,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: "Type something...",
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.done),
          ),
        ),
      );
}
