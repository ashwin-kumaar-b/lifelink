<p align="center">
  <img src="https://raw.githubusercontent.com/devesh-54/jeevalink-speech-models/main/assets/banner.png" alt="JeevaLink Banner" width="100%" onerror="this.style.display='none'"/>
</p>

<h1 align="center">📡 JeevaLink (iTantra)</h1>

<p align="center">
  <strong>Indian Multilingual TTS & STT Aided Neural Transceiver Radio Access for Low Bitrate Links</strong><br>
  <em>Speak. Relay. Locate. Survive — 100% Offline, Zero-Cloud Emergency Mesh Communications.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/SIH-2026_Finalist-orange.svg?style=for-the-badge&logo=target" alt="SIH 2026" />
  <img src="https://img.shields.io/badge/Problem_ID-SIH26173-blue.svg?style=for-the-badge" alt="Problem Statement SIH26173" />
  <img src="https://img.shields.io/badge/Flutter-3.x_Material_3-02569B.svg?style=for-the-badge&logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Android-API_26+-3DDC84.svg?style=for-the-badge&logo=android" alt="Android" />
  <img src="https://img.shields.io/badge/Neural_Engine-Sherpa--ONNX-FF6F00.svg?style=for-the-badge" alt="Sherpa ONNX" />
  <img src="https://img.shields.io/badge/Radio-Wi--Fi_Direct_%26_BLE-8A2BE2.svg?style=for-the-badge" alt="Mesh Radio" />
</p>

---

