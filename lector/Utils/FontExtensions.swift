import SwiftUI

extension Font {
  /// Returns Parkinsans font with the specified size and weight.
  /// Falls back to system font if Parkinsans is not available.
  static func parkinsans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    // Parkinsans-Regular is the only variant available
    // We'll use the regular variant and let SwiftUI handle the weight rendering
    if let font = UIFont(name: "Parkinsans-Regular", size: size) {
      return Font(font)
    }
    // Fallback to system font if Parkinsans is not registered
    return .system(size: size, weight: weight)
  }
  
  /// Convenience method for Parkinsans with semibold weight
  static func parkinsansSemibold(size: CGFloat) -> Font {
    return .parkinsans(size: size, weight: .semibold)
  }
  
  /// Convenience method for Parkinsans with bold weight
  static func parkinsansBold(size: CGFloat) -> Font {
    return .parkinsans(size: size, weight: .bold)
  }
  
  /// Convenience method for Parkinsans with medium weight
  static func parkinsansMedium(size: CGFloat) -> Font {
    return .parkinsans(size: size, weight: .medium)
  }
}
