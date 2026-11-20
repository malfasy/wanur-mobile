# WanurGlove - MediGrip Controller

## WanurGlove Test
[Magic Tiles 3 online game](https://www.onlinegames.io/magic-tiles-3/)

## 📱 Download & Installation

**Download the latest APK:**
[📥 WanurGlove App on Google Drive](https://drive.google.com/drive/folders/1a0nJ_TjHy-hr9B7Rpw8kH4_aciL5Jybn?usp=sharing)

### System Requirements
- **Platform:** Android
- **Minimum Version:** Android 6.0 (API 23)
- **Bluetooth:** BLE 5.0 or higher
- **Permissions Required:** Bluetooth, Bluetooth Scan, Bluetooth Connect, Location

---

## Logbook latihan dan dashboard progres (branch `feature/logbook-dashboard`)

Fitur baru: **Riwayat Latihan** (sesi terekam otomatis saat layar latihan terbuka), **Tes Genggam** terpandu 3 percobaan, dan **Progres Pemulihan** (kepatuhan, tren genggam, menit aktif per minggu, sebaran jari, target mingguan, ringkasan PDF untuk terapis). Semua nilai gaya adalah nilai relatif (kg*), belum dikalibrasi dengan dinamometer.

Menjalankan dan menguji tanpa glove:

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # build debug: ikon Pengaturan Pengembang muncul di Beranda
adb shell input keyevent KEYCODE_F   # tekanan keypad tiruan (juga G, H, J)
```

- Mode simulasi dan impor 10 profil pasien: Pengaturan Pengembang. Profil dibuat ulang dengan `python3 tools/generate_profiles.py`.
- T1 test case: `docs/T1_test_cases.md`
- T2 kesesuaian indikator: ekspor dari Pengaturan Pengembang, lalu `python3 tools/verify_indicators.py indicators_all_profiles.json`
- T3 waktu muat: `docs/T3_procedure.md` dan `tools/summarize_t3.py`
- Catatan implementasi dan perbedaan dari desain: `docs/IMPLEMENTATION_NOTES.md`

---

## 🎮 Getting Started

### 1️⃣ First Time Setup

#### Step 1: Pair the Device
1. Turn on your **MediGrip-Controller** (ESP32C3 glove device)
2. Open **Android Settings** → **Bluetooth**
3. Search for available devices
4. Find and tap **"MediGrip-Controller"**
5. Tap **"Pair"** to complete pairing
6. Wait for confirmation: "Connected"

#### Step 2: Install & Launch App
1. Download the APK from the Google Drive link above
2. Enable **"Install from Unknown Sources"** if prompted
3. Install the app
4. Open **WanurGlove** app
5. Grant all required permissions (Bluetooth, Location)

#### Step 3: Auto-Connect
- The app will **automatically detect** and connect to your paired MediGrip-Controller
- Wait 2-5 seconds for connection
- ✅ Status will show: **"Connected to MediGrip-Controller"**

> **Note:** First-time connection takes ~5-8 seconds. Subsequent connections are instant (~2 seconds) using saved MAC address.

---

## 🕹️ How to Use

### Main Features

#### 1. **Grip Measurement** (Loadcell Sensor)
Measure hand grip strength in real-time.

**Steps:**
1. From home screen, tap **"Start Measure"**
2. Put on the glove
3. Squeeze the grip sensor
4. View live readings (kg) on screen
5. Data is auto-saved to local database
6. View history in measurement screen

**Indicators:**
- 🟢 **Green:** Normal grip (10-30 kg)
- 🟡 **Yellow:** Weak grip (< 10 kg)
- 🔴 **Red:** Strong grip (> 30 kg)

---

#### 2. **Finger Calibration** (Touch Sensors)
Test and calibrate touch sensor response for each finger.

**Steps:**
1. From home screen, tap **"Start Calibration"**
2. Choose calibration mode:
   - **Touch Test:** Free testing mode
   - **Guided Calibration:** Step-by-step finger testing

**Guided Calibration:**
1. Screen shows target finger (e.g., "MOVE INDEX FINGER (f)")
2. Touch the corresponding sensor on your glove
3. Badge turns **green** when detected
4. Automatically moves to next finger
5. Sequence: **Pinky → Ring → Middle → Index**
6. Shows **"CALIBRATION SUCCESS!"** when complete

---

### Connection Management

#### Auto-Connect Features
- **Instant Connect:** Uses saved MAC address for 2-second connection
- **Smart Detection:** Automatically finds "MediGrip-Controller" in paired devices
- **Fallback Scan:** Scans if instant methods fail

#### Manual Retry
If connection fails:
1. Tap the **🔄 Refresh icon** in top-right corner
2. Wait for auto-detection
3. Check notifications for connection status

#### Disconnect
- Tap the **Bluetooth icon** in top-right corner when connected
- Device will disconnect immediately

---

## 🔧 Troubleshooting

### ❌ "No Device Connected"
**Solution:**
1. Ensure MediGrip-Controller is **turned on**
2. Check it's **paired** in Android Bluetooth settings
3. Tap **🔄 Retry** button in the app
4. If still failing, unpair and re-pair the device

### ❌ App Can't Find Device
**Solution:**
1. Go to Android Settings → Bluetooth
2. Check if "MediGrip-Controller" is in **Paired devices** list
3. If not listed, pair it first (see Step 1 above)
4. Return to app and tap retry

### ❌ Stuck on "Auto-connecting..."
**Solution:**
1. Close and reopen the app
2. Turn Bluetooth OFF then ON
3. Restart the MediGrip-Controller device
4. Force stop app in Android settings and relaunch

### ❌ Sensors Not Responding
**Solution:**
1. Check battery level of MediGrip device
2. Verify glove is worn correctly
3. Go to Calibration screen to test individual sensors
4. Disconnect and reconnect Bluetooth

---

## 📊 Technical Specifications

### Hardware
- **Controller:** ESP32-C3 (BleKeyboard mode)
- **Sensors:**
  - Loadcell (HX711) for grip strength
  - 4x Touch sensors (capacitive) for finger detection
- **Communication:** Bluetooth Low Energy 5.0
- **Service UUID:** `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Characteristic UUID:** `beb5483e-36e1-4688-b7f5-ea07361b26a8`

### Software
- **Framework:** Flutter
- **State Management:** Provider
- **Local Database:** SQLite (sqflite)
- **BLE Library:** flutter_blue_plus
- **Supported Platforms:** Android only

### Data Protocol
- **Loadcell Data:** Integer strings (e.g., "1234") sent every 500ms
- **Keymap Data:** 4-character UTF-8 strings (e.g., "fghj")
- **Encoding:** UTF-8

---

## 🎯 Features

✅ **Bluetooth Low Energy** connectivity  
✅ **Auto-connect** with MAC address caching  
✅ **Real-time** loadcell readings (500ms interval)  
✅ **Touch sensor** calibration & testing  
✅ **Local database** for session history  
✅ **Dynamic greeting** based on time of day  
✅ **Instant retry** with loading indicators  
✅ **Smart device detection** (works with HID mode)  

---

## 📝 Version History

### v1.0.0
- Initial release
- BLE connectivity with ESP32C3
- Grip measurement feature
- Finger calibration system
- Auto-connect with MAC caching
- Local SQLite database

---

## 👨‍💻 Developer

**Project:** WanurGlove - MediGrip Controller  
**Platform:** Flutter (Android)  
**BLE Device:** ESP32-C3 with BleKeyboard library

---

## 📄 License

This project is part of a rehabilitation device development initiative.

---

## 🆘 Support

For issues or questions:
1. Check the **Troubleshooting** section above
2. Ensure your device is properly paired in Android Bluetooth settings
3. Verify app has all required permissions
4. Try the **Retry** button in the app

**Remember:** The MediGrip-Controller must be **paired** in Android Bluetooth settings before the app can connect!



