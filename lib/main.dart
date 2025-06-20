// Dart packages
import 'dart:async';
import 'dart:collection';
import 'dart:io';
//import 'dart:typed_data';
import 'dart:ui';
//import 'dart:typed_data';

// Flutter packages
import 'package:another_xlider/another_xlider.dart';
import 'package:another_xlider/models/handler.dart';
//import 'package:another_xlider/models/hatch_mark.dart';
//import 'package:another_xlider/models/hatch_mark_label.dart';
import 'package:another_xlider/models/ignore_steps.dart';
import 'package:another_xlider/models/tooltip/tooltip.dart';
import 'package:another_xlider/models/tooltip/tooltip_box.dart';
import 'package:another_xlider/models/tooltip/tooltip_position_offset.dart';
import 'package:another_xlider/models/trackbar.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_image_compress/flutter_image_compress.dart';
//import 'package:image/image.dart' as imglib;
//import 'package:path_provider/path_provider.dart';

// Directory packages
import 'utilities.dart';

/*
See this:
https://blog.codemagic.io/live-object-detection-on-image-stream-in-flutter/

*/

const myBlack = Color(0xff3c3c3c);
const myRed = Color(0xfff84c54);
const myOpacity = 0.4;

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
  ////// Camera Awesome related: //////
  late CameraAwesomeBuilder previewBuilder;
  late CameraAwesomeBuilder analysisBuilder;
  final _imageStreamController = StreamController<AnalysisImage>();
  Widget progressIndicator = const Center(
    child: SizedBox(
      width: 120,
      height: 120,
      child: CircularProgressIndicator(
        color: myBlack,
      ),
    ),
  );
  ////// Video related: //////
  int resolutionWidth = 720; // 720p, 1080p
  double maxFramesPerSecond = 30;
  int jpegQuality = 70;
  int compressedQuality = 20;
  int totalDelaySeconds = 10 + 1;
  late double totalUserDelaySeconds;

  ////// Storage related: //////
  // Keep track of the previous image path (for imagePaths)
  String previousImagePath = '';
  int previousSecond = 0;

  ////// Delay functionality related: //////
  // Image paths - second to paths
  // Note: then delay functionality is seconds based
  //   - we can ensure we rebase each second
  //   - we can calculate frames per second
  //   - we can the desired delay from the slider
  LinkedHashMap<int, List<String>> imagePaths = LinkedHashMap();
  // The seconds delay logic, talks to the slider
  // Then one second points to the next, but also index based to select the delay
  LinkedHashMap<int, int> delaySeconds = LinkedHashMap();
  // The current delay: live/delay/waiting, talks to the preview
  // Note:
  //   0: the live view
  //   all other: the delay view (defined by a second)
  ValueNotifier<int> delaySecond = ValueNotifier<int>(0);
  ValueNotifier<String> delayFramePath = ValueNotifier<String>('');
  // The loaded seconds
  double loaded = 0;
  // If user wants a delay longer than the loaded seconds, we need to wait
  bool waiting = false;
  // The delay seconds
  double nDelaySeconds = 0;
  double _lowerValue = 0;

  @override
  void initState() {
    super.initState();
    totalUserDelaySeconds = totalDelaySeconds - 1;
    //initStartImage();
    // Pre-defined camera configurations
    SensorConfig sensorConfig = SensorConfig.single(
      sensor: Sensor.position(SensorPosition.front),
      aspectRatio: CameraAspectRatios.ratio_1_1,
    );
    AnalysisConfig analysisConfig = AnalysisConfig(
      maxFramesPerSecond: maxFramesPerSecond,
      androidOptions: AndroidAnalysisOptions.yuv420(
        width: resolutionWidth,
      ),
    );
    previewBuilder = CameraAwesomeBuilder.previewOnly(
      sensorConfig: sensorConfig,
      // Show a progress indicator while loading the camera
      progressIndicator: progressIndicator,
      // Trigger every time a new image is available
      onImageForAnalysis: (img) async => processImage(img),
      imageAnalysisConfig: analysisConfig,

      builder: (state, preview) {
        //int waitingSeconds = (nDelaySeconds - loaded).toInt();
        //print(waitingSeconds);
        // Check if live preview or waiting for the delay to catch up
        return const SizedBox.shrink();
      },
    );

    analysisBuilder = CameraAwesomeBuilder.analysisOnly(
      sensorConfig: sensorConfig,
      // Show a progress indicator while loading the camera
      progressIndicator: progressIndicator,
      // Trigger every time a new image is available
      onImageForAnalysis: (img) async => processImage(img),
      imageAnalysisConfig: analysisConfig,
      builder: (state, preview) {
        return ValueListenableBuilder(
            valueListenable: delayFramePath,
            builder: (BuildContext context, String value, Widget? child) {
              return displayDelay();
            });
      },
    );
  }

  Widget waitingView() {
    // Add a BackdropFilter widget to create the blur effect
    int waitingSeconds = (nDelaySeconds - loaded).toInt();
    // Display the waiting view
    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 10, sigmaY: 10), // Adjust the blur intensity as needed
          child: Container(
            color: myBlack.withOpacity(0.1), // Adjust the opacity as needed
          ),
        ),
        // Add visible text on top of the blur
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Text(
                "$waitingSeconds sec.",
                style: const TextStyle(
                  fontSize: 24,
                  color: myBlack, //myBlack,//.withOpacity(myOpacity),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            // a progress indicator
            progressIndicator,
          ],
        ),
      ],
    );
  }

  Widget displayDelay() {
    // Display the delay
    return ValueListenableBuilder(
        valueListenable: delayFramePath,
        builder: (BuildContext context, String value, Widget? child) {
          return Container(
            color: myBlack,
            child: SizedBox.expand(
              child: Image.file(
                File(delayFramePath.value),
                gaplessPlayback: true,
                fit: BoxFit.cover,
              ),
            ),
          );
        });
  }

  void precacheSecond(second) async {
    // Pre-cache the frames
    List<String> delaySecondFrames = imagePaths[second]!;
    // Iterate the frames
    for (int i = 0; i < delaySecondFrames.length; i++) {
      // Get the frame path
      String framePath = delaySecondFrames[i];
      // Precache the image
      //imageCache.clear();
      precacheImage(FileImage(File(framePath)), context);
    }
  }

  void startOneSecondDelay(int thisDelaySecond, int recalibrate) async {
    // Get the time now
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    // Precache the next second frames
    precacheSecond(thisDelaySecond + 1);
    // Start to display the delay for current second
    final delaySecondFrames = imagePaths[thisDelaySecond]!;
    if (delaySecondFrames.isEmpty) {
      // Handle empty frames list
      print('Empty frames list');
      return;
    }
    // Calculate the frame duration based on FPS
    final frameDuration = Duration(
        milliseconds: (1000 - recalibrate) ~/ delaySecondFrames.length);

    // Start the delay
    for (int i = 0; i < delaySecondFrames.length; i++) {
      // Get the frame path
      delaySecond.value = thisDelaySecond;
      delayFramePath.value = delaySecondFrames[i];
      // Precache the image
      //precacheImage(FileImage(File(framePath)), context);
      // Wait for the frame duration
      await Future.delayed(frameDuration);
      // However, check if the delay was cancelled
      if (delaySecond.value != thisDelaySecond) {
        // The delay was cancelled, exit the function vall
        return;
      }
    }
    // Check time elapsed, after 1 second
    int timeElapsed = DateTime.now().millisecondsSinceEpoch - timeStamp;
    // The delay is over, reset the delay
    // TODO: ~90 milliseconds off every time!
    startOneSecondDelay(thisDelaySecond + 1, timeElapsed - 1000);
  }

  @override
  void dispose() {
    _imageStreamController.close();
    super.dispose();
  }

  /// ################
  ///
  /// The build method
  ///
  /// ################
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Display the camera preview or the analysis (waiting or delay)
      body: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: delaySecond,
            builder: (BuildContext context, int value, Widget? child) {
              if (delaySecond.value > 0) {
                return analysisBuilder;
              } else {
                return previewBuilder;
              }
            },
          ),
          waiting ? waitingView() : const SizedBox.shrink(),
          showCurrentDelay(),
          videoBarController(),
        ],
      ),
    );
  }

  Positioned showCurrentDelay() {
    return Positioned(
      top: 35, // Position at the top
      left: 0, // You can adjust left if needed
      right: 0, // You can adjust right if needed
      child: Center(
        child: Container(
          width: 85, // Adjust the width as needed
          height: 35,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: myBlack
                  .withOpacity(myOpacity)), // Adjust the height as needed
          child: Center(
            child: Text(
              '${nDelaySeconds.toInt()} sec.',
              style: const TextStyle(color: Colors.white), // Text style
            ),
          ),
        ),
      ),
    );
  }

  void setADelay(int setThisDelaySeconds) {
    // Manage views based on the delay
    if (setThisDelaySeconds == -1) {
      waiting = false;
      // live view
      delaySecond.value = 0;
      // note 0 is a 1 second delay, since we use keys in delaySeconds (but can be an unfortunate 1.999.. delay)
    } else if (setThisDelaySeconds <= loaded) {
      waiting = false;
      // delay view
      List<int> delaySecondsList = delaySeconds.keys.toList();
      int nDelaySecondIdentifier =
          delaySecondsList[loaded.toInt() - setThisDelaySeconds];
      // Precache the next second frames
      precacheSecond(nDelaySecondIdentifier);
      // Start the delay
      startOneSecondDelay(nDelaySecondIdentifier, 0);
      // check
    } else {
      // waiting view
      waiting = true;
    }
    // Finally clear the cache, TODO??? work and ok???
    imageCache.clear();
  }

  Column videoBarController() {
    //double totalSeconds = keepSeconds.toDouble();
    //double loadedSeconds = nFramesInSecond.length.toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          children: [
            indicateLoadedSeconds(
                loaded.toDouble(), totalUserDelaySeconds.toDouble()),
            FlutterSlider(
              rtl: true,
              values: [_lowerValue],
              max: totalUserDelaySeconds.toDouble(),
              min: 0,
              onDragging: (handlerIndex, lowerValue, upperValue) {
                _lowerValue = lowerValue;
              },
              //onDragStarted: (handlerIndex, lowerValue, upperValue) => {
              //  nDelaySeconds = lowerValue,
              //},
              onDragCompleted: (handlerIndex, lowerValue, upperValue) {
                //secondsDelay = -lowerValue;
                setState(
                  () {
                    nDelaySeconds = lowerValue;
                    setADelay(nDelaySeconds.toInt() - 1);
                  },
                );
              },
              ignoreSteps: [FlutterSliderIgnoreSteps(from: 1, to: 1)],
              handler: FlutterSliderHandler(
                child: const Icon(
                  Icons.circle,
                  size: 12,
                  color: Colors.white,
                ),
                // decrease size of handler
                decoration: const BoxDecoration(),
              ),
              tooltip: FlutterSliderTooltip(
                //disabled: true,
                textStyle: const TextStyle(color: Colors.white),
                format: (String value) {
                  return '${double.parse(value).toInt()} sec.';
                },
                positionOffset: FlutterSliderTooltipPositionOffset(top: 0),
                boxStyle: FlutterSliderTooltipBox(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: myBlack.withOpacity(0.3)),
                ),
              ),
              trackBar: FlutterSliderTrackBar(
                activeTrackBar:
                    BoxDecoration(color: Colors.blue.withOpacity(0)),
                inactiveTrackBar:
                    BoxDecoration(color: Colors.blue.withOpacity(0)),
              ),
              /*
              hatchMark: FlutterSliderHatchMark(
                density: 0.5,
                labelsDistanceFromTrackBar: -30,
                labels: [FlutterSliderHatchMarkLabel(percent: 0, label: const Text('Live')),
                FlutterSliderHatchMarkLabel(percent: 100, label: Text("${totalUserDelaySeconds.toInt().toString()}\nsec.")),]
              ),
              */
            ),
          ],
        ),
        const SizedBox(
          height: 20,
        ),
      ],
    );
  }

  void processImage(AnalysisImage img) {
    img.when(
      jpeg: (image) {
        saveImageAndupdateVariables(image.bytes);
      },
      yuv420: (image) async {
        final jpeg = await image.toJpeg(quality: jpegQuality);
        saveImageAndupdateVariables(jpeg.bytes);
      },
      nv21: (image) async {
        final jpeg = await image.toJpeg(quality: jpegQuality);
        saveImageAndupdateVariables(jpeg.bytes);
      },
      bgra8888: (image) async {
        image.planes[0].bytes = swapBGRtoRGB(image.planes[0].bytes);
        final jpeg = await image.toJpeg(quality: jpegQuality);
        saveImageAndupdateVariables(jpeg.bytes);
      },
    );
  }

  Future<void> saveImageAndupdateVariables(bytes) async {
    // Get the path
    var (processSecond, processImagePath) = await createProcessedImagePath();
    // Save
    compressAndSaveImage(bytes, processImagePath, compressedQuality);
    // Update variables
    updateVariablesWithFrame(processSecond, processImagePath);
  }

  void updateVariablesWithFrame(processSecond, processImagePath) {
    /// Update the variables
    // Get the current timestamp
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    int processSecond = timeStamp ~/ 1000;
    // Check if current second is present

    if (imagePaths.containsKey(processSecond)) {
      // Present
      imagePaths[processSecond]!.add(processImagePath);
    } else {
      // New second
      imagePaths[processSecond] = [processImagePath];
      // Create the chain of seconds
      delaySeconds[previousSecond] = processSecond;
      // Perform memory management
      memoryManagement();
    }
    // Update variable
    previousSecond = processSecond;
    // Trigger a rebuild to update the UI
    setState(() {});
  }

  void memoryManagement() async {
    /// Manage the memory
    // Delete if we have more than totalDelaySeconds (based on the delaySeconds)
    if (delaySeconds.keys.length > totalDelaySeconds) {
      // Get the oldest second
      int oldestSecond = imagePaths.keys.first;
      // Delete the oldest second
      deleteThisSecond(oldestSecond);
    } else if (delaySeconds.isNotEmpty) {
      // Else perform some clean up and inform the user about the loaded seconds
      if (delaySeconds.keys.first == 0) {
        if (delaySeconds.length == 3) {
          // ensure we have 3 seconds registered
          // We want to delete the first dummy value 0 and the first second
          fixInitialization();
        }
      } else {
        // start updating the loaded seconds
        updateLoader();
      }
    }
  }

  void deleteThisSecond(int thisSecond) {
    List<String> oldestSecondFrames = imagePaths[thisSecond]!;
    // Deleting all the frames in the oldest second
    for (int i = 0; i < oldestSecondFrames.length; i++) {
      // First delete the oldest saved image
      String oldestFrame = oldestSecondFrames[i];
      // check if the file exists then delete
      if (File(oldestFrame).existsSync()) {
        File(oldestFrame).deleteSync();
      } else {
        // TODO: why?
        print('File does not exist');
      }

      // Finally delete this second within the variables
      imagePaths.remove(thisSecond);
      delaySeconds.remove(thisSecond);
    }
  }

  void fixInitialization() {
    // We want to delete the first dummy value 0 and the first second
    int firstRealSecond = delaySeconds.keys.elementAt(1);
    // Delete then in delaySeconds
    delaySeconds.remove(0);
    delaySeconds.remove(firstRealSecond);
    // Delete them in imagePaths
    imagePaths.remove(firstRealSecond);
  }

  void updateLoader() {
    setState(() {
      loaded = delaySeconds.length.toDouble() - 1;
      // Set the loaded seconds
      if (loaded < nDelaySeconds) {
        // Set the delay to live
        waiting = true;
      } else if (loaded == nDelaySeconds) {
        // Set the delay to live
        setADelay(nDelaySeconds.toInt());
        waiting = false;
      }
    });
  }
}
