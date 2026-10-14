import SwiftUI
import UIKit

// Colored recipe pages on screen (Joe, October 12): a deep gradient taken
// from the recipe's photo, or one the cook picks, with frosted-glass cards.
// The color math and its contrast guarantees live in RecipePalette.swift and
// are tested on Linux; this file only draws them.

// MARK: - The palette a page is using

private struct RecipePaletteKey: EnvironmentKey {
    static let defaultValue: RecipePalette? = nil
}

extension EnvironmentValues {
    /// Set on a recipe page that is painted with a palette; nil on the
    /// classic cream page and everywhere else in the app.
    var recipePalette: RecipePalette? {
        get { self[RecipePaletteKey.self] }
        set { self[RecipePaletteKey.self] = newValue }
    }
}

// MARK: - Photos and their colors

enum PaletteSampler {
    /// The image drawn into 24×24 sRGB pixels, then clustered. About a
    /// millisecond, once per photo (RecipePhotos caches it).
    static func palette(for image: UIImage) -> RecipePalette? {
        guard let cg = image.cgImage, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let side = 24
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        var pixels: [RGB] = []
        pixels.reserveCapacity(side * side)
        for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i + 3] > 200 {
            pixels.append(RGB(Double(bytes[i]) / 255, Double(bytes[i + 1]) / 255, Double(bytes[i + 2]) / 255))
        }
        return RecipePalette.fromPixels(pixels)
    }
}

/// Recipe photos and their palettes, decoded once. Keyed by file name, which
/// changes whenever a cover is replaced, so nothing here goes stale.
@MainActor
enum RecipePhotos {
    private static var cache: [String: (image: UIImage, palette: RecipePalette?)] = [:]

    static func load(_ recipe: Recipe, from library: RecipeLibrary) -> (image: UIImage, palette: RecipePalette?)? {
        guard let name = recipe.imageFilename else { return nil }
        if let hit = cache[name] { return hit }
        guard let url = library.imageURL(for: recipe), let image = UIImage(contentsOfFile: url.path) else { return nil }
        if cache.count >= 24 { cache.removeAll() }
        let entry = (image: image, palette: PaletteSampler.palette(for: image))
        cache[name] = entry
        return entry
    }

    /// The cook's plate photo, when they took one after cooking.
    static func loadPlate(_ recipe: Recipe, from library: RecipeLibrary) -> UIImage? {
        guard let name = recipe.platePhotoFilename else { return nil }
        if let hit = cache[name] { return hit.image }
        guard let url = library.platePhotoURL(for: recipe), let image = UIImage(contentsOfFile: url.path) else { return nil }
        if cache.count >= 24 { cache.removeAll() }
        cache[name] = (image: image, palette: nil)
        return image
    }

    /// The picture that leads Tonight and Cooking: the plate photo the cook
    /// took, else the cover (Joe, October 14). The page's colors still come
    /// from the cover.
    static func hero(_ recipe: Recipe, from library: RecipeLibrary) -> (image: UIImage, palette: RecipePalette?)? {
        let cover = load(recipe, from: library)
        if let plate = loadPlate(recipe, from: library) { return (image: plate, palette: cover?.palette) }
        return cover
    }

    /// The palette the recipe's page paints with, or nil for classic cream.
    static func palette(for recipe: Recipe, from library: RecipeLibrary) -> RecipePalette? {
        recipe.resolvedPalette(photo: load(recipe, from: library)?.palette)
    }
}

// MARK: - Drawing

extension RecipePalette {
    var swiftUIColors: [Color] { colors.map(\.color) }

    /// Top third stays the first stop, so a hero photo that dissolves into
    /// the page never meets a seam, then the gradient deepens.
    var pageGradient: LinearGradient {
        let c = swiftUIColors
        return LinearGradient(stops: [.init(color: c[0], location: 0), .init(color: c[0], location: 0.32),
                                      .init(color: c[1], location: 0.68), .init(color: c[2], location: 1)],
                              startPoint: .top, endPoint: .bottom)
    }

