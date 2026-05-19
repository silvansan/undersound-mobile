# ablaut launch screen (iOS)

Replace the images in this imageset to customize the iOS launch screen shown while Flutter starts.

Recommended approach:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select **Runner → Assets.xcassets → LaunchImage** in the Project Navigator.
3. Drop in `@1x`, `@2x`, and `@3x` PNGs based on `app/assets/ablaut-logo.png` or `ablaut-launcher-icon.png` from the Flutter project root (`app/assets/`).

Use a simple centered logo on a solid background (`#0F2D25` matches the Android adaptive icon background) so the splash matches the ablaut brand.

Alternatively, edit `ios/Runner/Base.lproj/LaunchScreen.storyboard` for a single scalable layout instead of fixed launch images.
