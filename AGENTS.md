# Limu Mobile Design Notes

- The visual source of truth is `https://github.com/gochi20/Iosmobiledesign.git`.
- Preserve the native SwiftUI implementation. Tabs: Home, Shipments (Cargo is a segment inside it), Order Forms, Invoices, Profile, with global Notifications. Cargo was folded into Shipments after the 14 Oct 2026 review, which freed a tab for Invoices.
- Core palette: charcoal `#161A1C`, copper `#D38239`, peach `#F3CBA1`, cream `#F5F0EC`, surface `#FEFEFE`.
- Use 16-point screen margins, 14-point card radii, compact status capsules, and SF Symbols for interface icons.
- Use `LimuColors`, `LimuCard`, `SectionCard`, `StatusBadge`, and the shared field/button components before introducing new styling.
- Keep the original Limu logo asset. Do not replace visible assets or icons with emoji, text glyphs, handcrafted SVGs, or placeholder shapes.
- The app talks to the Limu client API (`Api/v4/client`, see `API-INTEGRATION.md`); demo data only appears with the `--logged-in` launch argument.
- KYC choices (business categories, sizes, goods/service categories, interests, occupations) come from `kyc/options.php`, which reads `classes/kyc-catalog.php` in the portal repo. `KYCOptions.swift` is only an offline fallback; change the portal catalog first, then regenerate the fallback.
- Once KYC is Completed, identity and business fields are locked: change them through a KYC change request, never `profile/index.php` or `kyc/index.php`.
