# cabal

Flutter's biggest open secret.

## Build instructions

1. `git submodule update --init --recursive`
2. Edit the `flutter_gpu` path in `pubspec.yaml` to match your local engine checkout.
3. Edit the `IMPELLERC` path in `deps.sh`
4. Run `deps.sh`.
5. `flutter run -d macos`
