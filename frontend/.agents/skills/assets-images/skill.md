# Flutter Assets & Images Skill

## Description
Active reference for handling images and other bundled assets. Load this skill
when declaring assets, loading local images, caching network images, or using
custom icons. Core package choices (also summarized in AGENTS.md §10): `spider`
for local image references, `cached_network_image` for network images, and
`hugeicons` for custom icons.

## Assets and Images
* **Image Guidelines:** If images are needed, make them relevant and meaningful,
  with appropriate size, layout, and licensing (e.g., freely available). Provide
  placeholder images if real ones are not available.
* **Asset Declaration:** Declare all asset paths in your `pubspec.yaml` file.

    ```yaml
    flutter:
      uses-material-design: true
      assets:
        - assets/images/
    ```

* **Local Images:** Use the `spider` package to generate type-safe asset
  references. Run `spider` to generate the static `const` variables (this
  project generates the `AppImages` class — see `spider.yaml`), then pass the
  generated constant to `Image.asset` instead of an unreliable raw `String`
  path.

    ```dart
    // Preferred: pass the spider-generated static const.
    Image.asset(AppImages.placeholder)

    // Avoid: hard-coded, error-prone string paths.
    // Image.asset('assets/images/placeholder.png')
    ```
* **Network images:** Prefer caching network images using `CachedNetworkImage`
  from the package `cached_network_image` instead of using `NetworkImage` to
  load images from the network; always include `loadingBuilder` and
  `errorBuilder` for a better user experience.
* **Custom Icons:** Use the package `hugeicons` for custom icons instead of the
  material icons available from the `Icons` class.
