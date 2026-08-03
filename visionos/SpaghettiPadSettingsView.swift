// The settings menu as a native window.
//
// One view per widget type, driven entirely by what SettingsModel decoded. There
// is deliberately no switch on a *setting* anywhere in this file — only on a
// widget's kind — because the moment this file knows that "gSettings.Menu.Scale"
// is a slider from 1 to 2, it has become a second copy of the menu that upstream
// can silently break.
//
// The ImGui menu is still there and still works; this does not replace it so
// much as stand in front of it. The Developer pages open ImGui windows, which is
// what those widgets have always done, and the resolution editor draws its own
// ImGui and is skipped here rather than half-rendered.

import OSLog
import SwiftUI

private let log = Logger(subsystem: "com.subtlepath.spaghettipad", category: "settings")

// MARK: - Formatting

extension MenuWidget {
    /// The label without the printf specifier upstream embedded in it.
    ///
    /// ImGui draws a slider's value inside its label, so upstream writes them as
    /// "Menu Scale: %.0fx" and lets the widget substitute. A native slider shows
    /// its value in its own trailing text, so the specifier is stripped and the
    /// separator it was hanging off goes with it — leaving "Menu Scale".
    var displayLabel: String {
        guard let percent = label.lastIndex(of: "%") else { return label }
        let head = label[label.startIndex..<percent]
        return head
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":-–"))
            .trimmingCharacters(in: .whitespaces)
    }

    /// A value rendered the way upstream asked for it, honouring both the
    /// widget's format string and its percentage flag.
    func formatted(_ value: Double) -> String {
        let shown = (isPercentage ?? false) ? value * 100 : value
        let specifier = format ?? (isFloatSlider ? "%.2f" : "%d")

        // String(format:) is a varargs C call and takes the type the specifier
        // names, not the type Swift happens to be holding. Getting this wrong
        // does not warn; it prints garbage.
        if specifier.contains("d") || specifier.contains("i") {
            return String(format: specifier, Int32(shown.rounded()))
        }
        return String(format: specifier, shown)
    }

    var isFloatSlider: Bool { type == "sliderFloat" }
    var isIntSlider: Bool { type == "sliderInt" }

    /// A slider needs somewhere to go. Upstream's defaults are sane, but a
    /// widget declared with min == max would divide by zero inside SwiftUI.
    var range: ClosedRange<Double> {
        let low = min ?? 0
        let high = max ?? 1
        return high > low ? low...high : low...(low + 1)
    }
}

// MARK: - One widget

private struct WidgetRow: View {
    let widget: MenuWidget
    @Environment(SettingsModel.self) private var model

