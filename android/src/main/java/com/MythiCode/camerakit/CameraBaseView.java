package com.MythiCode.camerakit;

import android.app.Activity;
import android.graphics.Color;
import android.os.Build;
import android.view.View;
import android.widget.LinearLayout;

import com.google.firebase.FirebaseApp;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

public class CameraBaseView implements PlatformView {


    private final Activity activity;
    private final FlutterMethodListener flutterMethodListener;
    private final LinearLayout linearLayout;
    private CameraViewInterface cameraViewInterface;

    public CameraBaseView(Activity activity, FlutterMethodListener flutterMethodListener) {
        FirebaseApp.initializeApp(activity);
        this.activity = activity;
        this.flutterMethodListener = flutterMethodListener;
        linearLayout = new LinearLayout(activity);
        linearLayout.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT));
        linearLayout.setBackgroundColor(Color.parseColor("#000000"));

    }

    public void initCamera(boolean hasBarcodeReader, char flashMode, 
            boolean isFillScale, int barcodeMode, 
            boolean useCamera2API, char cameraPosition, boolean hasFaceDetection) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            if (useCamera2API)
                cameraViewInterface = new CameraView2(activity, flutterMethodListener);
            else cameraViewInterface = new CameraView1(activity, flutterMethodListener);
        } else {
            cameraViewInterface = new CameraView1(activity, flutterMethodListener);
        }
        cameraViewInterface.initCamera(linearLayout, hasBarcodeReader, flashMode, isFillScale, barcodeMode, cameraPosition, hasFaceDetection);
    }

    public void setCameraVisible(boolean isCameraVisible) {
        cameraViewInterface.setCameraVisible(isCameraVisible);
    }

    public void changeFlashMode(char captureFlashMode) {
        cameraViewInterface.changeFlashMode(captureFlashMode);
    }

    public void takePicture(final MethodChannel.Result result) {
        cameraViewInterface.takePicture(result);
    }

    public void pauseCamera() {
        cameraViewInterface.pauseCamera();
    }

    public void resumeCamera() {
        cameraViewInterface.resumeCamera();
    }

    @Override
    public View getView() {
        return linearLayout;
    }

    @Override
    public void dispose() {
        cameraViewInterface.dispose();
    }
}
