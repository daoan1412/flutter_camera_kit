import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'CameraKitController.dart';

enum CameraFlashMode { on, off, auto }
enum ScaleTypeMode { fit, fill }
enum BarcodeFormats {
  FORMAT_ALL_FORMATS,
  FORMAT_CODE_128,
  FORMAT_CODE_39,
  FORMAT_CODE_93,
  FORMAT_CODABAR,
  FORMAT_DATA_MATRIX,
  FORMAT_EAN_13,
  FORMAT_EAN_8,
  FORMAT_ITF,
  FORMAT_QR_CODE,
  FORMAT_UPC_A,
  FORMAT_UPC_E,
  FORMAT_PDF417,
  FORMAT_AZTEC
}
enum CameraPosition { back, front }

// ignore: must_be_immutable
class CameraKitView extends StatefulWidget {
  /// In barcodeReader mode, while camera preview detect barcodes, This method is called.
  final Function onBarcodeRead;

  ///After android and iOS user deny run time permission, this method is called.
  final Function onPermissionDenied;

  ///There are 2 modes `ScaleTypeMode.fill` and `ScaleTypeMode.fit` for this parameter.
  ///If you want camera preview fill your widget area, use `fill` mode. In this mode, camera preview may be croped for filling widget area.
  ///If you want camera preview to show entire lens preview, use `fit` mode. In this mode, camera preview may be shows blank areas.
  final ScaleTypeMode scaleType;

  ///True means scan barcode mode and false means take picture mode
  ///Because of performance reasons, you can't use barcode reader mode and take picture mode simultaneously.
  final bool hasBarcodeReader;

  ///This parameter accepts 3 values. `CameraFlashMode.auto`, `CameraFlashMode.on` and `CameraFlashMode.off`.
  /// For changing value after initial use `changeFlashMode` method in controller.
  final CameraFlashMode previewFlashMode;

  ///Set barcode format from available values, default value is FORMAT_ALL_FORMATS
  final BarcodeFormats barcodeFormat;

  ///Controller for this widget
  final CameraKitController cameraKitController;

  ///For fixing problem with flash In old phones like Samsung S6, switch between CameraAPI and Camera2 API. Set this parameter false
  ///Barcode scanning not support from this. Default value is true.
  final bool useCamera2API;

  final CameraPosition cameraPosition;
  final bool hasFaceDetection;
  final Function onFaceDetectionMsgCallBack;
  final Function onFaceImageCallBack;

  _BarcodeScannerViewState viewState;

  CameraKitView(
      {Key key,
      this.hasBarcodeReader = false,
      this.scaleType = ScaleTypeMode.fill,
      this.onBarcodeRead,
      this.hasFaceDetection = false,
      this.barcodeFormat = BarcodeFormats.FORMAT_ALL_FORMATS,
      this.previewFlashMode = CameraFlashMode.auto,
      this.cameraKitController,
      this.onPermissionDenied,
      this.cameraPosition = CameraPosition.back,
      this.onFaceDetectionMsgCallBack,
      this.onFaceImageCallBack,
      this.useCamera2API = true})
      : super(key: key);

  dispose() {
    viewState.disposeView();
  }

  @override
  State<StatefulWidget> createState() {
    if (cameraKitController != null) cameraKitController.setView(this);
    viewState = _BarcodeScannerViewState();
    return viewState;
  }
}

