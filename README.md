<img src="logo.png" alt="iMeasure" width="400">

# iMeasure

An iOS AR measurement app built with Flutter and ARKit. Point, tap, and measure real-world distances and areas using your phone's camera.

## Features

- **Line mode** — Place 2 points on any surface to get the distance between them (cm + ft/in).
- **Triangle mode** — Place 3 points to compute triangle area and perimeter.
- **Quadrilateral mode** — Place 4 points to compute quadrilateral area and perimeter.
- **Live preview** — See real-time distance lines as you move the phone before confirming each point.
- **Clear crosshair** — Center-screen targeting for precise point placement.
- **No-tap surface detection** — Uses `performHitTest` every frame on the `updateAtTime` callback for smooth live preview.

## How to use

1. Open the app and point the camera at a flat surface.
2. Choose **Line**, **Triangle**, or **Rectangle** at the top.
3. Aim the center crosshair at your first point and tap **+**.
4. Move to the next corner and tap **+** again. A dotted line shows between confirmed points.
5. Repeat for remaining points. Results appear in the top card.
6. Tap **Clear** to start over.

## Requirements

- iOS device with A9 chip or later (iPhone 6S+)
- iOS 15.0+
- Built with Flutter 3.41.9

## Tech stack

- **ARKit** via [`arkit_plugin`](https://pub.dev/packages/arkit_plugin) for scene rendering, hit testing, and 3D node placement
- Flutter for the UI layer
- `vector_math` for 3D vector math
- `permission_handler` for camera permission flow

## Project structure

```
lib/
  main.dart                  — App entry point
  screens/
    home_screen.dart         — Permission gate and launch
    measure_screen.dart      — AR measurement interface (all modes)
```

## Build & run

```bash
flutter pub get
flutter run
```

Target an iOS device (physical, not simulator) — ARKit requires a real camera.

## License

MIT — see [LICENSE](LICENSE).
