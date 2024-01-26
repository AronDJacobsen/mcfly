import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

//import 'package:mcfly/video_collections.dart';
//import 'package:mcfly/image_collections.dart';
//import 'package:mcfly/ffmpeg_package.dart';
import 'package:mcfly/camera_stream.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Obtain a list of available cameras on the device
  List<CameraDescription> cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraApp(cameras: cameras),
    );
  }
}




