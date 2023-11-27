# cabal

Flutter's biggest open secret.

## Build instructions

1. `git submodule update --init --recursive`
2. Edit the `flutter_gpu` path in `pubspec.yaml` to match your local engine checkout.
3. Change the macOS/iOS `DynamicLibrary.open` path in `deps/flutter_bullet/lib/flutter_bullet.dart` to `libflutter_bullet.1.0.0.dylib`.
4. Run `deps.sh`.
5. `flutter run -d macos`
