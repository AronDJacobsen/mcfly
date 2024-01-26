import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
// Removed unused import 'package:image/image.dart'.

void main() {
  runApp(const CameraAwesomeApp());
}

class CameraAwesomeApp extends StatelessWidget {
  const CameraAwesomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CamerAwesome App - Filter example',
      home: CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraAwesomeBuilder previewBuilder;
  late CameraAwesomeBuilder analysisBuilder;
  final _imageStreamController = StreamController<AnalysisImage>();
  double maxFramesPerSecond = 20;
  //ValueNotifier<List<Uint8List>> jpegs = ValueNotifier<List<Uint8List>>([]);
  List<Uint8List> jpegs = [];
  ValueNotifier<int> currentIndex = ValueNotifier<int>(0);
  //int currentIndex = 0;

  //List<double> _cachedFramerates = []
  bool showDelay = false;

  void updateFrame() {
    Future.delayed(Duration(milliseconds: (1000 / maxFramesPerSecond).round()),
        () {
      //setState(() {
      //  currentIndex.value = (currentIndex.value + 1) % jpegs.length;
      //});

      currentIndex.notifyListeners();
      //currentIndex.value = currentIndex.value;//(currentIndex.value + 1) % jpegs.length;

      // Stop calling updateFrame() if we are not showing the delay
      showDelay
          ? updateFrame()
          : null; // This can be simplified to showDelay ? updateFrame()
    });
  }

  int seconds2frameidx(int seconds) {
    // given seconds calculate the most probably frame index
    return seconds * maxFramesPerSecond.toInt();
  }

  @override
  void dispose() {
    _imageStreamController.close();
    super.dispose();
  }

  @override
  void initState() {
    previewBuilder = CameraAwesomeBuilder.previewOnly(
      sensorConfig: SensorConfig.single(
        sensor: Sensor.position(SensorPosition.front),
        aspectRatio: CameraAspectRatios.ratio_1_1,
      ),
      // Preview fit of the camera
      //previewFit: CameraPreviewFit.fitWidth,
      // Show a progress indicator while loading the camera
      progressIndicator: const Center(
        child: SizedBox(
          width: 100,
          height: 100,
          child: CircularProgressIndicator(),
        ),
      ),
      // Trigger every time a new image is available
      onImageForAnalysis: (img) async => processImage(img),
      imageAnalysisConfig: AnalysisConfig(
        androidOptions: const AndroidAnalysisOptions.yuv420(
          width: 150,
        ),
        maxFramesPerSecond: maxFramesPerSecond,
      ),

      builder: (state, preview) {
        return const SizedBox.shrink();
      },
    );

    analysisBuilder = CameraAwesomeBuilder.analysisOnly(
      sensorConfig: SensorConfig.single(
        sensor: Sensor.position(SensorPosition.front),
        aspectRatio: CameraAspectRatios.ratio_1_1,
      ),
      // Preview fit of the camera
      //previewFit: CameraPreviewFit.fitWidth,
      // Show a progress indicator while loading the camera
      progressIndicator: const Center(
        child: SizedBox(
          width: 100,
          height: 100,
          child: CircularProgressIndicator(),
        ),
      ),
      // Trigger every time a new image is available
      onImageForAnalysis: (img) async => processImage(img),
      imageAnalysisConfig: AnalysisConfig(
        androidOptions: const AndroidAnalysisOptions.yuv420(
          width: 150,
        ),
        maxFramesPerSecond: maxFramesPerSecond,
      ),

      builder: (state, preview) {
        return ValueListenableBuilder(
          valueListenable: currentIndex,
          builder: (BuildContext context, int value, Widget? child) {
            return delayedView();
          },
        );
      },
    );

    super.initState();
  }

  Widget delayedView() {
    return Container(
      color: Colors.black,
      child: Transform.scale(
        scaleX: Platform.isAndroid ? -1 : 1, // TODO? ios had null
        child: Transform.rotate(
          angle: Platform.isAndroid
              ? 3 / 2 * pi
              : 0, // TODO: different for android?
          child: SizedBox.expand(
            child: Image.memory(
              jpegs[currentIndex.value],
              gaplessPlayback: true,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: !showDelay ? previewBuilder : analysisBuilder,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: 200,
        height: 100,
        child: FloatingActionButton(
          onPressed: () {
            setState(() {
              showDelay = !showDelay;
              currentIndex.value = seconds2frameidx(3);
              updateFrame();
              print(jpegs.length);
            });
          },
          child: !showDelay
              ? const Text('See 3 second delay')
              : const Text('See Live Feed'),
        ),
      ),
    );
  }

  void processImage(AnalysisImage img) {
    // TODO: decode images?

    img.when(
      jpeg: (image) {
        //jpegs.add(image.bytes);
        jpegs.insert(0, image.bytes);
      },
      yuv420: (image) async {
        final jpeg = await image.toJpeg();
        //jpegs.add(jpeg.bytes);
        jpegs.insert(0, jpeg.bytes);
      },
      nv21: (image) async {
        final jpeg = await image.toJpeg();
        //jpegs.add(jpeg.bytes);
        jpegs.insert(0, jpeg.bytes);
      },
      bgra8888: (image) async {
        final jpeg = await image.toJpeg();
        //jpegs.add(jpeg.bytes);
        // TODO: have to flip color channels to get correct colors
        /*
        final jpeg = imglib.encodeJpg((imglib.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: image.planes[0].bytes.buffer,
          order:  imglib.ChannelOrder.bgra,
        ));
        */
        jpegs.insert(0, jpeg.bytes);
      },
    );

    // Add memory management
    if (jpegs.length > 80) {
      jpegs.removeLast();
    }
  }
}
