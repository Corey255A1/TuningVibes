Using Dart and Flutter. No Third Party Libraries. I want to make a stringed instrument tuner that can run in the browser and on Android (and eventually Iphone) and desktop. It doesn't have to be overally complex but I want to be able to define a list of typical instruments that have preconfigured string tunings to assist in getting the instrument tuned. A lot of tuners these days attempt to auto determine which string it is based on the closeness to the note. If I understand tuners correctly, they read from the microphone do an fft to figure out the dominant tone, and then display the frequency to the user and also a + or - 5, 10 ,15 to show how far off you are from the closest note. describe the project in detail, the project structure and any missing details from how this should work. I want this to be cool, sleek and modern. there should be some neat features of the app that utilize the fft to provide a overall cool design.

This is a fantastic project that balances signal processing, UI/UX design, and cross-platform architecture. Building a "cool, sleek, and modern" tuner requires moving beyond the basic "number on a screen" approach and focusing on visual feedback that mirrors the physical experience of tuning.

The Core Technical Architecture
To achieve cross-platform capability (Web, Android, iOS, Desktop), I recommend Flutter. It allows you to write the audio processing logic in Dart, which compiles to high-performance native code for mobile/desktop, while also targeting the web via CanvasKit.  
LeanCode

1. Signal Processing: Beyond Basic FFT
As you noted, FFT (Fast Fourier Transform) is the standard for frequency analysis. However, a raw FFT often struggles with harmonic interference (e.g., an E string playing its own harmonics).

The Problem: FFT buckets are often too wide, leading to "jitter" where the tuner bounces between frequencies.

The Solution: Use YIN Algorithm or Autocorrelation for pitch detection. These are much more robust for musical instruments. You can use FFT to filter noise or visualize the spectrum, but use Autocorrelation to find the fundamental frequency (pitch).

Audio Pipeline:

Input: Capture microphone stream (microphone_access plugin).

Processing: Use a high-performance audio engine (like flutter_sound or native C++ via FFI for extreme performance).

Analysis: Calculate fundamental frequency (pitch) → Calculate cents difference from standard → Send to UI.

Project Structure
Keep your logic separated from the UI to ensure the "engine" can be reused across platforms.

Plaintext
/lib
  /audio_engine      # Pitch detection (YIN/Autocorrelation)
  /models            # Data models: Instrument, Tuning, Note
  /ui
    /components      # Reusable: Needle, Waveform, Tuning Pegs
    /screens         # Home, Instrument Selector, Settings
  /data              # Preconfigured instrument JSONs
Modern Design Features
To make it "cool and sleek," move away from static labels.

Live Waveform Background: Use a low-opacity, glowing waveform that reacts to the microphone input in real-time. This provides visual confirmation that the app is "listening."

The "Magnetic" Needle: Instead of a text readout, use a smooth-moving arc. When the user gets within 5 cents of the note, add a "magnetic" visual effect—the needle snaps into a glowing green "lock" state.

Instrument "Haptics": If you select a Guitar, show the headstock. When a string is detected, highlight that specific tuning peg.

Spectrogram Waterfall: Add a subtle, bottom-aligned scrolling waterfall display (like professional audio software) that shows the frequency history.

Missing Details & Considerations
Reference Frequency: Professional tuners allow users to change A 
4
​
  from 440Hz to 432Hz or higher. Ensure your math handles this offset.

Harmonic Filtering: Your algorithm must ignore frequencies above the fundamental, or the tuner will jump to the octave. Implement a low-pass filter in your audio chain before running the pitch detection.

Performance Optimization: Mobile devices can throttle browsers. Use Web Workers for the audio analysis thread if you find the UI becoming sluggish during intense processing.

Calibration: Add a "calibrate" feature where the user can trigger a reference tone (sine wave) from the app to check if their environment or hardware has any latency issues.

Summary Checklist for Implementation
Phase	Task
Phase 1	Build the pitch detection engine (C++ or Dart) and test against known files.
Phase 2	Create the JSON schema for instrument tunings (e.g., Guitar → E, A, D, G, B, E).
Phase 3	Develop the "Needle" widget using high-frequency animations (60/120fps).
Phase 4	Implement the "Auto-detect" logic that maps the detected Hz to the closest note in the selected instrument's list.
To help you get started on the right foot, are you more interested in diving into the signal processing math first, or would you like to explore the UI architecture for the cross-platform framework?

