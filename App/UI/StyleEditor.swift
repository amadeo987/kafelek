import SwiftUI

func hexBinding(_ b: Binding<String>) -> Binding<Color> {
    Binding(get: { Color(hex: b.wrappedValue) }, set: { b.wrappedValue = $0.hexString })
}

struct StyleEditor: View {
    @Binding var style: Style

    var body: some View {
        Section("Motyw") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ThemePreset.all) { t in
                        Button {
                            t.apply(to: &style)
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(LinearGradient(colors: [Color(hex: t.color1), Color(hex: t.background == .gradient ? t.color2 : t.color1)],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                    Text("Aa")
                                        .font((t.font ?? .system).font(size: 14, weight: .bold))
                                        .foregroundStyle(Color(hex: t.text))
                                    Circle().fill(Color(hex: t.accent)).frame(width: 7, height: 7)
                                        .offset(x: 14, y: -14)
                                }
                                .frame(width: 46, height: 46)
                                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.secondary.opacity(0.3)))
                                Text(t.name).font(.caption2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }

        Section("Tło") {
            Picker("Rodzaj tła", selection: $style.background) {
                ForEach(BackgroundKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            switch style.background {
            case .solid:
                ColorPicker("Kolor tła", selection: hexBinding($style.color1), supportsOpacity: true)
            case .gradient:
                ColorPicker("Kolor 1", selection: hexBinding($style.color1), supportsOpacity: true)
                ColorPicker("Kolor 2", selection: hexBinding($style.color2), supportsOpacity: true)
                LabeledContent("Kąt \(Int(style.gradientAngle))°") {
                    Slider(value: $style.gradientAngle, in: 0...360, step: 15)
                }
            case .photo:
                HStack {
                    if let id = style.photoID, let img = PhotoStore.image(id) {
                        Image(nsImage: img).resizable().scaledToFill().frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button(style.photoID == nil ? "Wybierz zdjęcie…" : "Zmień zdjęcie…") {
                        if let id = pickPhoto() { style.photoID = id }
                    }
                }
                LabeledContent("Przyciemnienie") {
                    Slider(value: $style.photoDim, in: 0...0.8)
                }
            }
        }

        Section("Tekst") {
            ColorPicker("Kolor tekstu", selection: hexBinding($style.textColor), supportsOpacity: false)
            ColorPicker("Kolor akcentu", selection: hexBinding($style.accentColor), supportsOpacity: false)
            Picker("Czcionka", selection: $style.font) {
                ForEach(FontChoice.allCases) { f in
                    Text(f.title).font(f.font(size: 13, weight: .regular)).tag(f)
                }
            }
            Picker("Grubość", selection: $style.weight) {
                ForEach(WeightChoice.allCases) { Text($0.title).tag($0) }
            }
            Picker("Wyrównanie", selection: $style.align) {
                ForEach(TextAlign.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            LabeledContent("Wielkość tekstu \(Int(style.textScale * 100))%") {
                Slider(value: $style.textScale, in: 0.6...1.6, step: 0.05)
            }
            LabeledContent("Margines \(Int(style.padding))") {
                Slider(value: $style.padding, in: 4...28, step: 1)
            }
        }

        Section("Ramka") {
            LabeledContent("Grubość \(String(format: "%.1f", style.borderWidth))") {
                Slider(value: $style.borderWidth, in: 0...6, step: 0.5)
            }
            if style.borderWidth > 0 {
                ColorPicker("Kolor ramki", selection: hexBinding($style.borderColor), supportsOpacity: true)
            }
        }
    }
}
