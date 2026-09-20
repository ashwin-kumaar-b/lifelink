# 📡 JeevaLink (LifeLink) - Complete Project Architecture & Codebase Guide

> **Tagline:** *Speak. Relay. Survive.*  
> **System Type:** Internet-Independent Multilingual Offline Emergency Communication Network & Off-Grid Mesh System.

---

## 🖼️ System Architecture Overview

![JeevaLink System Architecture](file:///C:/Users/T%20Bharat/.gemini/antigravity/brain/f9ad7f53-f1fd-4466-96ea-4491578d4cc8/jeevalink_architecture_diagram_1789828991086.jpg)

---

## 🗂️ Complete Hierarchical File Tree

```text
lifelink/
├── .gitattributes                              # Git LFS tracking rules for ONNX models (*.onnx)
├── .gitignore                                 # Build output and IDE exclusion rules
├── .metadata                                  # Flutter metadata configuration
├── README.md                                  # Project description and documentation
├── analysis_options.yaml                      # Dart analyzer and linter configuration
├── pubspec.yaml                               # Flutter dependencies, assets, and metadata
├── pubspec.lock                               # Locked dependency resolution versions
├── assets/                                    # Local static assets
│   ├── models/                                # Local & Git LFS ONNX speech models
│   │   └── english/
│   │       ├── model.int8.onnx                # Pre-packaged English ONNX speech model
│   │       └── tokens.txt                     # English vocabulary tokens file
│   └── sounds/
│       └── clear_all_whoosh.wav               # UI sound effect for clearing message logs
├── android/                                   # Native Android Project
│   └── app/
│       └── src/
│          └── main/
│              ├── AndroidManifest.xml         # Android permissions, services, & activities
│              └── kotlin/com/jeevalink/jeevalink/
│                  ├── MainActivity.kt          # MethodChannel & EventChannel bridge hub
│                  ├── JeevaLinkForegroundService.kt # Foreground service & CPU WakeLock
│                  ├── NotificationHelper.kt    # WhatsApp-style status & emergency heads-up alerts
│                  ├── SocketManager.kt         # TCP socket server (Port 8888) & LAN broadcast
│                  ├── WifiDirectManager.kt     # Wi-Fi Direct (P2P) discovery & connection manager
│                  ├── BluetoothManager.kt      # RFCOMM Bluetooth fallback discovery & sockets
│                  └── SpeechManager.kt         # Native Android Speech Recognizer bridge
└── lib/                                       # Flutter Application Core
    ├── main.dart                              # App entry point & startup permission wrapper
    ├── models/
    │   └── message_packet.dart                # Core Message JSON Packet data model
    ├── services/
    │   ├── stt_tts_service.dart               # Sherpa-ONNX STT, FlutterTTS & Fuzzy Keyword Matcher
    │   ├── mesh_manager.dart                  # Multi-Hop Store-and-Forward & Deduplication Engine
    │   ├── native_bridge.dart                 # Dart MethodChannel wrapper for Kotlin bridge
    │   ├── local_storage_service.dart         # 24-hour persistent local JSON message storage
    │   ├── gps_service.dart                   # Geolocator GPS coordinate locator
    │   └── model_downloader_service.dart      # Dynamic GitHub Release ONNX downloader (Indic STT)
    ├── utils/
    │   └── gps_calculator.dart                # Haversine distance & bearing calculation utility
    ├── widgets/
    │   └── app_drawer.dart                    # Navigation drawer widget
    └── screens/
        ├── main_navigation_screen.dart        # Bottom navigation bar root shell
        ├── home_screen.dart                   # Push-To-Talk voice recorder & 24h message feed
        ├── emergency_panic_screen.dart        # 10s Countdown Light Glassmorphism SOS screen
        ├── radar_screen.dart                  # Animated 360° radar sweep & node distance map
        ├── message_screen.dart                # Detailed message history & playback log
        ├── connection_screen.dart             # Wi-Fi Direct / Bluetooth peer node manager
        └── settings_screen.dart               # User profile, language selector, & background status
```

---

## 📑 Detailed File-by-File Breakdown & Analysis

### 1. ⚙️ **Root Configuration & Metadata Files**

#### `pubspec.yaml`
- **Purpose:** Defines project package dependencies, Flutter engine constraints, and asset declarations.
- **Key Dependencies:**
  - `sherpa_onnx`: Local offline Speech-to-Text inference engine.
  - `record`: Audio recording to 16kHz mono WAV format.
  - `flutter_tts`: Android system native Text-to-Speech playback.
  - `geolocator`: GPS coordinate tracking.
  - `permission_handler`: Android runtime permission requesting.
  - `audioplayers`: In-app audio sound effects playback.
  - `uuid`: Unique identifier generation for message packets.
- **Declared Assets:** `assets/models/english/`, `assets/sounds/`.

#### `.gitattributes`
- **Purpose:** Specifies Git Large File Storage (LFS) rules. Tracks `*.onnx` binary files to keep repository sizes small.

---

### 2. 🤖 **Android Native Layer (`android/app/src/main/`)**

#### `AndroidManifest.xml`
- **Purpose:** Registers Android components, activities, services, and hardware permissions.
- **Permissions Declared:**
  - `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`, `CHANGE_NETWORK_STATE`, `INTERNET`: Wi-Fi Direct P2P networking.
  - `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `NEARBY_WIFI_DEVICES`: Android location and P2P peer scanning.
  - `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`: Bluetooth RFCOMM fallback.
  - `RECORD_AUDIO`: Microphone audio recording for STT.
  - `POST_NOTIFICATIONS`: Android 13+ push notification permissions.
  - `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: Background execution without OS kill.
- **Registered Service:** `<service android:name=".JeevaLinkForegroundService" android:foregroundServiceType="connectedDevice|dataSync" />`.

#### `MainActivity.kt`
- **Purpose:** Central Kotlin bridge hub between Flutter Dart runtime and Android native OS APIs.
- **Channels Managed:**
  - `MethodChannel("com.jeevalink/bridge")`: Handles method invocations from Flutter (`discoverPeers`, `connectPeer`, `sendMessage`, `startSTT`, `speakTTS`, `startBackgroundService`, `requestBatteryExemption`).
  - `EventChannel("com.jeevalink/events")`: Streams native async events to Flutter (`MESSAGE_RECEIVED`, `PEERS_DISCOVERED`, `STATUS_CHANGED`, `STT_RESULT`).
- **Core Functions:**
  - `configureFlutterEngine()`: Initializes managers and attaches listeners.
  - `startJeevaLinkBackgroundService()`: Launches `JeevaLinkForegroundService`.
  - `requestBatteryOptimizationExemption()`: Prompts user to disable Doze Mode battery saver limits.

#### `JeevaLinkForegroundService.kt`
- **Purpose:** Android `Service` running continuously in the background to ensure off-grid sockets stay connected when app is closed or screen is turned off.
- **Key Mechanics:**
  - **Foreground Service Type:** `connectedDevice` and `dataSync`.
  - **Ongoing Notification:** Displays `"⚡ JeevaLink Mesh Active"` notification.
  - **PowerManager.WakeLock:** Holds `PARTIAL_WAKE_LOCK` to keep CPU awake during screen-off states.
  - **Return Strategy:** `START_STICKY` for automatic recovery under RAM pressure.

#### `NotificationHelper.kt`
- **Purpose:** Creates and posts Android push notifications for received off-grid messages.
- **Channels:**
  - `jeevalink_emergency_channel` (High Priority): Triggered on `EMERGENCY` messages. Red accent (`#D32F2F`), heads-up alert banner, urgent vibration, expandable big text with **📍 GPS Coordinates**.
  - `jeevalink_normal_channel` (Default Priority): Triggered on `NORMAL` messages. Blue accent (`#1976D2`), WhatsApp-style status bar alert.
- **Deduplication:** Maintains thread-safe `processedMessageIds` set (500 items max) to suppress duplicate alerts.

#### `SocketManager.kt`
- **Purpose:** Manages TCP socket connections over Wi-Fi Direct local network on **Port 8888**.
- **Key Functions:**
  - `startServer()`: Opens `ServerSocket(8888)` listening for incoming peer packets.
  - `broadcastMessage()`: Sends JSON message packets across active TCP sockets.

#### `WifiDirectManager.kt`
- **Purpose:** Wraps Android `WifiP2pManager` for peer discovery, group creation, and connection info events.

#### `BluetoothManager.kt`
- **Purpose:** Bluetooth RFCOMM fallback connection manager. Scans nearby Bluetooth devices and maintains RFCOMM socket connections.

#### `SpeechManager.kt`
- **Purpose:** Android system native SpeechRecognizer bridge fallback.

---

### 3. 💙 **Flutter Application Core (`lib/`)**

#### `lib/main.dart`
- **Purpose:** Application entry point and startup permission wrapper (`PermissionWrapper`).
- **Startup Workflow:** Initializes `SttTtsService`, requests permissions (`location`, `microphone`, `notification`, `nearbyWifiDevices`, `bluetooth`), launches `JeevaLinkForegroundService`, and renders `MainNavigationScreen`.

#### `lib/models/message_packet.dart`
- **Purpose:** Data model representing off-grid message packets transmitted across the mesh.
- **Fields:**
  - `id` (String): Unique identifier (e.g. `MSG-92831` or `SOS-49120`).
  - `type` (String): `EMERGENCY` or `NORMAL`.
  - `language` (String): Language code (e.g., `en`, `ta`, `hi`, `te`).
  - `text` (String): Message body text.
  - `latitude`, `longitude` (double): GPS location coordinates.
  - `ttl` (int): Time-To-Live hop limit (default 3 to 5).
  - `timestamp` (String): ISO-8601 timestamp.
  - `isSelf` (bool): Local sender flag.

#### `lib/services/stt_tts_service.dart`
- **Purpose:** Local Speech-to-Text (STT) using `sherpa_onnx` and Text-to-Speech (TTS) using `flutter_tts`.
- **Speech Engine Details:**
  - Records 16kHz mono WAV audio using `record`.
  - Passes audio samples to `sherpa_onnx.OfflineRecognizer`.
  - Supports English (`model.int8.onnx`) and dynamic Indic language loading (`tamil`, `hindi`, `telugu`).
- **Fuzzy Emergency Keyword Detector:**
  - Scans transcripts against emergency keywords (`SOS`, `FLOOD`, `TRAPPED`, `FIRE`, `RESCUE`, `MEDICAL`).
  - Uses Levenshtein distance ($\le 2$) matching to auto-escalate priority to `EMERGENCY`.

#### `lib/services/mesh_manager.dart`
- **Purpose:** Multi-Hop Store-and-Forward and packet deduplication engine.
- **Key Logic:**
  - `processIncomingPacket()`: Checks `LinkedHashSet` cache of 1000 IDs. Drops duplicates. Saves to 24h storage. Decrements `ttl` and re-broadcasts to nearby nodes if `ttl > 0`.
  - `syncStoredPacketsToPeer()`: Auto-syncs historical message buffers when a new peer connects.

#### `lib/services/native_bridge.dart`
- **Purpose:** Dart wrapper for `MethodChannel("com.jeevalink/bridge")` and `EventChannel("com.jeevalink/events")`.

#### `lib/services/local_storage_service.dart`
- **Purpose:** Manages 24-hour local JSON persistent storage in application document directory with auto-pruning.

#### `lib/services/gps_service.dart`
- **Purpose:** Manages device GPS positioning streams via `geolocator`.

#### `lib/services/model_downloader_service.dart`
- **Purpose:** Dynamically downloads quantized INT8 ONNX speech models (`tamil_model.int8.onnx`, `hindi_model.int8.onnx`, `telugu_model.int8.onnx`) from GitHub Releases with live progress callbacks.

#### `lib/utils/gps_calculator.dart`
- **Purpose:** Calculates Haversine distance in meters/km and bearing in radians/degrees between GPS coordinates.

---

### 4. 📱 **UI Screens (`lib/screens/`)**

#### `main_navigation_screen.dart`
- **Purpose:** Root Scaffold containing bottom navigation bar with 5 tabs: **PTT Chat**, **Radar Map**, **Panic SOS**, **Message History**, and **Settings**.

#### `home_screen.dart`
- **Purpose:** Primary Push-To-Talk (PTT) voice recording interface and 24-hour live mesh feed. Features tap/hold mic button, text transcript box, emergency mode toggle, and message feed.

#### `emergency_panic_screen.dart`
- **Purpose:** High-priority SOS broadcast interface.
- **Key Features:**
  - Tapping **TAP SOS** triggers a **10-Second Countdown Modal**.
  - **Light Glassmorphism UI:** Translucent frosted glass (`BackdropFilter` 16x16), refractive border, and glowing neon edge shadow.
  - **Top-Right Timer Badge:** Live countdown (`10s` $\rightarrow$ `0s`).
  - **Clickable NO Button:** Immediately cancels the alert without raising any alarm.
  - **Read-Only YES Indicator:** Auto-dispatch badge showing remaining seconds (non-clickable).
  - Auto-broadcasts emergency packet with GPS location when countdown reaches 0s.

#### `radar_screen.dart`
- **Purpose:** Interactive 360° animated radar sweep map displaying nearby off-grid mesh nodes scaled by Haversine distance and bearing.

#### `connection_screen.dart`
- **Purpose:** Wi-Fi Direct and Bluetooth peer discovery, device pairing, and connection management list.

#### `settings_screen.dart`
- **Purpose:** User profile editor, display name settings, language selector, multi-hop TTL slider, storage pruner, and **Background Mesh Execution** status card.

---

## 🤖 System Context Guide for Future AI Assistants

```text
================================================================================
JEEVALINK AI SYSTEM ASSISTANT CONTEXT & PROTOCOLS
================================================================================
1. ARCHITECTURE PATTERN:
   - Frontend: Flutter (Material 3 UI, Dart)
   - Native OS Core: Kotlin (Android MainActivity + Foreground Service)
   - Messaging Protocol: JSON MessagePackets transmitted over TCP Sockets (Port 8888) and Bluetooth RFCOMM.
   - Offline Speech AI: Sherpa-ONNX Whisper INT8 Models running 100% on-device.

2. CRITICAL BACKGROUND EXECUTION RULE:
   - Sockets must NEVER be killed when the screen turns off.
   - Android execution relies on `JeevaLinkForegroundService.kt` holding a `PowerManager.PARTIAL_WAKE_LOCK` and declared under `connectedDevice|dataSync` foregroundServiceType.

3. EMERGENCY DISPATCH RULE:
   - Emergency packets have `type: "EMERGENCY"` and maximum priority.
   - Emergency SOS triggers a 10s countdown modal in `emergency_panic_screen.dart`. The user can ONLY click "NO" to cancel. "YES" is an automatic read-only indicator.

4. MESH RELAY & DEDUPLICATION:
   - Every packet has a unique `id` (e.g. `SOS-49A12`).
   - `MeshManager` maintains a 1000-item deduplication cache. Duplicates are silently dropped.
   - Packets decrement `ttl` by 1 and auto-relay to nearby peers if `ttl > 0`.
================================================================================
```
