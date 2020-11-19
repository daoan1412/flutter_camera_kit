//
//  CameraKitFlutterView.swift
//  camerakit
//
//  Created by MythiCode on 9/6/20.
//

import Foundation
import AVFoundation
import MLKitBarcodeScanning
import MLKitCommon
import MLKitVision
import MLKitFaceDetection

@available(iOS 10.0, *)
class CameraKitFlutterView : NSObject, FlutterPlatformView, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    let channel: FlutterMethodChannel
    let frame: CGRect

    var hasBarcodeReader: Bool!
    var hasFaceDetection: Bool!
    var isCameraVisible:Bool! = true
    var initCameraFinished:Bool! = false
    var isFillScale:Bool!
    var flashMode:AVCaptureDevice.FlashMode!
    var cameraPosition: AVCaptureDevice.Position!
    
    var previewView : UIView!
    var videoDataOutput: AVCaptureVideoDataOutput!
    var videoDataOutputQueue: DispatchQueue!
    
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer:AVCaptureVideoPreviewLayer!
    var captureDevice : AVCaptureDevice!
    let captureSession = AVCaptureSession()
    var barcodeScanner:BarcodeScanner!
    var faceDetector: FaceDetector!
    var flutterResultTakePicture:FlutterResult!
    private lazy var sessionQueue = DispatchQueue(label: "civams.face.admin.camera.SessionQueue")

    var headEulerAngle: [String: Int] = [:]
    
    init(registrar: FlutterPluginRegistrar, viewId: Int64, frame: CGRect) {
        self.channel = FlutterMethodChannel(name: "plugins/camera_kit_" + String(viewId), binaryMessenger: registrar.messenger())
        self.frame = frame
     }
    
    func requestPermission(flutterResult:  @escaping FlutterResult) {
        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
            //already authorized
            flutterResult(true)
        } else {
            DispatchQueue.main.async {
                AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                    if granted {
                        //access allowed
                        flutterResult(true)
                    } else {
                        //access denied
                        flutterResult(false)
                    }
                })
            }
        }
    }

    private func resumeCamera() {
          if  self.initCameraFinished == true {
                        self.previewLayer.frame = self.previewView.layer.bounds
                        self.sessionQueue.async {
                            self.captureSession.startRunning()
                            self.isCameraVisible = true
                        }
                    }
    }
    
    
    public func setMethodHandler() {
        self.channel.setMethodCallHandler({[weak self] (FlutterMethodCall,  FlutterResult) in
                guard let self = self else { return }
                let args = FlutterMethodCall.arguments
                let myArgs = args as? [String: Any]
                if FlutterMethodCall.method == "requestPermission" {
                    self.requestPermission(flutterResult: FlutterResult)
                } else if FlutterMethodCall.method == "initCamera" {
                    self.initCameraFinished = false
                    DispatchQueue.main.async {
                        self.initCamera(hasBarcodeReader: (myArgs?["hasBarcodeReader"] as! Bool),
                                        flashMode: (myArgs?["flashMode"] ) as! String,isFillScale:
                                        (myArgs?["isFillScale"] ) as! Bool
                            , barcodeMode:   (myArgs?["barcodeMode"] ) as! Int,
                            cameraPosition: (myArgs?["cameraPosition"]) as! String,
                            hasFaceDetection: (myArgs?["hasFaceDetection"]) as! Bool
                            )
                        self.resumeCamera()
                    }
                } else if FlutterMethodCall.method == "resumeCamera" {
                    self.resumeCamera()
            }
                else if FlutterMethodCall.method == "pauseCamera" {
                     if self.initCameraFinished == true {
                         self.sessionQueue.async {
                            self.captureSession.stopRunning()
                             self.isCameraVisible = false
                         }
                    }
                }
            else if FlutterMethodCall.method == "changeFlashMode" {
                    self.setFlashMode(flashMode: (myArgs?["flashMode"] ) as! String)
                    self.changeFlashMode()
                } else if FlutterMethodCall.method == "setCameraVisible" {
                    let cameraVisibility = (myArgs?["isCameraVisible"] as! Bool)
                    //print("isCameraVisible: " + String(isCameraVisible))
                    if cameraVisibility == true {
                        if self.isCameraVisible == false {
                            self.captureSession.startRunning()
                            self.isCameraVisible = true
                        }
                    } else {
                           if self.isCameraVisible == true {
                                self.stopCamera()
                                self.isCameraVisible = false
                        }
                    }
                  
                }
             else if FlutterMethodCall.method == "takePicture" {
                    self.flutterResultTakePicture = FlutterResult
                    self.takePicture()
                        }
             else if FlutterMethodCall.method == "setFaceDetectionStrategy" {
                self.headEulerAngle["minX"] = (myArgs?["minX"] as! Int)
                self.headEulerAngle["maxX"] = (myArgs?["maxX"] as! Int)
                self.headEulerAngle["minY"] = (myArgs?["minY"] as! Int)
                self.headEulerAngle["maxY"] = (myArgs?["maxY"] as! Int)
                self.headEulerAngle["minZ"] = (myArgs?["minZ"] as! Int)
                self.headEulerAngle["maxZ"] = (myArgs?["maxZ"] as! Int)
             }           
            })
    }
    
    func changeFlashMode() {
       
        if(self.hasBarcodeReader) {
            do{
               if (captureDevice.hasTorch)
                   {
                       try captureDevice.lockForConfiguration()
                    captureDevice.torchMode = (self.flashMode == .auto) ?(.auto):(self.flashMode == .on ? (.on) : (.off))
                       captureDevice.flashMode = self.flashMode
                       captureDevice.unlockForConfiguration()
                   }
                }catch{
                   //DISABEL FLASH BUTTON HERE IF ERROR
                   print("Device tourch Flash Error ");
               }
          
        }
    }
    
    func setFlashMode(flashMode: String) {
        if flashMode == "A" {
            self.flashMode = .auto
                  } else if flashMode == "O" {
            self.flashMode = .on
                  } else if flashMode == "F"{
            self.flashMode = .off
                  }
    }

    func setCameraPosition(position: String) {
        if position == "B" {
            cameraPosition = AVCaptureDevice.Position.back;
        } else if position == "F" {
            cameraPosition = AVCaptureDevice.Position.front;
        }
    }
    
    func view() -> UIView {
        if previewView == nil {
        self.previewView = UIView(frame: frame)
//            previewView.contentMode = UIView.ContentMode.scaleAspectFill
        }
        return previewView
    }

    private func setUpPreviewLayer() {
          previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            if self.isFillScale == true {
                    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            } else {
                   previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
            }
    }

    private func setUpCaptureSessionInput() {
         sessionQueue.async {[weak self] in
            guard let self = self else { return }
            let cameraPosition: AVCaptureDevice.Position =  self.cameraPosition
            guard let device = self.captureDevice(forPosition: self.cameraPosition) else {
                print("Failed to get capture device for camera position: \(self.cameraPosition)")
                return
            }
            do {
                self.captureSession.beginConfiguration()
                let currentInputs = self.captureSession.inputs
                for input in currentInputs {
                    self.captureSession.removeInput(input)
                }
                
                let input = try AVCaptureDeviceInput(device: device)
                guard self.captureSession.canAddInput(input) else {
                    print("Failed to add capture session input.")
                    return
                }
                self.captureSession.addInput(input)
                self.captureSession.commitConfiguration()
            } catch {
                print("Failed to create capture device input: \(error.localizedDescription)")
            }
        }
    }

      private func setUpCaptureSessionOutput() {
        sessionQueue.async {
            self.captureSession.beginConfiguration()
            // When performing latency tests to determine ideal capture settings,
            // run the app in 'release' mode to get accurate performance metrics
            self.captureSession.sessionPreset = AVCaptureSession.Preset.medium
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA,
            ]
            output.alwaysDiscardsLateVideoFrames = true
            let outputQueue = DispatchQueue(label: "VideoDataOutputQueue")
            output.setSampleBufferDelegate(self, queue: outputQueue)
            guard self.captureSession.canAddOutput(output) else {
                print("Failed to add capture session output.")
                return
            }
            self.captureSession.addOutput(output)
            self.captureSession.commitConfiguration()
        }
    }
    
    func initCamera(hasBarcodeReader: Bool, flashMode: String, isFillScale: Bool, barcodeMode: Int, cameraPosition: String, hasFaceDetection: Bool) {
        self.hasBarcodeReader = hasBarcodeReader
        self.hasFaceDetection = hasFaceDetection
        self.isFillScale = isFillScale
        var myBarcodeMode: Int
        setFlashMode(flashMode: flashMode)
        setCameraPosition(position: cameraPosition)
        if hasBarcodeReader == true {
//            let barcodeOptions = BarcodeScannerOptions(formats:
//                BarcodeFormat(rawValue: barcodeMode))
              if barcodeMode == 0 {
                 myBarcodeMode = 65535
             }
              else {
                myBarcodeMode = barcodeMode
            }
             let barcodeOptions = BarcodeScannerOptions(formats:
                BarcodeFormat(rawValue: myBarcodeMode))
//            let barcodeOptions = BarcodeScannerOptions(formats:
//                .all)
                // Create a barcode scanner.
               barcodeScanner = BarcodeScanner.barcodeScanner(options: barcodeOptions)
        }

        if hasFaceDetection {
            let options = FaceDetectorOptions()
            options.performanceMode = .fast 
            options.landmarkMode = .all
            self.faceDetector = FaceDetector.faceDetector(options: options)

        }
        self.setUpPreviewLayer()
        self.setUpCaptureSessionInput()
         let rootLayer :CALayer = self.previewView.layer
         rootLayer.masksToBounds = true
         rootLayer.addSublayer(self.previewLayer)
        self.setUpCaptureSessionOutput()
        self.initCameraFinished = true
    }

   private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            return discoverySession.devices.first { $0.position == position }
    }
    
    // func setupAVCapture(){
    //     session.sessionPreset = AVCaptureSession.Preset.medium
    //       guard let device = captureDevice(forPosition: cameraPosition) else {
    //                           return
    //       }
    //       captureDevice = device
    
       
    //       beginSession()
    //       changeFlashMode()
    //   }
    
    
    // func beginSession(isFirst: Bool = true){
    //     var deviceInput: AVCaptureDeviceInput!

        
    //     do {
    //         deviceInput = try AVCaptureDeviceInput(device: captureDevice)
    //         guard deviceInput != nil else {
    //             print("error: cant get deviceInput")
    //             return
    //         }
            
    //         if self.session.canAddInput(deviceInput){
    //             self.session.addInput(deviceInput)
    //         }

    //         if(hasBarcodeReader || hasFaceDetection) {
    //             videoDataOutput = AVCaptureVideoDataOutput()
    //             videoDataOutput.alwaysDiscardsLateVideoFrames=true
    //             videoDataOutput.videoSettings = [
    //                 (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA,
    //             ]
    //             videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    //             videoDataOutput.setSampleBufferDelegate(self, queue:self.videoDataOutputQueue)
    //             if session.canAddOutput(videoDataOutput!){
    //                          session.addOutput(videoDataOutput!)
    //              }
    //             videoDataOutput.connection(with: .video)?.isEnabled = true

    //         }
    //         else {
    //             photoOutput = AVCapturePhotoOutput()
    //                 photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])], completionHandler: nil)
    //             if session.canAddOutput(photoOutput!){
    //                 session.addOutput(photoOutput!)
    //             }
    //         }



    //         previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
    //         if self.isFillScale == true {
    //                 previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
    //         } else {
    //                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
    //         }

    //         let rootLayer :CALayer = self.previewView.layer
    //         rootLayer.masksToBounds = true
    //         previewLayer.frame = rootLayer.bounds
    //         rootLayer.addSublayer(self.previewLayer)
    //         session.startRunning()
    //         if isFirst == true {
    //         DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
    //                                 self.initCameraFinished = true
    //                        }
    //         }
       
            
    //     } catch let error as NSError {
    //         deviceInput = nil
    //         print("error: \(error.localizedDescription)")
    //     }
    // }
    
    func stopCamera(){
        self.sessionQueue.async {
            self.captureSession.startRunning()
            self.isCameraVisible = true
        }
    }

    
     private func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
          switch UIApplication.shared.statusBarOrientation {
          case .landscapeLeft:
            return .landscapeRight
          case .landscapeRight:
            return .landscapeLeft
          case .portraitUpsideDown:
            return .portraitUpsideDown
          case .portrait, .unknown:
            return .portrait
          @unknown default:
            fatalError()
          }
        }
        guard Thread.isMainThread else {
          var currentOrientation: UIDeviceOrientation = .portrait
          DispatchQueue.main.sync {
            currentOrientation = deviceOrientation()
          }
          return currentOrientation
        }
        return deviceOrientation()
      }
    
    
    public func imageOrientation(
      fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
    ) -> UIImage.Orientation {
      var deviceOrientation = UIDevice.current.orientation
      if deviceOrientation == .faceDown || deviceOrientation == .faceUp
        || deviceOrientation
          == .unknown
      {
        deviceOrientation = currentUIOrientation()
      }
      switch deviceOrientation {
      case .portrait:
        return devicePosition == .front ? .leftMirrored : .right
      case .landscapeLeft:
        return devicePosition == .front ? .downMirrored : .up
      case .portraitUpsideDown:
        return devicePosition == .front ? .rightMirrored : .left
      case .landscapeRight:
        return devicePosition == .front ? .upMirrored : .down
      case .faceDown, .faceUp, .unknown:
        return .up
      @unknown default:
        fatalError()
      }
    }
    func saveImage(image: UIImage) -> Bool {
        guard let data = image.jpegData(compressionQuality: 1) ?? image.pngData() else {
            return false
        }
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
            return false
        }
        do {
            try data.write(to: directory.appendingPathComponent("pic.jpg")!)
            flutterResultTakePicture(directory.path!  + "/pic.jpg")
            //print(directory)
            return true
        } catch {
            print(error.localizedDescription)
                        flutterResultTakePicture(FlutterError(code: "-103", message: error.localizedDescription, details: nil))
            return false
        }
    }
    func takePicture() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        photoOutput?.capturePhoto(with: settings, delegate:self)
    }
    
    public func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                        resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Swift.Error?) {
        if let error = error { //self.photoCaptureCompletionBlock?(nil, error)
            flutterResultTakePicture(FlutterError(code: "-101", message: error.localizedDescription, details: nil))
        }
            
        else if let buffer = photoSampleBuffer, let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: buffer, previewPhotoSampleBuffer: nil),
            let image = UIImage(data: data) {
            
            self.saveImage(image: image)
        }
            
        else {
            //error
//            self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
                        flutterResultTakePicture(FlutterError(code: "-102", message: "Unknown error", details: nil))
        }
    }
    

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if barcodeScanner == nil && faceDetector == nil {
            return
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }

        let visionImage = VisionImage(buffer: sampleBuffer)
        let orientation = imageOrientation(
            fromDevicePosition: cameraPosition
        )
        visionImage.orientation = orientation

        if faceDetector != nil {
            if (self.headEulerAngle.isEmpty) {
                channel.invokeMethod("onFaceDetectionMsgCallBack", arguments: 4)
                return
            }
            var faces: [Face]

            do {
                faces = try faceDetector.results(in: visionImage)
            } catch let error {
                print("Failed to detect faces with error: \(error.localizedDescription).")
                return
            }

            if (faces.isEmpty) {
                channel.invokeMethod("onFaceDetectionMsgCallBack", arguments: 9)
                return
            }
            
            for face in faces {
                let frame = face.frame
                let rotX = face.headEulerAngleX
                let rotY = face.headEulerAngleY
                let rotZ = face.headEulerAngleZ

                let x = frame.origin.x 
                let y = frame.origin.y

                if (x < 0) {
                    channel.invokeMethod("onFaceDetectionMsgCallBack", arguments: 0)
                    return
                }

                if(Int(x + frame.size.width) > CVPixelBufferGetWidth(imageBuffer)) {
                    channel.invokeMethod("onFaceDetectionMsgCallBack", arguments: 1)
                    return
                }

                if (y < 0) {
                    channel.invokeMethod("onFaceDetectionMsgCallBack", arguments: 2)
                    return
                }

                if(Int(y + frame.size.height) > CVPixelBufferGetHeight(imageBuffer)) {
                    channel.invokeMethod("onFaceDetectionMsgCallBack", arguments: 3)
                    return
                }

               guard let maxX = self.headEulerAngle["maxX"],
                      let minX = self.headEulerAngle["minX"],
                      let minY = self.headEulerAngle["minY"],
                      let maxY = self.headEulerAngle["maxY"] else {
                    return
                }

                if(Int(rotX) > maxX) {
                    channel.invokeMethod("onFaceDetectionMsgCallBack", arguments: 5)
                    return
                }

                if (Int(rotX) < minX) {
                    channel.invokeMethod("onFaceDetectionMsgCallBack", arguments: 6)
                    return
                }

                if (Int(rotY) > maxY) {
                    channel.invokeMethod("onFaceDetectionMsgCallBack", arguments: 7)
                    return
                }

                if (Int(rotY) < minY) {
                    channel.invokeMethod("onFaceDetectionMsgCallBack", arguments: 8)
                    return
                }

                if let image = imageFromImageBuffer(imageBuffer, faceFrame: frame) {
                    if let data = image.jpegData(compressionQuality: 1.0) {
                         channel.invokeMethod("onFaceImageCallBack", 
                         arguments: FlutterStandardTypedData(bytes: data))
                         self.headEulerAngle = [:]
                    }
                }
            }
        }
        
        // do stuff heref
        if barcodeScanner != nil {
            var barcodes: [Barcode]
            
            do {
                barcodes = try self.barcodeScanner.results(in: visionImage)
            } catch let error {
              print("Failed to scan barcodes with error: \(error.localizedDescription).")
              return
            }
            
            guard !barcodes.isEmpty else {
               //print("Barcode scanner returrned no results.")
               return
            }
            
            for barcode in barcodes {
                barcodeRead(barcode: barcode.rawValue!)
            }
        }
        
    }

     func imageFromImageBuffer(_ imageBuffer : CVImageBuffer, faceFrame: CGRect) -> UIImage? {
        let rect = CGRect(
            x: faceFrame.origin.x,
            y: faceFrame.origin.y,
            width: faceFrame.size.width,
            height: faceFrame.size.height
        )
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags.readOnly)
        
        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        
        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a bitmap graphics context with the sample buffer data
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        //let bitmapInfo: UInt32 = CGBitmapInfo.alphaInfoMask.rawValue
        let context = CGContext.init(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        // Create a Quartz image from the pixel data in the bitmap graphics context
        let quartzImage = context?.makeImage()
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags.readOnly)
        
        // Create an image object from the Quartz image
        
        let faceCgImage = quartzImage!.cropping(to: rect)!
        
        let image = UIImage.init(cgImage: faceCgImage, scale: 1, orientation: imageOrientation(fromDevicePosition: cameraPosition))
        
        return image
    }
    
    func barcodeRead(barcode: String) {
        channel.invokeMethod("onBarcodeRead", arguments: barcode)
    }
    
}
