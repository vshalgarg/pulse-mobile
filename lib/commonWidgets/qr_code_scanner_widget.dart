// import 'dart:developer';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:app/constants/constants_methods.dart';
// import 'package:qr_code_scanner/qr_code_scanner.dart';
//
// import 'show_qr_code_result_widget.dart';
//
// class QrCodeScannerWidget extends StatefulWidget {
//   const QrCodeScannerWidget({Key? key}) : super(key: key);
//
//   @override
//   State<QrCodeScannerWidget> createState() => _QrCodeScannerWidgetState();
// }
//
// class _QrCodeScannerWidgetState extends State<QrCodeScannerWidget> {
//   Barcode? result;
//   QRViewController? controller;
//   final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//         body: Stack(
//           alignment: Alignment.center,
//           children: [
//             _buildQrView(context),
//             Positioned(top: 2, child: buildControlButtons()),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildQrView(BuildContext context) {
//     return QRView(
//       key: qrKey,
//       onQRViewCreated: _onQRViewCreated,
//       overlay: QrScannerOverlayShape(
//         borderColor: Theme.of(context).primaryColor,
//         borderRadius: 10,
//         borderLength: 20,
//         borderWidth: 10,
//         cutOutSize: MediaQuery.of(context).size.width * 0.8,
//       ),
//       onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
//     );
//   }
//
//   void _onQRViewCreated(QRViewController controller) {
//     setState(() {
//       this.controller = controller;
//       this.controller?.resumeCamera();
//     });
//     controller.scannedDataStream.listen((scanData) {
//       // get data here
//       result = scanData;
//       // showToast(result!.code!);
//       Navigator.pop(context);
//       pushPage(context, ShowQrCodeResultWidget(scanData.code));
//       // setState(() { });
//     });
//   }
//
//   void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
//     log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
//     if (!p) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('no Permission')),
//       );
//     }
//   }
//
//   @override
//   void dispose() {
//     controller?.dispose();
//     super.dispose();
//   }
//
//   @override
//   void reassemble() {
//     super.reassemble();
//     if (Platform.isAndroid) {
//       controller!.pauseCamera();
//     } else if (Platform.isIOS) {
//       controller!.resumeCamera();
//     }
//   }
//
//   Widget buildControlButtons() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(8),
//         color: Colors.white24,
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: <Widget>[
//           IconButton(
//               onPressed: () async {
//                 await controller?.toggleFlash();
//                 setState(() {});
//               },
//               icon: FutureBuilder<bool?>(
//                 future: controller?.getFlashStatus(),
//                 builder: (context, snapshot) {
//                   if (snapshot.data != null) {
//                     return Icon(snapshot.data! ? Icons.flash_on : Icons.flash_off);
//                   } else {
//                     return Container();
//                   }
//                 },
//               )),
//           IconButton(
//             onPressed: () async {
//               await controller?.flipCamera();
//               setState(() {});
//             },
//             icon: FutureBuilder(
//               future: controller?.getCameraInfo(),
//               builder: (context, snapshot) {
//                 if (snapshot.data != null) {
//                   return const Icon(Icons.switch_camera);
//                 } else {
//                   return Container();
//                 }
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