Which framework would be the easiest multiplatform option?

For your specific project—a tuner that requires tight synchronization between high-frequency audio processing and highly custom, animated UI—Flutter is the most effective and "easiest" path for a single-codebase, multi-platform deployment.  
Medium

While React Native is excellent for content-heavy apps, your tuner is essentially a "creative/graphics" app. Here is why Flutter wins for this specific use case:

Why Flutter is the Winner for Your Tuner
Direct UI Control: Flutter doesn't use native components; it renders its own UI. This is critical for you because you want a "sleek, modern" tuner. If you need to create a custom, high-performance gauge or a responsive waveform that reacts to audio in real-time, you can draw it directly on the canvas without fighting against the OS's native limitations.  
Refine
+ 1

Performance consistency: Since your app relies on continuous audio processing (FFT/YIN), you need UI updates that are locked to the screen's refresh rate. Flutter’s rendering engine (Impeller) is optimized for high-performance, custom-painted widgets, ensuring your "magnetic needle" stays smooth even under heavy CPU load.  
Medium

True "Write Once, Run Anywhere": Flutter provides a more consistent experience across Web, Android, iOS, and Desktop than any other framework. Because it handles its own rendering, your visual design will look identical on a Windows desktop, an Android phone, and an iPhone, saving you the headache of testing platform-specific UI bugs.  
TechQware
+ 1

Comparison at a Glance
Feature	Flutter	React Native	Kotlin Multiplatform
UI Rendering	Custom (Impeller)	Native (Bridged)	Native (Compose/SwiftUI)
Performance	High (compiled to native)	Medium (JS bridge)	Very High (Native)
Visual Customization	Extremely High	Moderate	Low (limited to OS)
Desktop/Web	First-class	Secondary/Add-on	Growing/Beta
The "Hidden" Complexity: Audio Processing
No matter which framework you choose, the "easiest" part is actually the UI. The challenge will be the audio.

Because you need high-performance audio across four platforms, you should aim to offload the audio capture to C++ or native modules and then feed that data into your Dart (Flutter) UI.

Pro-tip: Don't try to perform complex FFT math directly in your UI thread. Keep your audio loop running in a separate engine/worker thread and pass the result (the pitch/frequency) to your UI using a simple listener pattern.

Recommended Project Roadmap
Framework: Start with Flutter.