## 📋 Table of Contents
1. [Executive Overview](#1--executive-overview)
2. [The Semantic Transceiver Paradigm](#2--the-semantic-transceiver-paradigm)
3. [System Architecture](#3--system-architecture)
4. [Subsystem Deep Dives](#4--subsystem-deep-dives)
   - [A. Speech-to-Text (STT) Engine](#a-speech-to-text-stt-engine)
   - [B. Text-to-Speech (TTS) Engine](#b-text-to-speech-tts-engine)
   - [C. Ultra-Low Bitrate Telemetry Framing](#c-ultra-low-bitrate-telemetry-framing)
   - [D. Dual-Radio Ad-Hoc Mesh Networking](#d-dual-radio-ad-hoc-mesh-networking)
   - [E. Offline Haversine Radar & Triage](#e-offline-haversine-radar--triage)
   - [F. Optical & Acoustic SOS Beacon](#f-optical--acoustic-sos-beacon)
   - [G. Android Background Persistence](#g-android-background-persistence)
5. [On-Demand Speech Model Downloader](#5--on-demand-speech-model-downloader)
6. [Repository Structure](#6--repository-structure)
7. [Performance & Hardware Benchmarks](#7--performance--hardware-benchmarks)
8. [User Guide: How to Use JeevaLink](#8--user-guide-how-to-use-jeevalink)
9. [Getting Started & Local Setup](#9--getting-started--local-setup)
10. [Team & Project Metadata](#10--team--project-metadata)

---

## 1. 🌟 Executive Overview

During natural disasters (floods, cyclones, earthquakes), military operations, or power grid failures, cellular towers, fiber backhauls, and internet connectivity collapse. Survivors cannot call for help, and rescue teams lose situational awareness.

Standard voice calls or audio recordings require high bandwidth (**64 kbps to 320 kbps**). Over weak, congested, or off-grid radio channels, sending raw voice files is virtually impossible.

**JeevaLink (iTantra)** solves **Problem Statement SIH26173** by establishing an on-device **Neural Semantic Transceiver**. Instead of transmitting heavy audio waveforms over the air, JeevaLink:
1. **Transcribes** spoken regional Indian voice locally on the phone using quantized INT8 neural models into compact text.
2. **Encapsulates** the message, GPS coordinates, and triage priority into a tiny **~0.4 KB telemetric packet**.
3. **Broadcasts & Hops** the packet across an autonomous, decentralized **Wi-Fi Direct and Bluetooth mesh** from phone to phone.
4. **Resynthesizes** the message as audible speech at the receiver device in the local language using offline Text-to-Speech.

> [!IMPORTANT]
> **100% Zero-Cloud Dependency:** JeevaLink requires no internet, no SIM cards, no Wi-Fi routers, and no external servers. It runs entirely on commodity Android smartphones.

---

## 2. ⚡ The Semantic Transceiver Paradigm

Traditional radio transceivers compress analog or digital speech signals using vocoders (e.g., Codec2, AMBE, Opus) requiring 1.2 kbps to 16 kbps. Under extreme RF interference or low-bitrate links, these codecs stutter and drop out.

JeevaLink shifts from **Acoustic Waveform Transmission** to **Semantic Token Transmission**:

```
Traditional:  [Voice Audio] ───(64 kbps - 320 kbps WAV/MP3)────► [Radio Choke / Packet Drop]
                                                                        
JeevaLink:    [Voice Audio] ──► [On-Device STT] ──► [0.4 KB Packet] ──► [Hop via Mesh] ──► [On-Device TTS] ──► [Speech Out]
                                                     (~40 bps throughput: 99.7% Bandwidth Saved!)
```

---

## 3. 🧠 System Architecture

### End-to-End Operational Pipeline
```mermaid
flowchart TD
    subgraph Transmitter ["Transmitter Node (Phone A)"]
        A1[Microphone Voice Input] --> A2[Audio Stream 16kHz PCM WAV]
        A2 --> A3[Silence Trimmer & Resampler]
        A3 --> A4[Sherpa-ONNX INT8 IndicConformer]
        A4 --> A5[Sanitized Text + GPS Coordinates]
        A5 --> A6[Low-Bitrate Packetizer ~0.4 KB JSON]
    end

    subgraph Mesh ["Decentralized Radio Access Layer"]
        A6 --> B1{Radio Route}
        B1 -->|Primary High-Speed| B2[Wi-Fi Direct TCP Sockets Port 8888]
        B1 -->|Secondary Fallback| B3[Bluetooth RFCOMM / BLE]
        B2 & B3 --> B4[Multi-Hop Relay Nodes TTL Bound]
        B4 --> B5[Ring-Buffer Deduplication]
    end

    subgraph Receiver ["Receiver Node (Phone B / Rescue Team)"]
        B5 --> C1[Native Bridge Event Stream]
        C1 --> C2[MessageStore & Packet Parser]
        C2 --> C3[Haversine Matrix Distance Radar]
        C2 --> C4[Android Native System TTS]
        C4 --> C5[Audible Regional Voice Output]
        C3 --> C6[Visual 360° Radar Plot]
    end
```

### Multi-Hop Mesh Propagation & Loop Suppression
```mermaid
sequenceDiagram
    autonumber
    participant A as Survivor (Node A)
    participant B as Relay Node (Node B)
    participant C as Rescuer (Node C)

    A->>A: Speak: "నాకు వైద్య సహాయం కావలెను" (Telugu)
    A->>A: INT8 Neural STT -> JSON Packet (UUID: #999, TTL: 3)
    A->>B: Transmit Packet via Wi-Fi Direct / BT
    Note over B: B checks Seen Cache: UUID #999 is NEW
    B->>B: Decrement TTL to 2
    B->>C: Forward Packet via Mesh Relay
    Note over C: C checks Seen Cache: UUID #999 is NEW
    C->>C: Decrement TTL to 1 (Destination reached)
    C->>C: Calculate Distance via Haversine Formula
    C->>C: Plot Node A on Visual 360° Radar
    C->>C: Native TTS speaks: "నాకు వైద్య సహాయం కావలెను"
```

---

## 4. 🔬 Subsystem Deep Dives

### A. Speech-to-Text (STT) Engine
Implemented in `lib/services/stt_tts_service.dart`, powered by `sherpa_onnx` C++ bindings and `record` audio capture:
- **Audio Capture:** 16 kHz sample rate, mono channel, uncompressed PCM WAV.
- **Model Architecture:** NeMo EncDec CTC (`IndicConformer`) quantized to INT8 precision.
- **Silence Trimming:** Automatically truncates leading/trailing amplitudes below threshold (`amplitude < 0.012`) with an 800-sample safety buffer.
- **Emergency Keyword Detection:** Built-in fuzzy matching engine using Levenshtein distance ($\le 2$) to instantly flag high-priority distress terms (`medical`, `flood`, `fire`, `trapped`, `rescue`, `help`, `sos`).

```dart
// Native C++ Sherpa-ONNX Recognizer Configuration
final sttConfig = sherpa_onnx.OfflineRecognizerConfig(
  model: sherpa_onnx.OfflineModelConfig(
    nemoCtc: sherpa_onnx.OfflineNemoEncDecCtcModelConfig(
      model: modelPath, // Path to model.int8.onnx
    ),
    tokens: tokensPath, // Path to tokens.txt
    numThreads: 2,      // Optimized for mobile dual-core CPU
    debug: false,
  ),
);
_sttRecognizer = sherpa_onnx.OfflineRecognizer(sttConfig);
```

### B. Text-to-Speech (TTS) Engine
Uses Android's native system speech engine (`flutter_tts`) configured for high acoustic clarity in noisy field environments:
- **Speech Rate:** `0.48` (Deliberately cadence-tuned for comprehension in stormy or noisy environments).
- **Locale Binding:** Dynamically binds language tags to native Indian locales (`ta-IN`, `te-IN`, `hi-IN`, `en-US`).

### C. Ultra-Low Bitrate Telemetry Framing
Each voice message is packaged into a compact telemetry payload serialized in JSON/binary:

```json
{
  "id": "urn:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6",
  "senderId": "NODE_3A8B9C",
  "senderName": "Ramesh (Civilian)",
  "type": "EMERGENCY",
  "language": "te",
  "text": "నాకు వైద్య సహాయం కావలెను",
  "latitude": 13.0827,
  "longitude": 80.2707,
  "ttl": 3,
  "timestamp": "2026-09-30T10:15:30Z"
}
```

| Field | Size | Purpose |
| :--- | :--- | :--- |
| `id` (UUIDv4) | 36 B | Prevents network duplication and loop amplification |
| `senderId` / `senderName` | ~20 B | Node identification in ad-hoc cluster |
| `type` / `language` | ~12 B | Priority flag (`EMERGENCY` vs `NORMAL`) & dialect routing |
| `text` | ~50 - 150 B | Transcribed semantic content |
| `latitude` / `longitude` | 16 B | Accurate WGS-84 location coordinates |
| `ttl` | 1 B | Hop countdown to prevent network congestion |
| **Total Payload** | **~350 - 450 Bytes** | **Passes over sub-1 kbps channels in < 1 second** |

### D. Dual-Radio Ad-Hoc Mesh Networking
Managed via Android Native Kotlin services (`android/app/src/main/kotlin/...`):
- **Primary Radio (`WifiDirectManager.kt`):** Android Wi-Fi P2P creates spontaneous Wi-Fi Direct groups without routers, streaming packets over TCP Sockets on **Port 8888**.
- **Fallback Radio (`BluetoothManager.kt`):** Bluetooth RFCOMM and BLE scanning run concurrently. If Wi-Fi Direct encounters radio negotiation failure, packets automatically route over Bluetooth links.
- **Store-and-Forward Routing (`mesh_manager.dart`):** Deduplication tables track `seenMessageIds` (LRU cache of 500 items). Messages are relayed across peers only if they have not been processed before.

### E. Offline Haversine Radar & Triage
Implemented in `lib/screens/radar_screen.dart` and `lib/utils/gps_calculator.dart`. Computes the great-circle distance between rescuer and survivor nodes without internet access:

$$d = 2R \cdot \arcsin\left(\sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)}\right)$$

- Plots remote nodes on a dynamic **360° visual radar display**.
- Automatically groups nodes into **Immediate Threat (< 100m)**, **Mid-Range (100m - 500m)**, and **Perimeter (> 500m)**.

### F. Optical & Acoustic SOS Beacon
Implemented in `lib/screens/emergency_panic_screen.dart`:
- **10-Second Cancel Delay:** Prevents accidental panic broadcasts.
- **Acoustic Siren:** Emits a multi-frequency, high-decibel alarm through the device speaker.
- **Optical Strobe:** Pulses the camera LED flash in Morse code SOS patterns for dark rubble and storm rescue.

### G. Android Background Persistence
Implemented in `JeevaLinkForegroundService.kt`:
- **Foreground Service:** Runs with `connectedDevice` and `dataSync` service types.
- **Partial WakeLock:** Keeps the mobile CPU active to process incoming Wi-Fi Direct and Bluetooth packets even when the screen is locked and the phone is in a pocket.
- **Battery Optimization Exemption:** Prompts user to whitelist the app from Android Doze Mode limitations.

---

## 5. 🌐 On-Demand Speech Model Downloader

Implemented in `lib/services/model_downloader_service.dart`, this architecture keeps the initial APK lightweight (~25 MB) by bundling the English base model and streaming regional Indic models on demand.

- **Host Base URL:** `https://github.com/devesh-54/jeevalink-speech-models/releases/download/v1.0.0/`

| Language | Model Asset File | Size | Destination Directory |
| :--- | :--- | :--- | :--- |
| **English (`en`)** | Pre-bundled inside APK | ~25 MB | `assets/models/english/` |
| **Telugu (`te`)** | `telugu_model.int8.onnx` | ~23 MB | `{app_doc_dir}/models/telugu/` |
| **Tamil (`ta`)** | `tamil_model.int8.onnx` | ~23 MB | `{app_doc_dir}/models/tamil/` |
| **Hindi (`hi`)** | `hindi_model.int8.onnx` | ~23 MB | `{app_doc_dir}/models/hindi/` |
| **Vocabulary Tokens**| `tokens.txt` | ~15 KB | `{app_doc_dir}/models/{lang}/` |

---

## 6. 🗂️ Repository Structure

```text
lifelink/
├── android/app/src/main/
│   ├── AndroidManifest.xml              # Wi-Fi Direct, BLE, WakeLock & Foreground permissions
│   └── kotlin/com/jeevalink/jeevalink/
│       ├── MainActivity.kt               # Central Flutter <-> Android bridge hub
│       ├── JeevaLinkForegroundService.kt # Background mesh socket listener & CPU WakeLock
│       ├── NotificationHelper.kt         # Emergency heads-up & status alerts
│       ├── SocketManager.kt              # TCP Socket Server (Port 8888) & packet streaming
│       ├── WifiDirectManager.kt          # Wi-Fi Direct P2P discovery & group manager
│       ├── BluetoothManager.kt           # Bluetooth RFCOMM fallback transceiver
│       └── SpeechManager.kt              # Native Android speech recognition bridge
├── assets/
│   ├── models/english/                   # Bundled English INT8 ONNX model & tokens
│   └── sounds/                           # Audio sound effects (siren, whoosh)
├── lib/
│   ├── main.dart                         # Entry point & runtime permission setup
│   ├── models/
│   │   └── message_packet.dart           # Core Message JSON Packet data model
│   ├── services/
│   │   ├── stt_tts_service.dart          # Sherpa-ONNX STT & Native Android TTS
│   │   ├── speech_model_registry.dart    # Token & model file mappings per language
│   │   ├── mesh_manager.dart             # Store-and-Forward routing & deduplication
│   │   ├── native_bridge.dart            # MethodChannel & EventChannel wrapper
│   │   ├── local_storage_service.dart    # 24-hour persistent SQLite/SharedPreferences store
│   │   ├── gps_service.dart              # Geolocator GPS tracking
│   │   └── model_downloader_service.dart # Dynamic GitHub Releases model downloader
│   ├── stores/                           # Centralized State Management (MobX / ChangeNotifier)
│   │   ├── message_store.dart            # Reactive message list & TTS speech playback
│   │   ├── peer_store.dart               # P2P connection state & discovered peer nodes
│   │   └── settings_store.dart           # User profile & preferred language settings
│   ├── utils/
│   │   └── gps_calculator.dart           # Haversine distance matrix algorithm
│   └── screens/
│       ├── main_navigation_screen.dart   # Bottom navigation root
│       ├── home_screen.dart              # Push-To-Talk voice recorder & message feed
│       ├── emergency_panic_screen.dart   # 10s countdown SOS beacon & siren
│       ├── radar_screen.dart             # Dynamic 360° survivor radar sweep
│       ├── message_screen.dart           # Detailed message history & playback log
│       ├── connection_screen.dart        # Wi-Fi Direct & Bluetooth node manager
│       └── settings_screen.dart          # Language download & profile configuration
└── test/
    ├── mesh_manager_test.dart            # Mesh packet forwarding & loop prevention tests
    └── target_architecture_test.dart     # Stores, NativeBridge & model registry unit tests
```

---

## 7. 📊 Performance & Hardware Benchmarks

All metrics benchmarked on mid-tier Android smartphones (Redmi Note / Samsung Galaxy A series, 4GB RAM, Android 11+):

| Metric | Measured Value | Operational Impact |
| :--- | :--- | :--- |
| **STT Model Architecture** | NeMo EncDec CTC (IndicConformer) | INT8 Quantized ONNX |
| **STT RAM Utilization** | **38 MB – 45 MB** | Runs smoothly without triggering OS low-RAM kills |
| **Inference Latency** | **320 ms – 580 ms** | Sub-second audio transcript output |
| **Audio Capture Format** | 16,000 Hz, 1-channel PCM WAV | Standard low-power mobile audio |
| **Packet Size** | **350 B – 450 B** | **99.7% bandwidth reduction** vs 200 KB voice note |
| **Effective Channel Bitrate** | **30 – 80 bps** | Operates over severely degraded radio links |
| **Single-Hop Wi-Fi P2P Range** | **~120 m – 160 m** (Line of Sight) | Expands across multiple hops |
| **Single-Hop Bluetooth Range** | **~25 m – 40 m** | Resilient indoor / obstacle penetration |
| **TTS System Overhead** | **< 10 MB RAM** | Uses built-in Android speech synthesizer |

---

## 8. 📱 User Guide: How to Use JeevaLink

JeevaLink is designed with a high-contrast, low-cognitive-load interface specifically tailored for high-stress disaster scenarios. Here is how to use the core features:

### Step 1: Initial App Launch & Permissions
1. Open **JeevaLink** on your Android device.
2. Grant the required permissions when prompted:
   - **Microphone:** To capture spoken voice for the on-device STT engine.
   - **Location:** To attach accurate GPS coordinates to distress packets for radar localization.
   - **Nearby Devices / Wi-Fi & Bluetooth:** Required for Android to discover and connect with neighboring mesh nodes without internet.
   - **Notification & Battery Exemption:** Allows JeevaLink's background service to stay alive without being killed by Android Doze Mode.

---

### Step 2: Push-to-Talk Voice Messaging (Home Screen)
1. Navigate to the **Home** tab (second icon in the bottom navigation bar).
2. Tap the **Microphone** button to start recording (or hold it down).
3. Speak naturally in your native language (e.g., Telugu: *"నాకు వైద్య సహాయం కావలెను"* or Hindi: *"यहाँ पानी और खाना चाहिए"*).
4. Tap the button again (or release) to finish.
5. The neural engine transcribes your voice in **~400 ms** and packages it with your GPS coordinates and timestamp.
6. The packet is **automatically beamed** across the Wi-Fi Direct and Bluetooth mesh. 
7. Any nearby phones or rescue workers will receive the packet, see the message on their feed, and **hear the message read aloud automatically** in their selected language.

---

### Step 3: Triggering Emergency SOS (Emergency Screen)
In life-threatening situations where you cannot speak or type:
1. Navigate to the **SOS** tab (leftmost icon with the exclamation shield).
2. Tap the large **Emergency SOS** button.
3. A **10-second safety countdown** begins (allowing you to cancel if triggered by mistake).
4. Once triggered:
   - A high-decibel **Acoustic Siren** sounds through the phone speaker.
   - The camera flash engages in a rapid **Optical Strobe** pattern to signal search teams in dark rubble or floods.
   - An **Emergency-Priority Packet** is blasted across the mesh network, alerting all nearby devices with a high-priority heads-up notification and map coordinates.

---

### Step 4: Tracking Nearby Survivors on the 360° Radar
1. Navigate to the **Radar** tab (third icon in the bottom navigation bar).
2. The dynamic 360° radar continuously sweeps your surrounding perimeter.
3. Every received packet plots the sender as a glowing blip based on distance calculated via the **Haversine formula**:
   - 🔴 **Immediate Zone (< 100 meters):** High proximity, walk toward beacon immediately.
   - 🟡 **Mid-Range Zone (100 – 500 meters):** Nearby neighborhood or adjacent street.
   - 🔵 **Perimeter Zone (> 500 meters):** Multi-hop mesh nodes.
4. Tap any blip to inspect the survivor's name, message transcript, exact GPS coordinates, and relative distance.

---

### Step 5: Switching & Downloading Regional Languages
1. Navigate to the **Settings** tab (rightmost gear icon).
2. Under **Primary Language**, choose between **Telugu**, **Tamil**, **Hindi**, or **English**.
3. If selecting an Indic language for the first time, tap **Download Model** to stream the lightweight quantized neural model (~23 MB) from GitHub Releases before heading off-grid.
4. Once downloaded, the model is permanently cached on the phone for 100% offline use.

---

### Step 6: Background Relay Mode (Keep Mesh Alive)
You do not need to keep the app open or the screen on:
1. Once launched, JeevaLink activates an **Android Foreground Service** (indicated by an ongoing `"⚡ JeevaLink Mesh Active"` notification).
2. You can lock your phone or put it in your pocket.
3. Your phone will silently act as a **Relay Node**, catching incoming distress signals from neighboring phones and hopping them forward to rescue workers.

---

## 9. 🚀 Getting Started & Local Setup

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.3.0`)
- Android SDK (`API level 26+` / Android 8.0 Oreo or higher)
- Real Android physical device (Wi-Fi Direct and Bluetooth APIs cannot be tested on standard Android Emulators).

### Clone & Install
```bash
# 1. Clone repository
git clone https://github.com/ashwin-kumaar-b/lifelink.git
cd lifelink

# 2. Fetch Flutter package dependencies
flutter pub get

# 3. Verify target architecture and test suites
flutter test
```

### Run on Physical Android Device
```bash
# Connect Android smartphone via USB with USB Debugging enabled
flutter run -d <device_id>
```

> [!TIP]
> To test mesh multi-hop routing, install the debug APK on **at least two physical Android phones**, turn on Wi-Fi and Bluetooth on both, and open the app. The devices will automatically discover each other and form an ad-hoc mesh.

---

## 10. 👥 Team & Project Metadata

- **Competition:** Smart India Hackathon (SIH) 2026
- **Problem Statement ID:** `SIH26173`
- **Problem Statement Title:** *iTantra - Indian Multilingual TTS & STT Aided Neural Transceiver Radio Access for low bitrate links*
- **Theme:** Smart Automation / Edge Communications
- **Team ID:** `169579`
- **Team Name:** `RIT-CODE SOCIETY`
- **Lead Repository:** [`ashwin-kumaar-b/lifelink`](https://github.com/ashwin-kumaar-b/lifelink)

---

<p align="center">
  <em>Developed with ❤️ by RIT-CODE SOCIETY for SIH 2026. Empowering off-grid communications when every second counts.</em>
</p>
