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
  // a controller to show the live camera preview on the screen
  late CameraController cameraController;
  bool cameraIsLoading = true;
  // for storing videos
  List<String> videoPaths = [];
  List<VideoPlayerController> videoControllers = [];
  bool isRecording = false;
  Timer? recordTimer;

  @override
  void initState() {
    // Initialize the camera controller when the widget is initialized
    initializeCameraAndRecord();
    super.initState();
  }

  Future<void> initializeCameraAndRecord() async {
    // Initialize the camera
    await initCamera();

    // Start recording the 1-second videos
    recordVideo();
  }

  initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front);
    cameraController =
        CameraController(front, ResolutionPreset.max, enableAudio: false);
    await cameraController.initialize();
    setState(() => cameraIsLoading = false);
  }

  @override
  void dispose() {
    recordTimer?.cancel();
    // Dispose of the camera controller when the widget is disposed
    cameraController.dispose();
    super.dispose();
  }


  // Method to record a 1-second video, it is a recursive method
  Future<void> recordVideo() async {
    if (isRecording) {
      final file = await cameraController.stopVideoRecording();
      // Create a VideoPlayerController to play the video, without audio
      VideoPlayerController videoPlayerController = VideoPlayerController.file(
        File(
          file.path,
        ),
      );
      await videoPlayerController.initialize();
      setState(() {
        isRecording = false;
        videoPaths.insert(0, file.path);
        videoControllers.insert(0, videoPlayerController);
        _deleteOldestVideoIfNeeded();
      });
    } else {
      await cameraController.prepareForVideoRecording();
      await cameraController.startVideoRecording();
      setState(() {
        isRecording = true;
        recordTimer = Timer(const Duration(seconds: 1), () {
          recordVideo(); // Automatically stop recording after 1 second
        });
      });
    }
  }

  // Method to delete the oldest video when the limit is reached
  void _deleteOldestVideoIfNeeded() {
    if (videoPaths.length > 60) {
      final oldestVideoPath = videoPaths.removeAt(0);
      File(oldestVideoPath).delete(); // Delete the oldest video file
      videoControllers.removeAt(59); // check this
    }
  }

  @override
  Widget build(BuildContext context) {
    print(videoPaths.length);
    if (cameraIsLoading) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      if (videoPaths.length > 3) {
        print('here');
        //if (1 == 0) {
        return FutureBuilder(
          future: videoControllers[1].play(),
          //future: videoControllers[0].initialize(),

          builder: (context, state) {
            if (state.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else {
              return VideoPlayer(videoControllers[0]);
            }
          },
        );
      } else {
        return CameraPreview(cameraController);
      }
    }
  }
}