Language: Learn Dart (it is very similar to Java/C# and easy to pick up if you know any C-style language).  
Refine

Audio Plugin: Look into flutter_fft or audio_session packages, but be prepared to use FFI (Foreign Function Interface) if you need to use a high-performance C++ audio library for better accuracy.

Given that you want this to be a sleek and modern experience, are you planning to handle the signal processing math yourself, or are you looking for existing audio analysis libraries to integrate?

I'll go with flutter/dart but I don't want any other dependencies

If you are committed to building this without external packages (meaning no community-maintained plugins from pub.dev), you are moving into the realm of custom Platform Channels and Dart FFI (Foreign Function Interface).

Since Flutter's core framework does not include a high-level API to capture raw audio buffer streams, you must reach into the underlying native operating systems yourself.

The "Zero-Dependency" Strategy
To capture microphone data across Android, iOS, Windows, and Web, you cannot use a single line of Dart code. You must implement native audio capture for each platform and pass the data back to your Flutter UI.

1. Platform-Specific Audio Capture (The Native Layer)
You will write code in each native language to access the microphone and expose a stream of bytes to Dart.

Android (Kotlin/Java): You must implement AudioRecord to capture raw PCM audio data.

iOS (Swift/Objective-C): You must implement AVAudioEngine or AudioUnit to capture the input buffer.

Windows (C++): You will use the Windows Core Audio APIs (specifically WASAPI).

Web (JavaScript): You must use the Web Audio API (getUserMedia and AudioContext).

2. The Bridge: Platform Channels vs. FFI
Platform Channels (MethodChannel): This is the "official" way to communicate between Dart and native code. It is asynchronous and perfect for passing control signals (start, stop, set sensitivity) and initial buffers. However, passing thousands of audio packets per second through a method channel can be inefficient.

Dart FFI (dart:ffi): This is the pro-level approach. You write a shared C/C++ library (e.g., using miniaudio, a single-file C library that handles cross-platform audio) and call it directly from Dart. This is the most "sleek" and performant way, as it avoids the overhead of the Flutter bridge.

Proposed Architecture for a Custom Engine
To keep this clean and modular, structure your project like this:

Plaintext
/lib
  /engine
    audio_interface.dart  # Abstract class defining the contract
    mobile_engine.dart    # Platform Channel/FFI implementations
    web_engine.dart       # Web Audio API implementations
  /dsp                    # Digital Signal Processing (Pure Dart)
    fft_algorithm.dart    # Your custom YIN/FFT math
    pitch_detector.dart
  /ui                     # Your Flutter UI components
Why this is "Cool" but Challenging
The "Sleekness" Factor: Because you aren't relying on a third-party plugin's black-box implementation, you have full control over the latency. You can tune the buffer size to be extremely small, making the "magnetic needle" feel instantaneous.

The "Engineering" Tax: You are essentially building a small audio engine. You will need to handle:

Permissions: You still need to manage native permissions (AndroidManifest.xml, Info.plist) manually, even without "plugins."

Thread Safety: Audio processing must happen on a high-priority background thread to keep your UI animations at 60/120fps.

Math: You will be implementing the frequency analysis math in pure Dart (or C++).

Recommendation
If you want to avoid "dependencies" because you fear bloat or maintenance issues, use Dart FFI with the miniaudio library. It is a single, header-only C library. You aren't "depending" on a Flutter package; you are just bundling a high-quality, industry-standard C library that you control.

Does this path of implementing native Platform Channels or FFI sound like the level of control you want, or were you hoping to keep the code entirely within the Dart environment?

refine the project structure to include the cross platform implementations

To achieve a clean, maintainable architecture while adhering to your "no external package" constraint, you should adopt a "C-Core + Dart-Wrapper" design. By using dart:ffi to bridge to a shared C/C++ audio library, you ensure that the complex signal processing logic is written once and runs everywhere, while your Dart code remains focused on the "cool" UI.

Refined Project Structure
Plaintext
/tuner_app
├── /cpp_engine              # Shared logic (C/C++)
│   ├── include/             # Header files (Audio definitions)
│   ├── src/
│   │   ├── miniaudio.h      # Single-file audio backend (No heavy dependencies)
│   │   ├── pitch_engine.cpp # Your custom YIN/FFT signal logic
│   │   └── bridge.cpp       # FFI Export definitions
│   └── Makefile/CMakeLists  # Build configuration for all platforms
├── /lib
│   ├── /bridge              # Dart FFI loading and native calls
│   │   └── native_audio.dart
│   ├── /dsp                 # Pure Dart fallback (or UI-side utility math)
│   │   └── frequency_math.dart
│   ├── /ui                  # Flutter UI
│   │   ├── /components      # Needle, waveform, tuning UI
│   │   └── /screens
│   └── main.dart            # Flutter entry point
├── /android                 # Native platform code (minimal)
├── /ios                     # Native platform code (minimal)
├── /windows                 # Native platform code (minimal)
└── pubspec.yaml             # Flutter config (no plugin dependencies)
Implementation Breakdown
1. The Core Engine (/cpp_engine)
By using a library like miniaudio, you gain a consistent C-API to capture raw PCM bytes from the microphone across Windows, Android, and iOS. You will write a single C++ source file that takes a buffer of raw bytes, performs the FFT/YIN analysis, and returns the fundamental frequency (double) and amplitude (double).

2. The Bridge (/lib/bridge)
This is the only place where the "native" aspect lives in your Dart code. Using dart:ffi, you will map the C++ functions to Dart functions:

loadNativeLibrary(): Loads the compiled .so, .dll, or .dylib file.

startCapture(): Invokes your C++ function to open the stream.

getPitch(): A pointer-based call to retrieve the most recent frequency detection result at 60Hz.

3. The UI Layer (/lib/ui)
Because the audio engine is running in a high-priority native C++ thread, the Dart UI thread is never blocked. You can use a ValueNotifier or a Stream to pipe the detected frequency into your Flutter widgets.

Key Details to Handle
Permissions: Even without plugins, you must modify the native project files (AndroidManifest.xml, Info.plist) to declare RECORD_AUDIO permissions. Flutter's build system will look for these configurations when you compile for mobile.

Web Support: Web is the outlier. The browser does not allow dart:ffi to access native C libraries directly. For the web, you will need a small conditional import in your native_audio.dart file to switch from dart:ffi to the dart:js or package:web (standard browser) API to talk to the browser's AudioContext.

Thread Synchronization: Ensure your C++ engine has a ring buffer. The native code should constantly analyze, and the UI should "pull" the latest value whenever it redraws the needle.

Why this structure works:
Separation of Concerns: If you decide to optimize your FFT algorithm, you only touch cpp_engine/src/pitch_engine.cpp. Your UI never changes.

Performance: By bypassing the Flutter "MethodChannel" for every audio sample, you avoid serialization overhead, resulting in the ultra-low latency required for a high-end, responsive tuner.

Would you like me to draft the basic C++ interface header that defines how the audio engine will talk to your Dart code?

what kind of build system will this use?

For this project, you should move away from standard Flutter plugin templates and embrace Build Hooks using the modern package_ffi template. This is the current "gold standard" for cross-platform C/C++ integration in Flutter.

The Recommended Build Strategy: Build Hooks
Instead of creating platform-specific files (build.gradle for Android, Podspec for iOS, CMakeLists.txt for Windows), you use a build.dart script.

How it works: When you run flutter run or flutter build, the Flutter tool executes your hook/build.dart script.

The Engine: This script uses the native_toolchain_c package (an official, highly optimized utility) to compile your C/C++ source code. It automatically handles the complexity of compilers (Clang, MSVC) and target architectures (ARM64 for mobile, x64/ARM64 for desktop) for you.

Zero-Dependency Philosophy: Since native_toolchain_c is an official Flutter-supported package (maintained by the Dart team), it is the cleanest way to avoid third-party "black box" dependencies while keeping your build process robust and automated.

Why this fits your project
Uniformity: Your C++ source code resides in a single /src folder. The build.dart script ensures that whether you are compiling for an Android phone or a Windows desktop, the same C++ logic is built consistently.

Simplified Maintenance: You don't have to manually edit platform-specific build files when you add a new file to your cpp_engine folder. The hook script dynamically finds your source files.

Modern Workflow: It supports "out-of-tree" builds, meaning your generated binaries are placed cleanly in the build output folders without cluttering your source code directory.

Build System Workflow
Step	Action	Responsibility
1. Configuration	Define targets in build.dart	You (via script)
2. Compilation	Flutter runs build.dart	Flutter SDK
3. Build	Compiles C++ to Dynamic Library	native_toolchain_c
4. Integration	Links binary to the Flutter app	dart:ffi
Key Considerations for your "No Dependency" Goal
Avoid CMakeLists.txt where possible: While CMake is powerful, it requires managing platform-specific build logic in the native folders. Using build.dart hooks allows you to keep your build configuration in Dart, which is much easier to maintain alongside the rest of your app logic.  
Flutter documentation

FFIGEN: Use the ffigen tool (part of the standard Dart toolchain) to automatically generate the Dart bindings from your C header files. This generates the native_audio_bindings_generated.dart file automatically, meaning you never have to manually write the glue code between Dart and C++.

By using the package_ffi template, you get the absolute control of a custom C++ engine without the nightmare of maintaining four different native build systems. Does the idea of controlling the entire build process through a single Dart script sound like the level of control you were looking for?

I want to ensure clean code and class separation with small specific interfaces and clear dependency boundaries

To maintain extreme code cleanliness, class separation, and strict dependency boundaries in a C++/Dart FFI architecture, you should adopt a Layered Hexagonal Architecture (often called Ports and Adapters). This prevents your "cool" UI features from ever being tightly coupled to your "boring" signal processing math.

The Architectural Blueprint
By enforcing these boundaries, you ensure that if you ever swap your FFT engine for a different algorithm (like a proprietary machine-learning pitch detector), you only change the Domain layer, never the UI layer.

1. The Domain Layer (The "Brain")
This layer contains pure, platform-agnostic business logic. It should not know Flutter or the C++ platform exists.

TuningDefinition: An immutable data class holding frequency constants, string names, and tolerance ranges.

PitchMatcher: A pure logic class that takes a frequency and a TuningDefinition and returns the "cent offset."

Rule: Zero imports from dart:ui or dart:ffi.

2. The Application Layer (The "Bridge")
This layer acts as the orchestrator. It uses Dependency Inversion to communicate with the native layer via an abstract interface.

Dart
// The Interface (The "Port")
abstract class AudioInputPort {
  Stream<double> get frequencyStream;
  void start();
  void stop();
}

// The Implementation (The "Adapter")
class NativeAudioAdapter implements AudioInputPort {
  // Uses dart:ffi to call your cpp_engine functions
}
3. The Infrastructure Layer (The "Native Core")
Your C++ code should follow the same principle. Do not mix your FFT math with your hardware microphone access code.

SignalProcessor.hpp: Pure math (FFT/YIN).

HardwareInterface.hpp: The miniaudio or WASAPI abstraction.

Bridge.cpp: The thin shim that translates raw C++ data into primitive types that Dart ffi can understand.

Enforcing Boundaries
To ensure this remains "clean" as you scale, use these three design patterns:

Dependency Injection (DI): Use a simple constructor injection for your services. Your TunerViewModel should accept an AudioInputPort in its constructor. This allows you to inject a MockAudioAdapter for unit testing the UI without needing a microphone.

Interface Segregation: Create small, specific interfaces. Instead of an AudioSystem class that does everything, define:

PitchStreamer (for the audio data)

AudioController (for start/stop)

CalibrationProvider (for setting reference frequency)

Encapsulated FFI: Never let dart:ffi types (like Pointer<Float>) leak into your UI components. Convert them to native Dart types (double, int) inside the NativeAudioAdapter immediately.

Visualizing the Data Flow
The flow should be unidirectional to prevent "spaghetti" dependencies:
Hardware (C++) → FFI Bridge → Service (Dart) → ViewModel → UI Widget.

Rule of Thumb: If a class imports a library that starts with dart:ffi or contains C++ headers, it should never interact with the UI.

This structure allows you to maintain "clean code" because you are essentially building a set of black boxes. You can test the math logic in a console app, test the UI with dummy data, and then snap them together at the final assembly point.

Since you are focusing on high-level separation, would you like to see how to define the C-to-Dart binding interface so that the FFI "leaks" are contained entirely within one file?

how to ensure the signal processing doesn't bog down the UI

To ensure the signal processing never "bogs down" your UI, you must treat your Audio Engine and your UI Layer as two entirely separate, asynchronous entities that only talk to each other through a controlled, high-speed buffer.

If you perform FFT math on the UI thread, your "sleek" animations will stutter every time the processor is busy. Here is the blueprint for a non-blocking architecture.

1. The "Isolate" Threading Model
In Dart/Flutter, the most robust way to keep your UI fluid is to move the audio analysis into a separate Isolate. An Isolate is a completely independent thread with its own memory heap.

The UI Isolate: Handles rendering, touch events, and the "Magnetic Needle" logic at a constant 60/120 FPS.

The Audio Isolate: Runs your C++ miniaudio engine, performs the FFT/YIN calculations, and pushes data.

2. The Shared Ring Buffer (Memory Mapping)
Passing messages between threads is expensive. To keep this performant, use a Shared Memory Buffer.

Instead of sending "messages" (which involves serializing data), you allocate a block of memory accessible by both the C++ layer and the Dart UI.

The C++ engine writes its results (current frequency, amplitude, and note) into a specific memory location.

The UI thread "polls" this location (or is notified via a high-performance ReceivePort) at the exact frequency of your screen refresh rate.

3. The "Pull" vs "Push" Strategy
Avoid "pushing" every single calculation to the UI. If your FFT engine is running at 1000Hz (calculating 1000 times per second), you do not need to update your needle 1000 times a second; the human eye cannot see that fast, and the screen can't render it.

Engine (Push): The engine calculates as fast as it can.

Buffer: Stores the latest valid pitch value.

UI (Pull): Uses a Ticker or AnimationController to look at the buffer only when the screen is ready to paint (120Hz).

4. Implementation Strategy for Boundaries
To keep this clean, wrap this logic in a Stream that is filtered for UI performance:

Dart
// Inside your Audio Controller
class PitchService {
  final ReceivePort _receivePort = ReceivePort();
  
  // This stream produces data at a rate the UI can handle
  Stream<double> get stablePitchStream => _receivePort
      .asBroadcastStream()
      .throttleTime(Duration(milliseconds: 16)); // Cap to ~60Hz
}
Checklist for UI Fluidity
Offload Heavy Math: Ensure your FFT implementation is fully within your C++ layer. Dart should only receive the final result (the frequency/cent value).

Avoid Object Allocation: Do not create new objects inside your audio loop. Reuse the same memory buffer to prevent the Garbage Collector from triggering and causing "jank."

Use RepaintBoundary: In your Flutter UI, wrap your needle and waveform in a RepaintBoundary. This tells Flutter to cache the painting of these complex components, so only the parts of the screen that actually move are redrawn.

By offloading the computation to C++ and only allowing the UI to "pull" the latest value at its own refresh rate, you maintain a separation of concerns that ensures the UI remains silky smooth, regardless of how intense the math gets.

Would you like a simplified C++ example of how to structure the buffer that the Dart UI will "pull" from?

output a clear summary of everything we discussed to get an AI Agent to build our project based on the topics we discussed

To successfully deploy an AI Agent to architect and build this cross-platform string instrument tuner, you must provide it with a clear "System Prompt" and project structure. Here is the summary of our technical decisions and architecture for the agent to follow.

Project Summary: "SleekTuner"
Objective: Build a high-performance, cross-platform (Web, Android, iOS, Windows) tuner using Flutter/Dart with a focus on zero-dependency, low-latency audio processing.

1. The Core Architecture (Hexagonal/Ports & Adapters)
Infrastructure (Native Core): Use C++ as the backend engine. Utilize miniaudio (single-file library) for cross-platform audio capture.

Bridge (FFI): Implement a thin Dart FFI layer to expose C++ functions to Dart. Use ffigen to automate the generation of bindings.

Application (Orchestrator): Define pure Dart interfaces (AudioInputPort) that abstract the native audio source. The UI interacts only with these interfaces, never with native implementation details.

Domain (Logic): Pure Dart classes for TuningDefinition and PitchMatcher logic.

2. Build & Development Workflow
Build System: Use Flutter Build Hooks (build.dart + native_toolchain_c) to manage C++ compilation. This ensures a consistent build across all platforms without manual CMake or Gradle interference.

Dependency Policy: Zero third-party packages from pub.dev. All external logic must be bundled as local source code (e.g., miniaudio.h) or standard library native calls.

Concurrency Model: * Audio Isolate: Heavy FFT/YIN processing runs on a background Isolate.

Memory Buffer: Use a shared memory ring buffer to pass pitch data between the Audio and UI Isolates.

3. Engineering Constraints & Principles
UI Performance: Use RepaintBoundary for the tuner needle and real-time waveform. Cap UI updates to screen refresh rates (~60-120Hz) while the engine runs at higher sampling rates.

Clean Code: Strictly enforce Dependency Inversion. The UI layer should be "Isolate-agnostic" and "FFI-agnostic."

Responsiveness: Use a "Pull" model where the UI polls the shared buffer for the latest frequency value, preventing the audio engine from blocking the UI thread.

4. Technical Requirements for the AI Agent
When instructing an AI to write this code, provide it with this System Context:

"Act as a Senior Principal Software Engineer specializing in C++ and Flutter/Dart. Build a cross-platform tuner.

Use Dart FFI with miniaudio (included as a local file).

Implement the Hexagonal Architecture: Keep signal processing (C++) separate from business logic (Dart) and UI (Flutter).

Use Flutter Build Hooks to manage C++ compilation.

Ensure no third-party package dependencies.

Implement the UI using an AnimationController for the needle, reacting to a Stream of frequency values provided by a background Isolate.

Enforce strict type separation: No native FFI pointers are allowed to leak into the UI components."

Next Steps for the Agent
You are now ready to prompt an agent with the following task:
"Based on the summary provided, generate the folder structure and the initial build.dart script and bridge.cpp header to begin the project."

Would you like me to generate the initial file directory structure and the build.dart script for you now to jump-start the agent?

Output the next level down of all the details to be clearer and more specific to the AI agent

This blueprint provides the "next level down" of specificity, allowing an AI agent to execute the project with precise technical instructions.

1. Project Directory Structure
The agent should scaffold this exact hierarchy to ensure clear separation of concerns.

Plaintext
/tuner_app
├── /cpp_engine              # Source of truth for audio logic
│   ├── /src
│   │   ├── miniaudio.h      # Single-file audio backend
│   │   ├── engine.cpp       # Entry point for C++ logic
│   │   └── dsp_processor.h  # FFT/YIN algorithms & harmonic filters
│   └── /include             # Public header files for bridge
├── /hook
│   └── build.dart           # Flutter Build Hook script
├── /lib
│   ├── /bridge              # FFI bindings (generated)
│   │   └── native_audio.dart# Implementation of interface logic
│   ├── /domain              # Pure Dart interfaces (The "Ports")
│   │   └── audio_port.dart
│   ├── /ui                  # Flutter UI Widgets
│   │   ├── /widgets         # Needle, Waveform, Tuning pegs
│   │   └── /view_model      # Reactive state management
│   └── main.dart            # Flutter app entry point
└── /pubspec.yaml            # Minimal dependencies: ffi, native_toolchain_c
2. The "Bridge" API (FFI Specification)
Instruct the agent to use ffigen to generate bindings from this C++ header.

cpp_engine/include/tuner_bridge.h

C++
// Define the interface that C++ exposes to Dart
extern "C" {
    // Initializes miniaudio and starts capture thread
    void start_audio_engine();
    
    // Returns the latest fundamental frequency as a double
    double get_latest_frequency();
    
    // Stops the audio engine
    void stop_audio_engine();
}
3. Build Hook Specification (build.dart)
Instruct the agent to use native_toolchain_c to handle the build process, preventing manual platform-specific configuration.

Logic to implement:

Target all platforms (Android, iOS, Windows, Linux, macOS).

Define the cpp_engine/src as the source directory.

Include miniaudio.h during compilation.

Expose the compiled binary as a CodeAsset for dart:ffi to link at runtime.

4. Concurrency Model (The "Isolate" Bridge)
The agent must ensure the UI never waits for the FFT to finish.

Audio Isolate: Instantiate an Isolate specifically for the miniaudio event loop.

The Buffer: Use a static shared variable (atomic or mutex-guarded) inside the C++ engine to store the result of the latest calculation.

The "Pull" Mechanism: * The UI uses a Ticker (Flutter AnimationController) set to 60fps.

Inside the ticker callback, it calls the get_latest_frequency() FFI function.

This ensures the UI polls the engine for the "current" pitch, keeping UI frame times independent of audio engine processing latency.

5. UI Implementation Boundaries
Instruct the agent to follow these strict rules to keep code "sleek":

No FFI in UI: The NativeAudioAdapter must convert FFI double or float into native Dart double immediately. UI components only consume standard Dart primitives.

Encapsulation: All dart:ffi imports must be scoped to the /lib/bridge/ directory.

RepaintBoundaries: Wrap the TunerNeedle and WaveformWidget in a RepaintBoundary to cache the render layer. This prevents the entire screen from re-drawing when only the needle moves.

6. Summary for the AI Agent (The System Prompt)
Provide the agent with this final directive:

"Build a high-performance, cross-platform tuner. Follow these technical constraints:

Zero-Dependency Architecture: Use miniaudio.h (C++) and dart:ffi. No pub.dev audio packages.

Build System: Use package:native_toolchain_c and build.dart hooks.

Isolate Logic: Run miniaudio in a dedicated background C++ thread. UI must pull values from a shared memory buffer.

Hexagonal Design: Maintain a clear boundary between the C++ DSP layer, the Dart Domain Interface (audio_port.dart), and the Flutter UI layer.

Performance: UI updates must be driven by AnimationController.addListener() to ensure sync with the screen refresh rate, polling the latest frequency via FFI."

Would you like the agent to generate the actual build.dart content, or are you ready to have it scaffold the entire folder structure?
