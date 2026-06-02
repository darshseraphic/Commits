# Asrio

Asrio is an <b>advanced, privacy-first habit, routine, and lifestyle companion engineered</b> for individuals who value absolute <b>data sovereignty, high consistency, and digital hygiene</b>. Decoupled completely from external cloud networks, the platform operates as a secure hardware-bound lifestyle dashboard where all state mutations, analytical rendering, and critical notification scheduling execute deterministically on-device.

## The Core Need

Modern performance software often acts as a data-harvesting vehicle disguised as self-improvement utilities. Users are <b>forced to barter granular details of their daily life, sleep timetables, and emotional journal writing to centralized backend architectures, creating distinct problems</b>:

* **Exploitative Gamification Loops:** Systems optimized to manipulate attention spans and maximize application open-times rather than cultivating tangible habit completion loops.
* **Centralized Security Targets:** Cloud databases exposing highly specific personal lifestyle metrics to tracking networks, profiling, or breaches.
* **Brittle Reminders:** Server-reliant worker configurations that silently fail or suffer delivery lag due to OS background battery optimization restrictions and bad system handshakes.

Asrio establishes an unyielding **local-first counter-measure**. It encapsulates your routines entirely within the device boundaries, engineering a quiet, reliable infrastructure focused solely on structured personal discipline.


## Target Audience

Asrio is meticulously designed for a precise subset of power users:
* **Data Sovereignty Minimalists:** Technologists who refuse to register daily waking histories, private thoughts, or localized timetables onto third-party servers.
* **High-Performance Professionals:** Power users needing a distraction-free tracking environment lacking intrusive UX popups, unnecessary leveling models, and notification overhead.
* **System Purists:** Users expecting immediate visual rendering and zero execution latency.

## Architectural Workflow Overview

The platform uses a modular, layered configuration combining cross-platform framework efficiency with low-level platform architecture bridges to guarantee reliable routine monitoring.
```text
       [ Cross-Platform View Layer (Flutter/Dart) ]
                            │
                            ▼
         [ Architectural State Engine (BLoC Model) ]
                            │
         ┌──────────────────┴──────────────────┐
         ▼                                     ▼
[ Platform Notification Bridge ]     [ Sandboxed Persistence Core ]
         │                                     │
         ▼                                     ▼
(Android Native AlarmManager APIs)    (SQLCipher / Local DB Relational File)
```

### 1. Sequential Initialization Cycle

When the underlying application process boots, the core framework handles an synchronized startup sequence before mounting any interface components to prevent state corruption:

* **Native Framework Hydration:** Initializes method bindings and registers system platform channels.
* **Encrypted DB Isolation Check:** Opens an active connection handle to the secure local engine, testing schema structure mapping and preparing database views.
* **Hardware-Level Alarm Validation:** Synchronizes local configuration values with the operating system's active notification queues to ensure no updates are dropped.
* **Memory Hydration Stage:** Loads past completion histories into states, immediately serving components to eliminate visual layout shifts.

### 2. Routine Lifecycle Execution Model
* **Creation and Encoding:** A newly declared custom routine passes down into isolated data entities and commits locally using ACID-compliant transactions.
* **Immutable OS Registration:** An asynchronous handler hooks directly into low-level platform libraries (`AlarmManager` on Android) to map the exact microsecond timestamp into the device's hardware alarm configuration.
* **Deterministic Execution:** When the alarm triggers, the host OS spawns a high-priority background worker process to dispatch the reminder event instantly, bypassing standard runtime sleeping routines even if the app process has been terminated.

## Comprehensive Module Breakdown

The user layout splits cleanly across a bottom-mounted navigation system controlling five specific operational sub-systems:

### 1. Tab 1: Home Dashboard
Acts as your immediate centralized command grid containing operational status widgets:
* **Daily Wellbeing Matrix:** A comprehensive visual synthesis of completion data points across active behavioral habits.
* **Tactical Routines Overview:** An active listing of incomplete items flagged for immediate processing.
* **Milestones Progress Indicator:** Real-time feedback calculating local goal completions and leveling tiers.
* **Most Used Application Monitor:** A secure dropdown menu displaying localized analytics tracking usage distributions, system notification telemetry patterns, screen-time volume, and device battery consumption profiles.

