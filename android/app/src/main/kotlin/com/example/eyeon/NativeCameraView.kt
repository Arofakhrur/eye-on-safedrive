package com.example.eyeon

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.facemesh.FaceMeshDetection
import com.google.mlkit.vision.facemesh.FaceMeshDetector
import com.google.mlkit.vision.facemesh.FaceMeshDetectorOptions
import com.google.mlkit.vision.facemesh.FaceMeshPoint
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.*
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.hypot

class NativeCameraView(
    private val context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    private val lifecycleOwner: LifecycleOwner
) : PlatformView, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "NativeCameraView"
    }

    private val container: FrameLayout = FrameLayout(context)
    private val previewView: PreviewView = PreviewView(context)

    private var eventSink: EventChannel.EventSink? = null
    private val eventChannel = EventChannel(messenger, "eyeon_native_camera_events")
    private val methodChannel = MethodChannel(messenger, "eyeon_native_camera_control")

    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val detector: FaceMeshDetector

    private var videoCapture: VideoCapture<Recorder>? = null
    private var activeRecording: Recording? = null
    private var rollingJob: Job? = null
    private var isIncidentLocked = false
    private var lockedVideoPath: String? = null

    // Guard against double startCamera calls
    private var isCameraStarted = false
    private var cameraProvider: ProcessCameraProvider? = null

    // Face mesh toggle
    private var shouldSendFacePoints = false

    // For Coroutines
    private val scope = CoroutineScope(Dispatchers.Main + Job())

    init {
        Log.d(TAG, "init: NativeCameraView created (viewId=$viewId)")

        previewView.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        previewView.setBackgroundColor(Color.BLACK)
        previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        
        container.addView(previewView)

        eventChannel.setStreamHandler(this)

        val options = FaceMeshDetectorOptions.Builder()
            .setUseCase(FaceMeshDetectorOptions.FACE_MESH)
            .build()
        detector = FaceMeshDetection.getClient(options)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "lockIncidentVideo" -> {
                    Log.d(TAG, "lockIncidentVideo called")
                    isIncidentLocked = true
                    rollingJob?.cancel()
                    rollingJob = null
                    activeRecording?.stop()
                    activeRecording = null
                    scope.launch {
                        var retries = 0
                        while (lockedVideoPath == null && retries < 50) {
                            delay(100)
                            retries++
                        }
                        if (lockedVideoPath == null) {
                            Log.e(TAG, "lockIncidentVideo: Timeout waiting for video to finalize!")
                        } else {
                            Log.d(TAG, "lockIncidentVideo: Video ready at $lockedVideoPath")
                        }
                        result.success(lockedVideoPath)
                    }
                }
                "startCamera" -> {
                    Log.d(TAG, "startCamera method called from Flutter")
                    if (isCameraStarted) {
                        Log.w(TAG, "startCamera: Camera already started, ignoring duplicate call")
                        result.success(true)
                    } else {
                        startCamera()
                        result.success(true)
                    }
                }
                "setDrowsyState" -> {
                    // Accept drowsy state from Flutter (for future use if needed)
                    result.success(true)
                }
                "setSendFacePoints" -> {
                    val send = call.argument<Boolean>("send") ?: false
                    shouldSendFacePoints = send
                    Log.d(TAG, "setSendFacePoints: \$shouldSendFacePoints")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View {
        return container
    }

    override fun dispose() {
        Log.d(TAG, "dispose: Cleaning up NativeCameraView")
        cameraExecutor.shutdown()
        detector.close()
        scope.cancel()
        try {
            activeRecording?.stop()
        } catch (_: Exception) {}
        activeRecording = null
        rollingJob?.cancel()
        rollingJob = null

        // Unbind all camera use cases
        try {
            cameraProvider?.unbindAll()
        } catch (e: Exception) {
            Log.e(TAG, "dispose: Error unbinding camera", e)
        }
        cameraProvider = null
        isCameraStarted = false
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun startCamera() {
        Log.d(TAG, "startCamera: Initializing CameraX...")
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({
            try {
                val provider = cameraProviderFuture.get()
                cameraProvider = provider
                Log.d(TAG, "startCamera: CameraProvider obtained")

                // 1. Preview
                val preview = Preview.Builder()
                    .build()
                    .also {
                        it.setSurfaceProvider(previewView.surfaceProvider)
                    }
                Log.d(TAG, "startCamera: Preview configured")

                // 2. Image Analysis (Face Mesh)
                val imageAnalysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()

                imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                    val mediaImage = imageProxy.image
                    if (mediaImage != null) {
                        val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                        detector.process(image)
                            .addOnSuccessListener { meshes ->
                                if (meshes.isNotEmpty()) {
                                    val allPoints = meshes[0].allPoints
                                    val rightEAR = calculateEyeEAR(allPoints, intArrayOf(33, 160, 158, 133, 153, 144))
                                    val leftEAR = calculateEyeEAR(allPoints, intArrayOf(362, 385, 387, 263, 373, 380))
                                    val avgEAR = (rightEAR + leftEAR) / 2.0

                                    // Serialize points to FloatArray for Flutter ONLY if requested
                                    var pointsArray: FloatArray? = null
                                    if (shouldSendFacePoints) {
                                        pointsArray = FloatArray(allPoints.size * 2)
                                        for (i in allPoints.indices) {
                                            pointsArray[i * 2] = allPoints[i].position.x
                                            pointsArray[i * 2 + 1] = allPoints[i].position.y
                                        }
                                    }

                                    val eventMap = mutableMapOf<String, Any>(
                                        "type" to "ear", 
                                        "value" to avgEAR,
                                        "imageWidth" to mediaImage.width,
                                        "imageHeight" to mediaImage.height,
                                        "rotation" to imageProxy.imageInfo.rotationDegrees
                                    )
                                    if (pointsArray != null) {
                                        eventMap["points"] = pointsArray
                                    }
                                    
                                    sendEvent(eventMap)
                                } else {
                                    // No face detected — let Flutter know
                                    sendEvent(mapOf("type" to "no_face"))
                                }
                            }
                            .addOnFailureListener { e ->
                                Log.e(TAG, "ML Kit face mesh detection failed", e)
                            }
                            .addOnCompleteListener {
                                imageProxy.close()
                            }
                    } else {
                        imageProxy.close()
                    }
                }
                Log.d(TAG, "startCamera: ImageAnalysis configured")

                // 3. Video Capture (Rolling Buffer)
                val recorder = Recorder.Builder()
                    .setQualitySelector(QualitySelector.from(Quality.SD))
                    .build()
                videoCapture = VideoCapture.withOutput(recorder)
                Log.d(TAG, "startCamera: VideoCapture configured")

                val cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA

                provider.unbindAll()
                try {
                    provider.bindToLifecycle(
                        lifecycleOwner,
                        cameraSelector,
                        preview,
                        imageAnalysis,
                        videoCapture
                    )
                    Log.d(TAG, "startCamera: ✅ Camera bound to lifecycle successfully (with VideoCapture)!")
                } catch (e: Exception) {
                    Log.w(TAG, "startCamera: Failed to bind 3 use cases (emulator/low-end device issue?). Retrying without VideoCapture...", e)
                    provider.unbindAll()
                    provider.bindToLifecycle(
                        lifecycleOwner,
                        cameraSelector,
                        preview,
                        imageAnalysis
                    )
                    Log.d(TAG, "startCamera: ✅ Camera bound to lifecycle successfully (without VideoCapture)!")
                }

                isCameraStarted = true

                startRollingBuffer()

            } catch (exc: Exception) {
                Log.e(TAG, "startCamera: ❌ Failed to bind camera use cases", exc)
            }

        }, ContextCompat.getMainExecutor(context))
    }

    /**
     * Helper to safely send events to Flutter via EventChannel.
     * Logs a warning if eventSink is null (Flutter hasn't subscribed yet).
     */
    private fun sendEvent(data: Map<String, Any?>) {
        scope.launch {
            val sink = eventSink
            if (sink != null) {
                sink.success(data)
            } else {
                Log.w(TAG, "sendEvent: eventSink is null — Flutter not listening yet. Data: $data")
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startRollingBuffer() {
        if (isIncidentLocked) return
        Log.d(TAG, "startRollingBuffer: Starting rolling video buffer")

        rollingJob = scope.launch(Dispatchers.IO) {
            while (isActive && !isIncidentLocked) {
                try {
                    val outputFile = File(context.cacheDir, "rolling_buffer_${System.currentTimeMillis()}.mp4")

                    withContext(Dispatchers.Main) {
                        val outputOptions = FileOutputOptions.Builder(outputFile).build()
                        activeRecording = videoCapture?.output
                            ?.prepareRecording(context, outputOptions)
                            ?.start(ContextCompat.getMainExecutor(context)) { recordEvent ->
                                if (recordEvent is VideoRecordEvent.Finalize) {
                                    if (!recordEvent.hasError()) {
                                        if (isIncidentLocked) {
                                            lockedVideoPath = recordEvent.outputResults.outputUri.path
                                            Log.d(TAG, "Rolling buffer: Incident video locked at $lockedVideoPath")
                                            sendEvent(mapOf("type" to "incident_video_ready", "path" to lockedVideoPath))
                                        } else {
                                            // Delete the file if no incident
                                            outputFile.delete()
                                        }
                                    } else {
                                        Log.e(TAG, "Rolling buffer: Recording finalized with error: ${recordEvent.error}")
                                        outputFile.delete()
                                    }
                                }
                            }
                    }

                    // Record for 5 seconds
                    delay(5000)

                    // Only stop if incident hasn't been locked during this segment
                    if (!isIncidentLocked) {
                        withContext(Dispatchers.Main) {
                            stopRecording()
                        }
                    }
                } catch (e: kotlinx.coroutines.CancellationException) {
                    Log.d(TAG, "Rolling buffer: Coroutine cancelled (incident lock or dispose)")
                    break
                } catch (e: Exception) {
                    Log.e(TAG, "Rolling buffer: Error in recording cycle", e)
                }
            }
        }
    }

    private fun stopRecording() {
        activeRecording?.stop()
        activeRecording = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "onListen: Flutter started listening to EventChannel")
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "onCancel: Flutter stopped listening to EventChannel")
        this.eventSink = null
    }

    private fun calculateEyeEAR(allPoints: List<FaceMeshPoint>, indices: IntArray): Double {
        if (allPoints.size < 468) return 0.0

        val p1 = allPoints[indices[0]].position
        val p2 = allPoints[indices[1]].position
        val p3 = allPoints[indices[2]].position
        val p4 = allPoints[indices[3]].position
        val p5 = allPoints[indices[4]].position
        val p6 = allPoints[indices[5]].position

        val d1 = hypot((p2.x - p6.x).toDouble(), (p2.y - p6.y).toDouble())
        val d2 = hypot((p3.x - p5.x).toDouble(), (p3.y - p5.y).toDouble())
        val d3 = hypot((p1.x - p4.x).toDouble(), (p1.y - p4.y).toDouble())

        return if (d3 > 0) (d1 + d2) / (2.0 * d3) else 0.0
    }
}