class _BarcodeScannerViewState extends State<CameraKitView>
    with WidgetsBindingObserver {
  NativeCameraKitController controller;
  VisibilityDetector visibilityDetector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (defaultTargetPlatform == TargetPlatform.android) {
      visibilityDetector = VisibilityDetector(
          key: Key('visible-camerakit-key-1'),
          onVisibilityChanged: (visibilityInfo) {
            if (controller != null) {
              if (visibilityInfo.visibleFraction == 0)
                controller.setCameraVisible(false);
              else
                controller.setCameraVisible(true);
            }
          },
          child: AndroidView(
            viewType: 'plugins/camera_kit',
            onPlatformViewCreated: _onPlatformViewCreated,
          ));
    } else {
      visibilityDetector = VisibilityDetector(
          key: Key('visible-camerakit-key-1'),
          onVisibilityChanged: (visibilityInfo) {
            if (visibilityInfo.visibleFraction == 0)
              controller.setCameraVisible(false);
            else
              controller.setCameraVisible(true);
          },
          child: UiKitView(
            viewType: 'plugins/camera_kit',
            onPlatformViewCreated: _onPlatformViewCreated,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return visibilityDetector;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        print("Flutter Life Cycle: resumed");
        if (controller != null) controller.resumeCamera();
        break;
      case AppLifecycleState.inactive:
        print("Flutter Life Cycle: inactive");
        if (Platform.isIOS) {
          controller.pauseCamera();
        }
        break;
      case AppLifecycleState.paused:
        print("Flutter Life Cycle: paused");
        controller.pauseCamera();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    this.controller = new NativeCameraKitController._(id, context, widget);
    this.controller.initCamera();
  }

  void disposeView() {
    controller.dispose();
  }
}

///View State controller. User works with CameraKitController
///and CameraKitController Works with this controller.
class NativeCameraKitController {
  BuildContext context;
  CameraKitView widget;

  NativeCameraKitController._(int id, this.context, this.widget)
      : _channel = new MethodChannel('plugins/camera_kit_' + id.toString());

  final MethodChannel _channel;

  Future<dynamic> nativeMethodCallHandler(MethodCall methodCall) async {
    if (methodCall.method == "onBarcodeRead") {
      if (widget.onBarcodeRead != null)
        widget.onBarcodeRead(methodCall.arguments);
    }

    if (methodCall.method == "onFaceDetectionMsgCallBack" &&
        widget.onFaceDetectionMsgCallBack != null) {
      widget.onFaceDetectionMsgCallBack(methodCall.arguments);
    }

    if (methodCall.method == "onFaceImageCallBack" &&
        widget.onFaceImageCallBack != null) {
      widget.onFaceImageCallBack(methodCall.arguments);
    }

    return null;
  }

  bool _getScaleTypeMode(ScaleTypeMode scaleType) {
    if (scaleType == ScaleTypeMode.fill)
      return true;
    else
      return false;
  }

  String _getCharFlashMode(CameraFlashMode cameraFlashMode) {
    String flashMode;
    switch (cameraFlashMode) {
      case CameraFlashMode.auto:
        flashMode = "A";
        break;
      case CameraFlashMode.on:
        flashMode = "O";
        break;
      case CameraFlashMode.off:
        flashMode = "F";
        break;
    }
    return flashMode;
  }

  String _getCharCameraPosition(CameraPosition cameraPosition) {
    String pos;
    switch (cameraPosition) {
      case CameraPosition.back:
        pos = "B";
        break;
      case CameraPosition.front:
        pos = "F";
        break;
    }
    return pos;
  }

  void initCamera() async {
    _channel.setMethodCallHandler(nativeMethodCallHandler);
    _channel.invokeMethod('requestPermission').then((value) {
      if (value) {
        if (Platform.isAndroid) {
          _channel.invokeMethod('initCamera', {
            "hasBarcodeReader": widget.hasBarcodeReader,
            "flashMode": _getCharFlashMode(widget.previewFlashMode),
            "isFillScale": _getScaleTypeMode(widget.scaleType),
            "barcodeMode": _getBarcodeModeValue(widget.barcodeFormat),
            "useCamera2API": widget.useCamera2API,
            "cameraPosition": _getCharCameraPosition(widget.cameraPosition),
            "hasFaceDetection": widget.hasFaceDetection
          });
        } else {
          _channel.invokeMethod('initCamera', {
            "hasBarcodeReader": widget.hasBarcodeReader,
            "flashMode": _getCharFlashMode(widget.previewFlashMode),
            "isFillScale": _getScaleTypeMode(widget.scaleType),
            "barcodeMode": _getBarcodeModeValue(widget.barcodeFormat),
            "cameraPosition": _getCharCameraPosition(widget.cameraPosition),
            "hasFaceDetection": widget.hasFaceDetection
          });
        }
      } else {
        widget.onPermissionDenied();
      }
    });
  }

  ///Call resume camera in Native API
  Future<void> resumeCamera() async {
    return _channel.invokeMethod('resumeCamera');
  }

  ///Call pause camera in Native API
  Future<void> pauseCamera() async {
    return _channel.invokeMethod('pauseCamera');
  }

  ///Call close camera in Native API
  Future<void> closeCamera() {
    return _channel.invokeMethod('closeCamera');
  }

  ///Call take picture in Native API
  Future<String> takePicture() async {
    return _channel.invokeMethod('takePicture', null);
  }

  ///Call change flash mode in Native API
  Future<void> changeFlashMode(CameraFlashMode captureFlashMode) {
    return _channel.invokeMethod(
        'changeFlashMode', {"flashMode": _getCharFlashMode(captureFlashMode)});
  }

  ///Call dispose in Native API
  Future<void> dispose() {
    return _channel.invokeMethod('dispose', "");
  }

  ///Call set camera visible in Native API.
  ///This API is used to automatically manage pause and resume camera
  Future<void> setCameraVisible(bool isCameraVisible) {
    return _channel
        .invokeMethod('setCameraVisible', {"isCameraVisible": isCameraVisible});
  }

  Future<void> setFaceDetectionStrategy(
      int minX, int maxX, int minY, int maxY, int minZ, maxZ) {
    return _channel.invokeMethod("setFaceDetectionStrategy", {
      'minX': minX,
      'maxX': maxX,
      'minY': minY,
      'maxY': maxY,
      'minZ': minZ,
      'maxZ': maxZ
    });
  }

  int _getBarcodeModeValue(BarcodeFormats barcodeMode) {
    switch (barcodeMode) {
      case BarcodeFormats.FORMAT_ALL_FORMATS:
        return 0;
      case BarcodeFormats.FORMAT_CODE_128:
        return 1;
      case BarcodeFormats.FORMAT_CODE_39:
        return 2;
      case BarcodeFormats.FORMAT_CODE_93:
        return 4;
      case BarcodeFormats.FORMAT_CODABAR:
        return 8;
      case BarcodeFormats.FORMAT_DATA_MATRIX:
        return 16;
      case BarcodeFormats.FORMAT_EAN_13:
        return 32;
      case BarcodeFormats.FORMAT_EAN_8:
        return 64;
      case BarcodeFormats.FORMAT_ITF:
        return 128;
      case BarcodeFormats.FORMAT_QR_CODE:
        return 256;
      case BarcodeFormats.FORMAT_UPC_A:
        return 512;
      case BarcodeFormats.FORMAT_UPC_E:
        return 1024;
      case BarcodeFormats.FORMAT_PDF417:
        return 2048;
      case BarcodeFormats.FORMAT_AZTEC:
        return 4096;

      default:
        return 0;
    }
  }
}
