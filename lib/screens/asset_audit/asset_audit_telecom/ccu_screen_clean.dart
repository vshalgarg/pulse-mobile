// import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
// import 'package:app/constants/constants_methods.dart';
// import 'package:app/screens/asset_audit/asset_audit_telecom/battery_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_svg/svg.dart';
// import '../../../models/asset_audit_model.dart';
// import '../../../utils/asset_audit_post_helper.dart';
// import '../../../utils/asset_audit_photo_upload_helper.dart';
// import '../../../bloc/asset_audit_cubit.dart';
// import '../../../bloc/asset_audit_state.dart';
// import '../../../bloc/asset_audit_get_image_cubit.dart';
// import '../../../bloc/audit_schedule_status_cubit.dart';
// import '../../../repositories/image_repository.dart';
// import '../../../app_config.dart';
// import 'dart:io';
// import 'dart:convert';
//
// import '../../../commonWidgets/asset_type_card.dart';
// import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
// import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
// import '../../../commonWidgets/custom_form_appbar.dart';
// import '../../../commonWidgets/custom_form_field.dart';
// import '../../../commonWidgets/custom_image_upload_field.dart';
// import '../../../commonWidgets/custom_remark.dart';
// import '../../../commonWidgets/qr_screen_form_field.dart';
// import '../../../commonWidgets/base64_image_widget.dart';
// import '../../../constants/app_colors.dart';
// import '../../../constants/app_images.dart';
// import '../../../constants/constants_strings.dart';
//
// class CCUScreen extends StatefulWidget {
//   final CategoryData? ccuData;
//   final AssetAuditModel? assetAuditData;
//
//   const CCUScreen({super.key, this.ccuData, this.assetAuditData});
//
//   @override
//   State<CCUScreen> createState() => _CCUScreenState();
// }
//
// class _CCUScreenState extends State<CCUScreen> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController serialController = TextEditingController();
//   String? selectedFile;
//   String? selectedStatus;
//   String? selectedBatteryStatus;
//   String? selectedType;
//   bool hasUnsavedChanges = false;
//   bool showValidationErrors = false;
//
//   int totalRectifierItems = 6;
//   int totalMPPTItems = 6;
//   int totalCabinetItems = 6;
//   int currentScannedItems = 0;
//   List<Map<String, dynamic>> savedRectifierItems = [];
//   List<Map<String, dynamic>> savedMPPTItems = [];
//   List<Map<String, dynamic>> savedCabinetItems = [];
//   Map<String, dynamic> currentFormData = {};
//   String? uploadedPhotoPath;
//
//   String? rectifierSerialNumber;
//   String? rectifierPhoto;
//   int? rectifierPhotoId;
//   String? rectifierStatus;
//
//   int? cabinetPhotoId;
//   String? cabinetPhoto;
//   String? cabinetStatus;
//   String? cabinetSerialNumber;
//   final cabinetSerialController = TextEditingController();
//   final remarksController = TextEditingController();
//   final capacityController = TextEditingController();
//
//   String? mpptSerialNumber;
//   String? mpptPhoto;
//   int? mpptPhotoId;
//   String? mpptStatus;
//
//   final TextEditingController rectifierSerialController = TextEditingController();
//   final TextEditingController mpptSerialController = TextEditingController();
//
//   int rectifierCardKey = 0;
//   int mpptCardKey = 0;
//   int cabinetCardKey = 0;
//
//   bool _hasPostedCCUData = false;
//
//   // Image service
//   late ImageRepository _imageService;
//   Map<String, String> _imageCache = {};
//   String? _currentRequestedImageId;
//   bool _isRequestingImage = false;
//
//   @override
//   void initState() {
//     super.initState();
//     serialController.addListener(_onFormChanged);
//
//     if (!_hasDataToShow()) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         _navigateToBatteryScreen();
//       });
//       return;
//     }
//
//     capacityController.text = _getCCUCapacity();
//
//     // Initialize image service
//     _imageService = ImageRepository(AppConfig.of(context).apiProvider);
//
//     _loadCCUData();
//   }
//
//   @override
//   void dispose() {
//     serialController.dispose();
//     remarksController.dispose();
//     super.dispose();
//   }
//
//   void _onFormChanged() {
//     setState(() {
//       // Trigger rebuild when form changes
//     });
//   }
//
//   void _saveAndExit() async {
//     Navigator.of(context).pop();
//   }
//
//   bool _hasDataToShow() {
//     if (widget.assetAuditData == null) {
//       return false;
//     }
//
//     final ccuData = widget.assetAuditData!.responseData.ccu;
//     if (ccuData == null) {
//       return false;
//     }
//
//     final hasRectifierItems = (ccuData.ccuRectifiers?.length ?? 0) > 0;
//     final hasMpptItems = (ccuData.ccuMppt?.length ?? 0) > 0;
//     final hasCabinetItems = (ccuData.ccuCabinet?.length ?? 0) > 0;
//     final hasGeneralAssets = ccuData.assets.isNotEmpty;
//
//     return hasRectifierItems || hasMpptItems || hasCabinetItems || hasGeneralAssets;
//   }
//
//   String _getCCUCapacity() {
//     if (widget.assetAuditData == null) {
//       return '';
//     }
//
//     final ccuData = widget.assetAuditData!.responseData.ccu;
//     if (ccuData == null) {
//       return '';
//     }
//
//     // Get capacity from first available item
//     final rectifierItems = ccuData.ccuRectifiers ?? [];
//     if (rectifierItems.isNotEmpty && rectifierItems.first.capacity != null) {
//       return rectifierItems.first.capacity!;
//     }
//
//     final mpptItems = ccuData.ccuMppt ?? [];
//     if (mpptItems.isNotEmpty && mpptItems.first.capacity != null) {
//       return mpptItems.first.capacity!;
//     }
//
//     final cabinetItems = ccuData.ccuCabinet ?? [];
//     if (cabinetItems.isNotEmpty && cabinetItems.first.capacity != null) {
//       return cabinetItems.first.capacity!;
//     }
//
//     return '';
//   }
//
//   void _loadCCUData() {
//     if (!_hasDataToShow()) {
//       return;
//     }
//
//     if (widget.assetAuditData != null) {
//       setState(() {
//         final ccuData = widget.assetAuditData!.responseData.ccu;
//         if (ccuData != null) {
//           print('CCU Debug: Loading CCU data...');
//           print('CCU Debug: ccuData.ccuRectifiers?.length = ${ccuData.ccuRectifiers?.length ?? 0}');
//           print('CCU Debug: ccuData.ccuMppt?.length = ${ccuData.ccuMppt?.length ?? 0}');
//           print('CCU Debug: ccuData.ccuCabinet?.length = ${ccuData.ccuCabinet?.length ?? 0}');
//
//           // Clear existing saved items to avoid duplicates
//           savedRectifierItems.clear();
//           savedMPPTItems.clear();
//           savedCabinetItems.clear();
//           currentScannedItems = 0;
//
//           // Load CCU Rectifiers - only add items that have both photo_id and asset_status
//           final rectifierItems = ccuData.ccuRectifiers ?? [];
//           print('CCU Debug: Processing ${rectifierItems.length} rectifier items');
//           for (var item in rectifierItems) {
//             print('CCU Debug: Rectifier item - photoId: ${item.photoId}, assetStatus: ${item.assetStatus}, mfgSerialNo: ${item.mfgSerialNo}, remarks: ${item.itemTypeRemark}');
//             if (item.photoId != null && item.assetStatus != null) {
//               Map<String, dynamic> savedItem = {
//                 'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
//                 'photo': null,
//                 'photoId': item.photoId,
//                 'status': item.assetStatus ?? 'Unknown',
//                 'timestamp': DateTime.now(),
//                 'isQRCodeScanned': item.qrCodeScanned ?? false,
//                 'itemType': item.itemType ?? 'Unknown',
//                 'remarks': item.itemTypeRemark ?? 'CCU Rectifier Item',
//                 'assetStatus': item.assetStatus,
//                 'assetAuditSiteRespId': item.assetAuditSiteRespId,
//               };
//               savedRectifierItems.add(savedItem);
//               currentScannedItems++;
//               print('CCU Debug: Added rectifier item: ${savedItem['serialNumber']} with remarks: ${savedItem['remarks']}');
//             } else {
//               print('CCU Debug: Skipping rectifier item - photoId: ${item.photoId}, assetStatus: ${item.assetStatus}');
//             }
//           }
//
//           // Load CCU MPPT - only add items that have both photo_id and asset_status
//           final mpptItems = ccuData.ccuMppt ?? [];
//           print('CCU Debug: Processing ${mpptItems.length} MPPT items');
//           for (var item in mpptItems) {
//             print('CCU Debug: MPPT item - photoId: ${item.photoId}, assetStatus: ${item.assetStatus}, mfgSerialNo: ${item.mfgSerialNo}, remarks: ${item.itemTypeRemark}');
//             if (item.photoId != null && item.assetStatus != null) {
//               Map<String, dynamic> savedItem = {
//                 'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
//                 'photo': null,
//                 'photoId': item.photoId,
//                 'status': item.assetStatus ?? 'Unknown',
//                 'timestamp': DateTime.now(),
//                 'isQRCodeScanned': item.qrCodeScanned ?? false,
//                 'itemType': item.itemType ?? 'Unknown',
//                 'remarks': item.itemTypeRemark ?? 'CCU MPPT Item',
//                 'assetStatus': item.assetStatus,
//                 'assetAuditSiteRespId': item.assetAuditSiteRespId,
//               };
//               savedMPPTItems.add(savedItem);
//               currentScannedItems++;
//               print('CCU Debug: Added MPPT item: ${savedItem['serialNumber']} with remarks: ${savedItem['remarks']}');
//             } else {
//               print('CCU Debug: Skipping MPPT item - photoId: ${item.photoId}, assetStatus: ${item.assetStatus}');
//             }
//           }
//
//           // Load CCU Cabinet
//           final cabinetItems = ccuData.ccuCabinet ?? [];
//           print('CCU Debug: Processing ${cabinetItems.length} cabinet items');
//           for (var item in cabinetItems) {
//             print('CCU Debug: Cabinet item - photoId: ${item.photoId}, assetStatus: ${item.assetStatus}, mfgSerialNo: ${item.mfgSerialNo}, remarks: ${item.itemTypeRemark}');
//             if (item.photoId != null && item.assetStatus != null) {
//               Map<String, dynamic> savedItem = {
//                 'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
//                 'photo': null,
//                 'photoId': item.photoId,
//                 'status': item.assetStatus ?? 'Unknown',
//                 'timestamp': DateTime.now(),
//                 'isQRCodeScanned': item.qrCodeScanned ?? false,
//                 'itemType': item.itemType ?? 'Unknown',
//                 'remarks': item.itemTypeRemark ?? 'CCU Cabinet Item',
//                 'assetStatus': item.assetStatus,
//                 'assetAuditSiteRespId': item.assetAuditSiteRespId,
//               };
//               savedCabinetItems.add(savedItem);
//               currentScannedItems++;
//               print('CCU Debug: Added cabinet item: ${savedItem['serialNumber']} with remarks: ${savedItem['remarks']}');
//             } else {
//               print('CCU Debug: Skipping cabinet item - photoId: ${item.photoId}, assetStatus: ${item.assetStatus}');
//             }
//           }
//
//           print('CCU Debug: Final counts - Rectifiers: ${savedRectifierItems.length}, MPPT: ${savedMPPTItems.length}, Cabinet: ${savedCabinetItems.length}');
//         }
//       });
//     }
//   }
//
//   void _navigateToBatteryScreen() async {
//     if (!_hasChanges) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (context) => BatteryScreen(
//             batteryData: widget.assetAuditData?.responseData.battery,
//             assetAuditData: widget.assetAuditData,
//           ),
//         ),
//       );
//     } else {
//       // Show save and exit dialog
//       showDialog(
//         context: context,
//         builder: (BuildContext context) {
//           return AlertDialog(
//             title: const Text('Unsaved Changes'),
//             content: const Text('You have unsaved changes. Do you want to save them before proceeding?'),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   Navigator.pushReplacement(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => BatteryScreen(
//                         batteryData: widget.assetAuditData?.responseData.battery,
//                         assetAuditData: widget.assetAuditData,
//                       ),
//                     ),
//                   );
//                 },
//                 child: const Text('Discard'),
//               ),
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   // Save changes and navigate
//                   _saveChangesAndNavigate();
//                 },
//                 child: const Text('Save'),
//               ),
//             ],
//           );
//         },
//       );
//     }
//   }
//
//   void _saveChangesAndNavigate() async {
//     // Save changes logic here
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(
//         builder: (context) => BatteryScreen(
//           batteryData: widget.assetAuditData?.responseData.battery,
//           assetAuditData: widget.assetAuditData,
//         ),
//       ),
//     );
//   }
//
//   bool get _hasChanges {
//     return savedRectifierItems.isNotEmpty ||
//            savedMPPTItems.isNotEmpty ||
//            savedCabinetItems.isNotEmpty ||
//            rectifierSerialController.text.isNotEmpty ||
//            mpptSerialController.text.isNotEmpty ||
//            cabinetSerialController.text.isNotEmpty;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: CustomFormAppBar(
//         title: 'CCU',
//         onBackPressed: () {
//           if (_hasChanges) {
//             showDialog(
//               context: context,
//               builder: (BuildContext context) {
//                 return AlertDialog(
//                   title: const Text('Unsaved Changes'),
//                   content: const Text('You have unsaved changes. Do you want to save them before proceeding?'),
//                   actions: [
//                     TextButton(
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                         Navigator.of(context).pop();
//                       },
//                       child: const Text('Discard'),
//                     ),
//                     TextButton(
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                         _saveChangesAndNavigate();
//                       },
//                       child: const Text('Save'),
//                     ),
//                   ],
//                 );
//               },
//             );
//           } else {
//             Navigator.of(context).pop();
//           }
//         },
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Capacity Field
//               CustomFormField(
//                 controller: capacityController,
//                 labelText: 'Capacity',
//                 enabled: false,
//               ),
//               const SizedBox(height: 16),
//
//               // Remarks Field
//               CustomRemark(
//                 controller: remarksController,
//                 labelText: 'Remarks',
//               ),
//               const SizedBox(height: 24),
//
//               // Saved Items Lists
//               if (savedRectifierItems.isNotEmpty) ...[
//                 Text(
//                   'Saved Rectifier Items (${savedRectifierItems.length})',
//                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 ...savedRectifierItems.map((item) => Card(
//                   child: ListTile(
//                     title: Text(item['serialNumber'] ?? 'Unknown'),
//                     subtitle: Text('Status: ${item['status']} | Remarks: ${item['remarks']}'),
//                     trailing: IconButton(
//                       icon: const Icon(Icons.edit),
//                       onPressed: () {
//                         // Edit item logic
//                       },
//                     ),
//                   ),
//                 )),
//                 const SizedBox(height: 16),
//               ],
//
//               if (savedMPPTItems.isNotEmpty) ...[
//                 Text(
//                   'Saved MPPT Items (${savedMPPTItems.length})',
//                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 ...savedMPPTItems.map((item) => Card(
//                   child: ListTile(
//                     title: Text(item['serialNumber'] ?? 'Unknown'),
//                     subtitle: Text('Status: ${item['status']} | Remarks: ${item['remarks']}'),
//                     trailing: IconButton(
//                       icon: const Icon(Icons.edit),
//                       onPressed: () {
//                         // Edit item logic
//                       },
//                     ),
//                   ),
//                 )),
//                 const SizedBox(height: 16),
//               ],
//
//               if (savedCabinetItems.isNotEmpty) ...[
//                 Text(
//                   'Saved Cabinet Items (${savedCabinetItems.length})',
//                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 ...savedCabinetItems.map((item) => Card(
//                   child: ListTile(
//                     title: Text(item['serialNumber'] ?? 'Unknown'),
//                     subtitle: Text('Status: ${item['status']} | Remarks: ${item['remarks']}'),
//                     trailing: IconButton(
//                       icon: const Icon(Icons.edit),
//                       onPressed: () {
//                         // Edit item logic
//                       },
//                     ),
//                   ),
//                 )),
//                 const SizedBox(height: 16),
//               ],
//
//               // Next Button
//               const SizedBox(height: 32),
//               Center(
//                 child: ArrowButton(
//                   text: 'Next',
//                   onPressed: _navigateToBatteryScreen,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