    var body: some View {
        let state = model.value(widget)

        VStack(alignment: .leading, spacing: 4) {
            control(state)
            if let help = widget.help {
                Text(help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .disabled(state.isDisabled)
    }

    @ViewBuilder
    private func control(_ state: MenuValue) -> some View {
        switch widget.type {
        case "checkbox":
            Toggle(widget.displayLabel, isOn: Binding(
                get: { state.bool },
                set: { model.setBool(widget, $0) }
            ))

        case "windowButton":
            // Reflects whether the ImGui window is open, because that is what
            // pressing it changes. A toggle says so; a button would not.
            Toggle(widget.displayLabel, isOn: Binding(
                get: { state.bool },
                set: { _ in model.activate(widget) }
            ))

        case "combobox", "audioBackend", "videoBackend":
            Picker(widget.displayLabel, selection: Binding(
                get: { state.int },
                set: { model.setInt(widget, $0) }
            )) {
                ForEach(widget.entries ?? []) { entry in
                    Text(entry.label).tag(entry.value)
                }
            }

        case "sliderFloat", "sliderInt":
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(widget.displayLabel)
                    Spacer(minLength: 12)
                    Text(widget.formatted(state.number))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                slider(state)
            }

        case "button":
            Button(widget.displayLabel) { model.activate(widget) }

        case "color24", "color32":
            ColorPicker(
                widget.displayLabel,
                selection: Binding(
                    get: {
                        Color.unpacked(UInt32(Swift.max(0, state.number)), hasAlpha: widget.type == "color32")
                    },
                    set: { model.setColor(widget, $0) }
                ),
                supportsOpacity: widget.type == "color32"
            )

        case "separator":
            Divider()

        case "separatorText":
            Text(widget.displayLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

        case "text":
            Text(widget.displayLabel)
                .fixedSize(horizontal: false, vertical: true)

        default:
            // A type this build does not draw. Named rather than dropped: a
            // silent omission is how a settings window quietly loses a feature
            // upstream added.
            LabeledContent(widget.displayLabel) {
                Text(widget.type).foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func slider(_ state: MenuValue) -> some View {
        let binding = Binding(
            get: { state.number },
            set: { newValue in
                if widget.isIntSlider {
                    model.setInt(widget, Int(newValue.rounded()))
                } else {
                    model.setDouble(widget, newValue)
                }
            }
        )

        if let step = widget.step, step > 0 {
            Slider(value: binding, in: widget.range, step: step)
        } else {
            Slider(value: binding, in: widget.range)
        }
    }
}

// MARK: - A page

private struct PageView: View {
    let section: String
    let page: MenuPage
    @Environment(SettingsModel.self) private var model

    var body: some View {
        let widgets = model.visibleWidgets(on: page)

        Form {
            if widgets.isEmpty {
                ContentUnavailableView(
                    "Nothing here",
                    systemImage: "slider.horizontal.3",
                    description: Text("Every setting on this page is hidden by another setting.")
                )
            } else {
                Section {
                    ForEach(widgets) { widget in
                        WidgetRow(widget: widget)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(page.name)
    }
}

// MARK: - Search

private struct SearchResultsView: View {
    @Environment(SettingsModel.self) private var model

    var body: some View {
        let results = model.searchResults()

        Form {
            if results.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
            } else {
                ForEach(results, id: \.widget.id) { result in
                    Section {
                        WidgetRow(widget: result.widget)
                    } header: {
                        Text("\(result.section) › \(result.page)")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Search")
    }
}

// MARK: - The window

struct SettingsWindow: View {
    @State private var model = SettingsModel()
    @State private var selection: PageSelection?

    /// A page, named by where it lives. The pages are not uniquely named —
    /// "General" appears under all three sections — so a selection has to carry
    /// both halves or the sidebar jumps.
    struct PageSelection: Hashable {
        let section: String
        let page: String
    }

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(selection: $selection) {
                ForEach(model.sections) { section in
                    Section(section.name) {
                        ForEach(section.pages) { page in
                            NavigationLink(
                                value: PageSelection(section: section.name, page: page.name)
                            ) {
                                Label(page.name, systemImage: icon(for: page.name))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .searchable(text: $model.searchText, prompt: "Search settings")
        } detail: {
            if !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                SearchResultsView()
            } else if let selection, let page = page(for: selection) {
                PageView(section: selection.section, page: page)
            } else if model.isReady {
                ContentUnavailableView(
                    "Settings",
                    systemImage: "gearshape",
                    description: Text("Pick a page on the left.")
                )
            } else {
                // The engine publishes its first snapshot on its next frame, so
                // this is what the window looks like for one frame — and what it
                // keeps looking like if the engine never started, which is worth
                // being able to tell apart from an empty menu.
                ProgressView("Waiting for the game")
                    .progressViewStyle(.circular)
            }
        }
        .environment(model)
        .onAppear {
            model.start()
            // Only now does the engine stand its ImGui menu down. Saying it here
            // rather than when the window was asked for is the whole failsafe:
            // if this window never appears, ImGui keeps drawing and settings
            // stay reachable.
            SpaghettiPad_MenuNativeWindowPresent(1)
        }
        .onDisappear {
            SpaghettiPad_MenuNativeWindowPresent(0)
            model.stop()
            // The wearer may have closed this with the window's own close
            // button, which the engine knows nothing about — and it goes on
            // blocking game input for as long as it believes the menu is up.
            // Harmless when the engine is the one that closed us.
            SpaghettiPad_MenuRequestVisible(0)
        }
    }

    private func page(for selection: PageSelection) -> MenuPage? {
        model.sections
            .first { $0.name == selection.section }?
            .pages.first { $0.name == selection.page }
    }

    /// Cosmetic, and matched by name because the engine has no concept of an
    /// icon. An unrecognised page gets a neutral one rather than nothing, so the
    /// sidebar stays aligned when upstream adds a page.
    private func icon(for page: String) -> String {
        switch page {
        case "General": return "gearshape"
        case "Audio": return "speaker.wave.2"
        case "Graphics": return "sparkles"
        case "Controls": return "gamecontroller"
        case "Cheats": return "wand.and.stars"
        case "Rulesets": return "list.bullet.rectangle"
        case "Gfx Debugger": return "ladybug"
        case "Stats": return "chart.bar"
        case "Console": return "terminal"
        case "Scene Visibility": return "eye"
        default: return "square.grid.2x2"
        }
    }
}
