import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;

void main() {
  runApp(const CameraAwesomeApp());
}

class CameraAwesomeApp extends StatelessWidget {
  const CameraAwesomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
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
  final _imageStreamController = StreamController<AnalysisImage>();
  double maxFramesPerSecond = 30;
  ValueNotifier<List<Uint8List>> jpegs = ValueNotifier<List<Uint8List>>([]);
  int currentIndex = 0;
  //List<double> _cachedFramerates = []
  bool showDelay = false;

  void updateFrame() {
    Future.delayed(Duration(milliseconds: (1000 / maxFramesPerSecond).round()),
        () {
      if (mounted) {
        setState(() {
          currentIndex = (currentIndex + 1) % jpegs.value.length;
        });
        showDelay
            ? updateFrame()
            : null; // This can be simplified to showDelay ? updateFrame()
      } else {
        print('not mounted');
      }
    });
  }

  @override
  void dispose() {
    _imageStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: !showDelay
          ? CameraAwesomeBuilder.analysisOnly(
              sensorConfig: SensorConfig.single(
                sensor: Sensor.position(SensorPosition.front),
                aspectRatio: CameraAspectRatios.ratio_1_1,
              ),
              // Trigger every time a new image is available, determined by the maxFramesPerSecond parameter
              onImageForAnalysis: (img) async =>
                  _imageStreamController.add(img),
              imageAnalysisConfig: AnalysisConfig(
                androidOptions: const AndroidAnalysisOptions.yuv420(
                  width: 150,
                ),
                maxFramesPerSecond: maxFramesPerSecond,
              ),
              builder: (state, preview) {
                return CameraPreviewDisplayer(
                  // return a AnalysisImage stream, which depends on the platform and the AnalysisConfig
                  analysisImageStream: _imageStreamController.stream,
                  jpegs: jpegs,
                );
              },
            )
          : ValueListenableBuilder(valueListenable: jpegs, builder: (context, value, child) {
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
                      jpegs.value[currentIndex],
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
          
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            showDelay = !showDelay;
            updateFrame();
            print(jpegs.value.length);
          });
        },
        child: !showDelay
            ? const Text('Playback')
            : const Text('Remove'),
      ),
    );
  }
}

class CameraPreviewDisplayer extends StatefulWidget {
  final Stream<AnalysisImage> analysisImageStream;
  final ValueNotifier<List<Uint8List>> jpegs;

  const CameraPreviewDisplayer({
    super.key,
    required this.analysisImageStream,
    required this.jpegs,
  });

  @override
  State<CameraPreviewDisplayer> createState() => _CameraPreviewDisplayerState();
}

class _CameraPreviewDisplayerState extends State<CameraPreviewDisplayer> {
  Uint8List? _cachedJpeg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StreamBuilder<AnalysisImage>(
        stream: widget.analysisImageStream,
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final img = snapshot.requireData;
          return img.when(jpeg: (image) {
            _cachedJpeg = _applyFilterOnBytes(image.bytes);
            // Add the current JPEG to the list
            widget.jpegs.value.add(_cachedJpeg!);
            return ImageAnalysisPreview(
              currentJpeg: _cachedJpeg!,
              width: image.width.toDouble(),
              height: image.height.toDouble(),
            );
          }, yuv420: (Yuv420Image image) {
            return FutureBuilder<JpegImage>(
                future: image.toJpeg(),
                builder: (_, snapshot) {
                  if (snapshot.data == null && _cachedJpeg == null) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else if (snapshot.data != null) {
                    _cachedJpeg = _applyFilterOnBytes(
                      snapshot.data!.bytes,
                    );
                  }
                  // Add the current JPEG to the list
                  widget.jpegs.value.add(_cachedJpeg!);

                  return ImageAnalysisPreview(
                    currentJpeg: _cachedJpeg!,
                    width: image.width.toDouble(),
                    height: image.height.toDouble(),
                  );
                });
          }, nv21: (Nv21Image image) {
            return FutureBuilder<JpegImage>(
                future: image.toJpeg(),
                builder: (_, snapshot) {
                  if (snapshot.data == null && _cachedJpeg == null) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else if (snapshot.data != null) {
                    _cachedJpeg = _applyFilterOnBytes(
                      snapshot.data!.bytes,
                    );
                  }
                  // Add the current JPEG to the list
                  widget.jpegs.value.add(_cachedJpeg!);
                  return ImageAnalysisPreview(
                    currentJpeg: _cachedJpeg!,
                    width: image.width.toDouble(),
                    height: image.height.toDouble(),
                  );
                });
          }, bgra8888: (Bgra8888Image image) {
            // Conversion from dart directly
            _cachedJpeg = _applyFilterOnImage(
              imglib.Image.fromBytes(
                width: image.width,
                height: image.height,
                bytes: image.planes[0].bytes.buffer,
                order: imglib.ChannelOrder.bgra,
              ),
            );
            // Add the current JPEG to the list
            widget.jpegs.value.add(_cachedJpeg!);
            return ImageAnalysisPreview(
              currentJpeg: _cachedJpeg!,
              width: image.width.toDouble(),
              height: image.height.toDouble(),
            );
          })!;
        },
      ),
    );
  }

  Uint8List _applyFilterOnBytes(Uint8List bytes) {
    return _applyFilterOnImage(imglib.decodeJpg(bytes)!);
  }

  Uint8List _applyFilterOnImage(imglib.Image image) {
    return imglib.encodeJpg(
      image, //imglib.billboard(image),
      quality: 20,
    );
  }
}

class ImageAnalysisPreview extends StatelessWidget {
  final double width;
  final double height;
  final Uint8List currentJpeg;

  const ImageAnalysisPreview({
    super.key,
    required this.currentJpeg,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
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
              currentJpeg,
              gaplessPlayback: true,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
