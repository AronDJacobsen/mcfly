import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

// A screen that allows users to take a picture using a given camera.
class CameraApp extends StatefulWidget {
  const CameraApp({
    super.key,
    required this.cameras,
  });

  final List<CameraDescription> cameras;

  @override
  CameraAppState createState() => CameraAppState();
}

class CameraAppState extends State<CameraApp> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late Image image;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    final front = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front);
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      front,
      // Define the resolution to use.
      ResolutionPreset.medium,
      enableAudio: false,
      // Set the format group of the image
      //imageFormatGroup: ImageFormatGroup.jpeg,
    );

    // Initialize the controller
    _initializeControllerFuture = _controller.initialize();

    // Start streaming the camera
    _initializeControllerFuture.then((_) {
      _controller.startImageStream((CameraImage cameraImage) {
        

        setState(() {
          image = image;
        });
      });
    });
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            //return const Center(
            //    child: Text('Camera is ready')); //CameraPreview(_controller);
            //return Texture(
            //  textureId: _controller.cameraId,
            //);
            return Container();//Center(child: image);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
