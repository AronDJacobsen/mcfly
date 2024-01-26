import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CameraApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraApp({super.key, required this.cameras});

  @override
  CameraAppState createState() => CameraAppState();
}

class CameraAppState extends State<CameraApp> {
  late CameraController cameraController;
  bool cameraIsLoading = true;
  //List<String> imagePaths = [];
  // add a notifier for imagePaths
  ValueNotifier<List<String>> imagePaths = ValueNotifier<List<String>>([]);
  late XFile imageLocation;

  @override
  void initState() {
    initializeCameraAndRecord();
    super.initState();
  }

  Future<void> initializeCameraAndRecord() async {
    await initCamera();
    captureImage();
  }

  Future<void> initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front);
    cameraController =
        CameraController(front, ResolutionPreset.max, enableAudio: false);
    // remove flash
    cameraController.setFlashMode(FlashMode.off);
    await cameraController.initialize();
    setState(() => cameraIsLoading = false);
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> captureImage() async {
    XFile imageLocation = await cameraController.takePicture();
    // add image path to imagePaths
    imagePaths.value = [...imagePaths.value, imageLocation.path];
    captureImage();
  }

  @override
  Widget build(BuildContext context) {
    print(imagePaths.value.length);
    if (cameraIsLoading) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      
      if (imagePaths.value.length > 100) {
        return ListView.builder(
          itemCount: imagePaths.value.length,
          itemBuilder: (context, index) {
            // Display the image
            return Image.file(File(imagePaths.value[index]));
          },
        );
      } else {
        return CameraPreview(cameraController);
      }
    }
  }
}