### 2. Tab 2: To-Do Tasks
An integrated task engine managing structured micro-goals, separating long-term ambitions from urgent tasks:
* **Dual-Horizon Workspace:** A switchable system that separates daily tracking components from yearly milestone tracking maps via a simple toggle.
* **Dynamic Split-Layout Canvas:** The interface isolates completed rows in the top viewport while tracking pending checklist rows in the scrollable bottom view. Tapping elements transfers entities across blocks seamlessly via smooth list reordering animations.

### 3. Tab 3: Daily Diary
A secure, localized writing environment replicating tactical analog note-taking:
* **Analog Presentation System:** Features real-time formatting options such as Lined Notebook themes or Grid/Graph paper overlays restricted strictly to code-defined minimalist hex codes (`#FBFBFB`, `#FFFFFF`, `#1C1C1C`, `#1C1D21`).
* **Rich Typography Options:** Includes custom handwriting fonts paired with a context-aware toolbar supporting markdown variations like bolding, italicizing, and underlining configurations.
* **Intelligent Image Pasting:** An auto-arranging layout engine mimicking a physical scrapbook. 16:9 media cards fill the complete horizontal width, while 1:1 square media assets balance rows side-by-side using real-time aspect calculations and entry paste animations.
* **Dynamic UI Controls:** When writing notes, the global application bottom navbar smoothly slides off-screen, expanding vertical screen real estate. Exiting via the "Close Book" control executes a beautiful book-closing animation before returning to the main dashboard navigation stack.

### 4. Tab 4: Consistency Matrix
An analytics pipeline mapping habits and system usage into actionable charts without passing telemetry data over the network:
* **Habit Time Pie Matrix:** Aggregates behavioral patterns (e.g., active study periods, resting lengths) by correlating user-input statistics directly with phone app usage diagnostics.
* **Granular Calendar Heatmap:** Displays circle-based grid elements for the active month, allowing smooth horizontal scrolling across historical months. Circles utilize proportional grey-to-black density shading: lighter greys mark minimal checklist entries, while deep blacks signify detailed diary logs.
* **Daily Frequency Graph:** A 24-hour vertical Y-axis and day-of-month X-axis chart tracking app openings. Individual entries render as pinpoint coordinates, linked by an optimized trend line chart to map lifestyle routines.

### 5. Tab 5: Settings Core
Provides complete control over localized properties, diagnostic details, and compliance configurations:
* **Global Theme Layer:** App-wide switches to quickly enforce Light, Dark, or System mode states.
* **Granular Reminder Channels:** Custom independent notification settings to schedule alerts for diaries and tasks.
* **Interactive Manual Walkthroughs:** Includes detailed visual structural diagrams explaining app functionality without relying on network lookups.

## Technical Security & Data Privacy Framework

Asrio treats user telemetry as non-negotiable personal assets:
* **Hardened Storage Sandbox:** Media attachments, relational database configurations, and profile attributes are kept strictly inside private app directories.
* **Cryptographic Data Lockdown:** Persistence models utilize **SQLCipher relational database encryption**, locking files with high-grade 256-bit AES protection directly on disk.
* **Zero-Telemetry manifest:** Complete exclusion of remote analytic engines, diagnostic collection scripts, or automated cloud monitoring bugs.
* **Physical Guard Controls:** Features platform-native biometric hardware calls (FaceID and Fingerprint integrations) to create a barrier against local device access.
* **AI Safeguards:** Your personal database contents are explicitly protected from AI model training loops or parsing pipelines.

## Technical Production Specifications

### Modern Directory Layout

```code
Asrio/
├── lib/                             # Core cross-platform logic module
│   ├── UI/                          # UI rendering layers
│   │   ├── home/                    # Dashboard view controllers
│   │   │   └── homescreen.dart
│   │   ├── todo/                    # To-Do engine view views
│   │   │   └── todoscreen.dart
│   │   ├── diary/                   # Notebook view layers
│   │   │   └── Diaryscreen.dart
│   │   ├── consistency/             # Chart fragments
│   │   │   └── consistencyFragment.kt
│   │   └── settings/                # Settings management
│   │       └── settingsFragment.kt
│   └── data/                        # Local persistence layer
│       ├── db/                      # Relational tables and DAO queries
│       ├── model/                   # Pure object modeling definitions
│       └── repository/              # Repository abstractions
└── res/                             # Native Android resource configurations
    ├── layout/                      # Native component views
    ├── drawable/                    # System vectors and graphics
    ├── anim/                        # Lottie configuration files
    ├── font/                        # Custom handwriting TrueType files
    └── navigation/                  # Core nav component navigation graphs
```

