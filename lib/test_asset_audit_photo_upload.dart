// This is a test file to demonstrate the new Asset Audit Photo Upload system
// You can remove this file after testing

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/asset_audit_photo_upload_cubit.dart';
import 'utils/asset_audit_photo_upload_helper.dart';

class TestAssetAuditPhotoUpload extends StatelessWidget {
  const TestAssetAuditPhotoUpload({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Asset Audit Photo Upload'),
      ),
      body: BlocListener<AssetAuditPhotoUploadCubit, AssetAuditPhotoUploadState>(
        listener: (context, state) {
          if (state is AssetAuditPhotoUploadSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Photo uploaded successfully! ID: ${state.response.imgId}'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is AssetAuditPhotoUploadFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: ${state.errorMessage}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  // Example of how to use the helper
                  // Note: In a real app, you would get the file from image picker
                  print('Test button pressed - this demonstrates the new photo upload system');
                },
                child: const Text('Test Photo Upload System'),
              ),
              const SizedBox(height: 20),
              const Text(
                'The new Asset Audit Photo Upload system is now integrated!\n'
                'It uses the /api/v1/mobile/uploads endpoint.\n'
                'Check the CCU screen for implementation.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Example usage in other screens:
/*
// 1. Import the helper
import '../utils/asset_audit_photo_upload_helper.dart';

// 2. Use it in your photo upload logic
final photoId = await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
  photoFile: photoFile,
  schId: schId,
  imgId: imgId, // optional
  context: context,
);

// 3. Check if upload is in progress
if (AssetAuditPhotoUploadHelper.isUploading(context)) {
  // Show loading indicator
}

// 4. Get error messages
final errorMessage = AssetAuditPhotoUploadHelper.getLastErrorMessage(context);

// 5. Reset state if needed
AssetAuditPhotoUploadHelper.resetState(context);
*/
