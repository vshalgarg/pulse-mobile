import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:app/constants/save_file_in_device_storage.dart';
import 'package:open_file/open_file.dart';
import 'package:screenshot/screenshot.dart';

class ShowPainterImage extends StatelessWidget {
  final Uint8List image;

  //Create an instance of ScreenshotController
  final ScreenshotController screenshotController = ScreenshotController();

  ShowPainterImage(this.image, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Screenshot(
              controller: screenshotController,
              child: Image.memory(
                image,
              ),
            ),
          ),
          MaterialButton(
            color: Colors.white,
            onPressed: () async {
              // if screenshot is saving in phone's storage
              final fullPath = await SaveFileInDeviceStorage.saveDataInDeviceStorage(image);
              OpenFile.open(fullPath); // need storage runtime permission also

              // capture screenshot of image
              // await screenshotController.captureAndSave(
              //   fullPath, //set path where screenshot will be saved
              //   fileName: fileName,
              //   delay: const Duration(milliseconds: 10),
              // );

              /*screenshotController.capture().then((Uint8List? image) async {
                //Capture Done
                // if iUint8List mage is storing into phone's storage
                // final directory = (await getApplicationDocumentsDirectory()).path;
                bool dirDownloadExists = true;
                var directory;
                if (Platform.isIOS) {
                  directory = await getDownloadsDirectory();
                } else {
                  directory = "/storage/emulated/0/Download/";

                  dirDownloadExists = await Directory(directory).exists();
                  if (dirDownloadExists) {
                    directory = "/storage/emulated/0/Download";
                  } else {
                    directory = "/storage/emulated/0/Downloads";
                  }
                }
                final dir = await Directory('$directory/sample').create(recursive: true);
                if(!await dir.exists()){
                  return;
                }
                final fullPath = '$directory/sample/${DateTime.now().millisecondsSinceEpoch}.png';
                final imgFile = File('$fullPath');
                basename(imgFile.path);
                if (image != null) {
                  imgFile.writeAsBytesSync(image);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.only(left: 10),
                      content: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Image Exported successfully.", style: TextStyle(color: Colors.white)),
                          TextButton(
                            onPressed: () {
                              OpenFile.open(fullPath);
                            },
                            child: Text(
                              "Open",
                              style: TextStyle(
                                color: Colors.blue[200],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                }
              }).catchError((onError) {

              });*/

              // ScaffoldMessenger.of(context).showSnackBar(
              //   SnackBar(
              //     backgroundColor: Colors.grey[700],
              //     padding: const EdgeInsets.only(left: 10),
              //     content: Row(
              //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //       children: [
              //         const Text("Image Exported successfully.", style: TextStyle(color: Colors.white)),
              //         TextButton(
              //           onPressed: () {
              //             OpenFile.open(path);
              //           },
              //           child: Text(
              //             "Open",
              //             style: TextStyle(
              //               color: Colors.blue[200],
              //             ),
              //           ),
              //         )
              //       ],
              //     ),
              //   ),
              // );
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }
}
