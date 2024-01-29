import 'dart:io';
import 'dart:typed_data';

import 'package:another_xlider/another_xlider.dart';
import 'package:another_xlider/models/handler.dart';
import 'package:another_xlider/models/tooltip/tooltip.dart';
import 'package:another_xlider/models/trackbar.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as imglib;
import 'package:path_provider/path_provider.dart';

// Helper function to generate a timestamp for the image
String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

Future<void> compressAndSaveImage(Uint8List imageBytes, String processImagePath,
    int compressedQuality) async {
  // Compress the image using the flutter_image_compress package
  List<int> compressedBytes = await FlutterImageCompress.compressWithList(
    imageBytes,
    //minHeight: 1920, // Set the minimum height for the compressed image
    //minWidth: 1080, // Set the minimum width for the compressed image
    quality:
        compressedQuality, // Set the quality of the compressed image (0 to 100)
    rotate: 0, // Set the rotation of the compressed image
  );

  // Save the compressed image to the specified output path
  await File(processImagePath).writeAsBytes(compressedBytes);
}

Uint8List swapBGRtoRGB(Uint8List bgraData) {
  // Ensure that the length of the data is a multiple of 4 (BGRA8888)
  if (bgraData.length % 4 != 0) {
    throw ArgumentError('Invalid data length for BGRA8888 format');
  }

  // Iterate over each pixel (4 bytes per pixel)
  for (int i = 0; i < bgraData.length; i += 4) {
    // Swap the Blue (bgraData[i]) and Red (bgraData[i + 2]) channels
    int temp = bgraData[i];
    bgraData[i] = bgraData[i + 2];
    bgraData[i + 2] = temp;
  }

  return bgraData;
}

Future<String> generateAndSaveFakeImage(String name) async {
  // Given image bytes handle them
  Directory tempDir = await getTemporaryDirectory();
  // Create a save path
  String imageSavePath = '${tempDir.path}/$name.jpg';

  // Create a new image with dimensions 500x500
  imglib.Image image = imglib.Image(width: 10, height: 10);

  // Convert the image to bytes
  Uint8List imageBytes = Uint8List.fromList(imglib.encodeJpg(image));

  // Save the image to the specified output path
  await File(imageSavePath).writeAsBytes(imageBytes);

  return imageSavePath;
}

List<int> calculateCumulativeSums(List<int> numbers) {
  int sum = 0;

  // Use the fold function to calculate cumulative sums
  List<int> cumulativeSums = numbers.fold([], (List<int> result, int number) {
    sum += number; // Add the current number to the running sum
    result.add(sum); // Add the current cumulative sum to the result list
    return result;
  });

  return cumulativeSums;
}

int calculateCumulativeSum(List<int> numbers) {
  int sum = 0;

  // Use the fold function to calculate the cumulative sum
  int cumulativeSum = numbers.fold(0, (currentSum, number) {
    sum += number; // Add the current number to the running sum
    return currentSum + sum; // Return the updated cumulative sum
  });

  return cumulativeSum;
}

Future<(int, String)> createProcessedImagePath() async {
  /// Get the path
  // Get the current timestamp
  int timeStamp = DateTime.now().millisecondsSinceEpoch;
  int processSecond = timeStamp ~/ 1000;
  // Given image bytes handle them
  Directory tempDir = await getTemporaryDirectory();
  // Create a save path
  String currentImagePath =
      '${tempDir.path}/compr_img_${timeStamp.toString()}.jpg';
  return (processSecond, currentImagePath);
}

const myBlack = Color(0xff3c3c3c);
const myOpacity = 0.5;


FlutterSlider indicateLoadedSeconds(double loadedSeconds, double totalSeconds) {
  return FlutterSlider(
    rtl: true,
    //disabled: true,
    values: [loadedSeconds, 0],
    max: totalSeconds,
    min: 0,
    handler: FlutterSliderHandler(
      disabled: true,
      opacity: 0,
    ),
    rightHandler: FlutterSliderHandler(
      disabled: true,
      opacity: 0,
    ),
    tooltip: FlutterSliderTooltip(
      disabled: true,
    ),
    trackBar: FlutterSliderTrackBar(
      activeTrackBar: BoxDecoration(color: myBlack.withOpacity(myOpacity)),
      activeTrackBarDraggable: false,
      inactiveTrackBar: BoxDecoration(color: myBlack.withOpacity(0.15)),
    ),
  );
}
