package com.jeevalink.jeevalink

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.util.Log
import java.util.Locale

class SpeechManager(
    private val context: Context,
    private val onSTTResult: (String) -> Unit,
    private val onSTTError: (String) -> Unit
) : TextToSpeech.OnInitListener {

    private val tag = "SpeechManager"
    private var speechRecognizer: SpeechRecognizer? = null
    private var textToSpeech: TextToSpeech? = null
    private var isTTSReady = false
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        mainHandler.post {
            try {
                if (SpeechRecognizer.isRecognitionAvailable(context)) {
                    initRecognizerInstance()
                } else {
                    Log.w(tag, "Speech recognition is not available on this device")
                }
            } catch (e: Exception) {
                Log.e(tag, "Error initializing SpeechRecognizer", e)
            }
        }

        textToSpeech = TextToSpeech(context, this)
    }

    private fun initRecognizerInstance(): SpeechRecognizer? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                Log.d(tag, "Creating Android 12+ OnDeviceSpeechRecognizer")
                SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            } else {
                Log.d(tag, "Creating Standard SpeechRecognizer")
                SpeechRecognizer.createSpeechRecognizer(context)
            }
        } catch (e: Exception) {
            Log.w(tag, "Fallback to standard createSpeechRecognizer: ${e.message}")
            try {
                SpeechRecognizer.createSpeechRecognizer(context)
            } catch (_: Exception) {
                null
            }
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            isTTSReady = true
            textToSpeech?.language = Locale.getDefault()
            Log.d(tag, "TextToSpeech initialized successfully")
        } else {
            Log.e(tag, "TextToSpeech initialization failed with status $status")
        }
    }

    fun startListening(language: String = "en-US") {
        mainHandler.post {
            try {
                // Safely destroy old instance to avoid state locks
                speechRecognizer?.let {
                    try {
                        it.stopListening()
                        it.cancel()
                        it.destroy()
                    } catch (_: Exception) {}
                }

                if (!SpeechRecognizer.isRecognitionAvailable(context)) {
                    onSTTError("Speech recognition unavailable on device")
                    return@post
                }

                speechRecognizer = initRecognizerInstance()
                if (speechRecognizer == null) {
                    onSTTError("Could not create speech recognizer")
                    return@post
                }

                val targetLang = when (language.lowercase()) {
                    "ta", "ta-in" -> "ta-IN"
                    "te", "te-in" -> "te-IN"
                    "hi", "hi-in" -> "hi-IN"
                    else -> if (language.contains("-")) language else "$language-US"
                }

                Log.d(tag, "Starting STT listener on Main Looper with locale: $targetLang")

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, targetLang)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, targetLang)
                    putExtra("android.speech.extra.EXTRA_ADDITIONAL_LANGUAGES", arrayOf(targetLang))
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                }

                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        Log.d(tag, "SpeechRecognizer: Ready for speech input ($targetLang)")
                    }

                    override fun onBeginningOfSpeech() {
                        Log.d(tag, "SpeechRecognizer: Beginning of speech detected")
                    }

                    override fun onRmsChanged(rmsdB: Float) {}
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    override fun onEndOfSpeech() {
                        Log.d(tag, "SpeechRecognizer: End of speech detected")
                    }

                    override fun onError(error: Int) {
                        val errorMsg = getErrorMessage(error)
                        Log.e(tag, "STT Error ($targetLang): $errorMsg (code $error)")
                        mainHandler.post {
                            onSTTError("$errorMsg (code $error)")
                        }
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (!matches.isNullOrEmpty()) {
                            val recognizedText = matches[0]
                            Log.d(tag, "STT Result ($targetLang): $recognizedText")
                            mainHandler.post {
                                onSTTResult(recognizedText)
                            }
                        } else {
                            mainHandler.post {
                                onSTTError("No speech detected")
                            }
                        }
                    }

                    override fun onPartialResults(partialResults: Bundle?) {}
                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })

                speechRecognizer?.startListening(intent)
            } catch (e: Exception) {
                Log.e(tag, "Failed to start listening", e)
                onSTTError(e.message ?: "STT Start Error")
            }
        }
    }

    fun stopListening() {
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
            } catch (e: Exception) {
                Log.e(tag, "Error stopping listening", e)
            }
        }
    }

    fun speak(text: String, language: String = "en") {
        if (!isTTSReady || textToSpeech == null) {
            Log.w(tag, "TTS is not ready yet")
            return
        }

        val targetLang = when (language.lowercase()) {
            "ta", "ta-in" -> "ta-IN"
            "te", "te-in" -> "te-IN"
            "hi", "hi-in" -> "hi-IN"
            else -> language
        }

        val locale = try {
            Locale.forLanguageTag(targetLang)
        } catch (e: Exception) {
            Locale.getDefault()
        }

        textToSpeech?.language = locale
        textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "JeevaLinkTTS")
    }

    fun destroy() {
        mainHandler.post {
            try {
                speechRecognizer?.destroy()
                textToSpeech?.stop()
                textToSpeech?.shutdown()
            } catch (e: Exception) {
                Log.e(tag, "Error destroying SpeechManager", e)
            }
        }
    }

    private fun getErrorMessage(errorCode: Int): String {
        return when (errorCode) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
            SpeechRecognizer.ERROR_CLIENT -> "Client side error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
            SpeechRecognizer.ERROR_NETWORK -> "Network error"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "No speech match found"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
            SpeechRecognizer.ERROR_SERVER -> "Server error"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input timeout"
            11 -> "Server disconnected (code 11)"
            else -> "Speech engine error"
        }
    }
}
