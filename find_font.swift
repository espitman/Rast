import Cocoa

let families = NSFontManager.shared.availableFontFamilies
for family in families {
    if family.contains("Vazir") {
        print("Family: \(family)")
        if let members = NSFontManager.shared.availableMembers(ofFontFamily: family) {
            for member in members {
                print("  - \(member[0])")
            }
        }
    }
}