    /// For swatches and thumbnails.
    var swatchGradient: LinearGradient {
        LinearGradient(colors: swiftUIColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// The page behind a colored recipe: the gradient plus two soft pools of
/// the palette's own colors, which is what makes the cards above it read as
/// frosted glass. Only palette colors are used, and blends of them are never
/// brighter than the brightest stop, so the contrast tests still hold.
struct RecipePageBackground: View {
    let palette: RecipePalette

    var body: some View {
        let c = palette.swiftUIColors
        palette.pageGradient
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Circle().fill(c[1])
                        .frame(width: w * 1.05, height: w * 1.05)
                        .blur(radius: 80)
                        .position(x: w * 0.95, y: h * 0.52)
                    Circle().fill(c[0])
                        .frame(width: w * 0.9, height: w * 0.9)
                        .blur(radius: 90)
                        .position(x: w * 0.05, y: h * 0.86)
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

// MARK: - Covers on Tonight and Cooking (A2-35)

/// A recipe cover as the top of a card: a cropped band that resolves into
/// the card's opaque surface, borrowing the recipe's own color on the way
/// (A2-35: no text over food; the transition, not the page, takes the
/// recipe's wash). Decorative — the card already names the recipe.
struct RecipeCoverBand: View {
    let image: UIImage
    let palette: RecipePalette?
    let height: CGFloat
    var surface: Color = Theme.paper

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(Image(uiImage: image).resizable().scaledToFill())
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(stops: [
                    .init(color: surface.opacity(0), location: 0),
                    .init(color: (palette?.colors[0].color ?? surface).opacity(0.22), location: 0.55),
                    .init(color: surface, location: 1),
                ], startPoint: .top, endPoint: .bottom)
                .frame(height: height * 0.55)
                .allowsHitTesting(false)
            }
            .accessibilityHidden(true)
    }
}

/// A small square crop of the cover, for header rows and the timeline.
struct RecipeCoverThumbnail: View {
    let image: UIImage
    let size: CGFloat

    var body: some View {
        Image(uiImage: image).resizable().scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A card on a recipe page: frosted glass on a colored page (shaded darker
/// on a deep page, lighter on a pale one; solid with Reduce Transparency or
/// Increase Contrast), the classic paper card otherwise.
struct RecipeSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.recipePalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(cornerRadius: CGFloat) { self.cornerRadius = cornerRadius }

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if let palette {
            if reduceTransparency || contrast == .increased || LaunchOptions.solidCards {
                content.background(palette.solidCard.color, in: shape)
            } else {
                content
                    .background {
                        shape.fill(.ultraThinMaterial)
                            .overlay(shape.fill(palette.glassTint.color.opacity(RecipePalette.glassShade)))
                    }
                    .overlay {
                        // The glass edge: a hairline that catches the light at the top.
                        shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.30), .white.opacity(0.06)],
                                                          startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
                            .allowsHitTesting(false)
                    }
            }
        } else {
            content.background(Theme.paper, in: shape)
        }
    }
}

extension View {
    func recipeSurface(cornerRadius: CGFloat = 18) -> some View {
        modifier(RecipeSurface(cornerRadius: cornerRadius))
    }
}

// MARK: - Choosing a page color

/// ••• → Page color. Saves on tap (with the library's rollback), so the page
/// behind the half-height sheet changes as the cook browses.
struct PageStyleSheet: View {
    let recipeID: UUID
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var problem: String?

    init(recipeID: UUID) { self.recipeID = recipeID }

    private struct Option: Identifiable {
        let id: String
        let name: String
        let style: PageStyle
        let palette: RecipePalette?
        var symbol: String? = nil
    }

    private var recipe: Recipe? { library.recipe(id: recipeID) }

    private func options(_ recipe: Recipe) -> [Option] {
        var out: [Option] = []
        if let photo = RecipePhotos.load(recipe, from: library)?.palette {
            out.append(Option(id: "match-photo", name: "Match photo", style: .matchPhoto, palette: photo, symbol: "photo"))
        }
        out += RecipePalette.presets.map { Option(id: $0.id, name: $0.name, style: .preset($0.id), palette: $0.palette) }
        out.append(Option(id: "classic", name: "Classic cream", style: .classic, palette: nil))
        return out
    }

    /// Which option the page is showing now (automatic resolves to one of them).
    private func current(_ recipe: Recipe) -> String {
        let hasPhoto = RecipePhotos.load(recipe, from: library)?.palette != nil
        switch recipe.pageStyle {
        case .none: return hasPhoto ? "match-photo" : "classic"
        case .some(.matchPhoto): return hasPhoto ? "match-photo" : "classic"
        case .some(.classic): return "classic"
        case .some(.preset(let id)): return RecipePalette.preset(id) != nil ? id : (hasPhoto ? "match-photo" : "classic")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let recipe {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(RecipePhotos.load(recipe, from: library) == nil
                             ? "Choose a color for this recipe. Changes save as you select."
                             : "Match the photo, or choose a color. Changes save as you select.")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("page-style-help")
                        if let problem {
                            // Above the grid: the sheet opens at half height.
                            Label(problem, systemImage: "exclamationmark.triangle")
                                .font(.subheadline).foregroundStyle(Theme.warning)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("page-style-error")
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 160 : 96), spacing: 12)], spacing: 14) {
                            let selected = current(recipe)
                            ForEach(options(recipe)) { option in
                                swatch(option, selected: option.id == selected) { choose(option.style, for: recipe) }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .background(Theme.cream)
            .foregroundStyle(Theme.ink)
            .navigationTitle("Page color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("page-style-done")
                }
            }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .tint(Theme.tomato)
    }

    private func swatch(_ option: Option, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                    if let palette = option.palette {
                        shape.fill(palette.swatchGradient)
                    } else {
                        shape.fill(Theme.recipeBackground)
                    }
                    if let symbol = option.symbol {
                        Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(.white)
                    }
                    if selected {
                        let disc: Color = option.palette == nil ? Theme.cream : Color.black.opacity(0.55)
                        let mark: Color = option.palette == nil ? Theme.tomato : Color.white
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(mark, disc)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(6)
                    }
                }
                .frame(height: 72)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.ink : Theme.line, lineWidth: selected ? 2 : 1))
                Text(option.name).font(.footnote.weight(selected ? .semibold : .regular))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("page-style-\(option.id)")
    }

    private func choose(_ style: PageStyle, for recipe: Recipe) {
        var changed = recipe
        changed.pageStyle = style
        guard changed != recipe else { return }
        if library.update(changed) {
            problem = nil
        } else {
            problem = "The page color couldn’t be saved. Your previous color is still selected. Choose another color to try again."
            UIAccessibility.post(notification: .announcement, argument: problem)
        }
    }
}