### Key Libraries Utilized

* **Architecture and Navigation:** Jetpack Navigation Component handles seamless fragment swapping and state routing.
* **Persistence Core:** Room / SQLCipher handles encrypted database caching layers.
* **Render Pipeline:** ViewPager2 guides book-style swiping, Glide optimizes local image loading, and StaggeredGridLayoutManager manages scrapbook asset layouts.
* **Visualization Layer:** MPAndroidChart renders smooth vector lines, data points, and pie matrixes.
* **Motion Graphics Engine:** Lottie handles fluid book-closing, page-turning, and scrapbook insertion animations.

### Hardened Android Native Manifest Setup

To guarantee that alerts bypass aggressive OS power-saving states, the system uses low-level native permissions:

```xml
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />

<application>
    <receiver 
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
        android:exported="false"/>
        
    <receiver 
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
        android:exported="true">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED"/>
            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
        </intent-filter>
    </receiver>
    
    <receiver 
        android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"
        android:exported="false"/>
</application>

```

### Complete Internationalization (i18n) Engine

Asrio features a native internationalization engine supporting 20+ languages out of the box, mapping localized keys efficiently through code structures.

```dart
// Production i18n Data Structures
class AppLanguage {
  final String code;
  final String name;
  final String flag;
  const AppLanguage({required this.code, required this.name, required this.flag});
}

const List<AppLanguage> kAppLanguages = [
  AppLanguage(code: 'en', name: 'English', flag: ''),
  AppLanguage(code: 'de', name: 'Deutsch', flag: ''),
  AppLanguage(code: 'fr', name: 'Français', flag: ''),
  AppLanguage(code: 'es', name: 'Español', flag: ''),
  AppLanguage(code: 'it', name: 'Italiano', flag: ''),
  AppLanguage(code: 'pt', name: 'Português', flag: ''),
  AppLanguage(code: 'hu', name: 'Magyar', flag: ''),
  AppLanguage(code: 'ro', name: 'Română', flag: ''),
  AppLanguage(code: 'tr', name: 'Türkçe', flag: ''),
  AppLanguage(code: 'ru', name: 'Русский', flag: ''),
  AppLanguage(code: 'uk', name: 'Українська', flag: ''),
  AppLanguage(code: 'zh', name: '简体中文', flag: ''),
  AppLanguage(code: 'ja', name: '日本語', flag: ''),
  AppLanguage(code: 'ko', name: '한국어', flag: ''),
  AppLanguage(code: 'vi', name: 'Tiếng Việt', flag: ''),
  AppLanguage(code: 'ar', name: 'العربية', flag: ''),
  AppLanguage(code: 'id', name: 'Indonesia', flag: ''),
  AppLanguage(code: 'th', name: 'ภาษาไทย', flag: ''),
  AppLanguage(code: 'hi', name: 'हिन्दी', flag: ''),
  AppLanguage(code: 'nl', name: 'Nederlands', flag: ''),
  AppLanguage(code: 'pl', name: 'Polski', flag: ''),
  AppLanguage(code: 'sv', name: 'Svenska', flag: '')
];

```

# Active Roadmap

* **Battery Subsystem Tweaks:** Polishing background receivers across restrictive, non-standard OEM Android skins.
* **Optimized Relational Queries:** Tuning query speeds for long-term multi-year habit histories.
* **Encrypted Air-Gapped Backups:** Building local backup systems to allow full data transfers without using cloud connections.

#

<p align="center">
  <a href="https://github.com/darshseraphic/Asrio/blob/main/update/phases.md">
    <img src="https://img.shields.io/badge/CHECK_UPDATES-000000?style=for-the-badge&logo=github&logoColor=white" alt="Check Updates" />
  </a>
</p>
