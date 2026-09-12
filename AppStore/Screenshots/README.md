# Kyuva App Store screenshots

## Ready-to-upload assets

- `Mac/en/` contains five English macOS screenshots at 1440 x 900.
- `iPhone-6.9/en/` contains the five English product-page screenshots at 1320 x 2868.
- `Watch-Series-10/en/` contains the English Watch screenshot at 416 x 496.
- All final assets are opaque RGB JPEGs and show the signed or exact-source candidate UI with non-private demo content.

## Editable iPhone source

The `Studio/` directory is a lightweight overlay for the installed `app-store-screenshots` skill template. It intentionally does not vendor the template or its dependencies.

1. Scaffold the current skill template into a disposable directory.
2. Copy the contents of `Studio/` into that directory.
3. Add the object from `Studio/kyuva-theme.json` to `THEMES` in `src/lib/constants.ts`.
4. Run the editor and export the iPhone bundle.

The iPhone story order is deliberate: core prompting, privacy, Voice Follow, scripting, then fine control. Update the raw captures before changing claims or shipping a new UI. The Mac captures are authentic signed-build windows rather than editor mockups.
