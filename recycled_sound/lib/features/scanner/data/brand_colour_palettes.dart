import 'dart:ui' show Color;

/// A manufacturer's named colour option for a hearing aid.
class BrandColour {
  const BrandColour(this.name, this.color);

  /// Manufacturer's colour name, e.g. "Sand Beige", "Chroma Beige".
  final String name;

  /// Approximate sRGB colour for the swatch.
  final Color color;
}

/// Brand-specific colour palettes for hearing aid manufacturers.
///
/// When the scanner identifies a brand, these palettes narrow the colour
/// choice from the generic CIELAB palette (10 colours) to the manufacturer's
/// actual named colours (~5-8 per brand). The audiologist taps the exact
/// manufacturer colour name — faster and more precise than free text.
///
/// Sources: manufacturer product pages, fitting software colour pickers.
abstract final class BrandColourPalettes {
  /// Returns the colour palette for a brand, or null if unknown.
  static List<BrandColour>? forBrand(String brand) =>
      _palettes[brand.toLowerCase()];

  /// All brands that have palettes.
  static Iterable<String> get knownBrands => _palettes.keys;

  static const _palettes = <String, List<BrandColour>>{
    'phonak': [
      BrandColour('Sand Beige', Color(0xFFD4B896)),
      BrandColour('Champagne', Color(0xFFE8D5B7)),
      BrandColour('Silver Grey', Color(0xFFA8A9AD)),
      BrandColour('Graphite Grey', Color(0xFF5C5C5C)),
      BrandColour('Velvet Black', Color(0xFF2C2C2C)),
      BrandColour('Sandalwood', Color(0xFFC4A882)),
    ],
    'oticon': [
      BrandColour('Beige', Color(0xFFD4B896)),
      BrandColour('Silver', Color(0xFFA8A9AD)),
      BrandColour('Chroma Beige', Color(0xFFCBB78E)),
      BrandColour('Diamond Black', Color(0xFF2A2A2A)),
      BrandColour('Terracotta', Color(0xFFBE7B5E)),
      BrandColour('Steel Grey', Color(0xFF71797E)),
    ],
    'signia': [
      BrandColour('Beige', Color(0xFFD4B896)),
      BrandColour('Silver', Color(0xFFA8A9AD)),
      BrandColour('Graphite', Color(0xFF5C5C5C)),
      BrandColour('Black', Color(0xFF2C2C2C)),
      BrandColour('Rose Gold', Color(0xFFC9A087)),
      BrandColour('Espresso', Color(0xFF4A3728)),
    ],
    'widex': [
      BrandColour('Autumn Beige', Color(0xFFD4B896)),
      BrandColour('Champagne', Color(0xFFE8D5B7)),
      BrandColour('Silver Dawn', Color(0xFFB0B0B0)),
      BrandColour('Toffee', Color(0xFF8B5E3C)),
      BrandColour('Dark Slate', Color(0xFF4A4A4A)),
      BrandColour('Midnight Black', Color(0xFF1A1A1A)),
    ],
    'resound': [
      BrandColour('Warm Beige', Color(0xFFD4B896)),
      BrandColour('Light Blonde', Color(0xFFE8D5B7)),
      BrandColour('Dark Grey', Color(0xFF5C5C5C)),
      BrandColour('Sterling', Color(0xFFA8A9AD)),
      BrandColour('Cobalt Blue', Color(0xFF304B7A)),
      BrandColour('Black', Color(0xFF2C2C2C)),
    ],
    'starkey': [
      BrandColour('Champagne', Color(0xFFE8D5B7)),
      BrandColour('Silver', Color(0xFFA8A9AD)),
      BrandColour('Espresso', Color(0xFF4A3728)),
      BrandColour('Black', Color(0xFF2C2C2C)),
      BrandColour('Cool Grey', Color(0xFF8D9093)),
    ],
    'unitron': [
      BrandColour('Beige', Color(0xFFD4B896)),
      BrandColour('Champagne', Color(0xFFE8D5B7)),
      BrandColour('Silver Grey', Color(0xFFA8A9AD)),
      BrandColour('Espresso', Color(0xFF4A3728)),
      BrandColour('Black', Color(0xFF2C2C2C)),
    ],
    'bernafon': [
      BrandColour('Beige', Color(0xFFD4B896)),
      BrandColour('Silver Grey', Color(0xFFA8A9AD)),
      BrandColour('Graphite', Color(0xFF5C5C5C)),
      BrandColour('Chestnut', Color(0xFF8B5E3C)),
      BrandColour('Black', Color(0xFF2C2C2C)),
    ],
    'beltone': [
      BrandColour('Beige', Color(0xFFD4B896)),
      BrandColour('Silver', Color(0xFFA8A9AD)),
      BrandColour('Champagne', Color(0xFFE8D5B7)),
      BrandColour('Dark Grey', Color(0xFF5C5C5C)),
      BrandColour('Black', Color(0xFF2C2C2C)),
    ],
    'blamey saunders': [
      BrandColour('Beige', Color(0xFFD4B896)),
      BrandColour('Silver', Color(0xFFA8A9AD)),
      BrandColour('Black', Color(0xFF2C2C2C)),
    ],
  };
}
