// The engine's settings menu, decoded.
//
// Nothing in this file knows what any particular setting means. The engine
// declares the menu — 119 widgets across three sections, each with a label, a
// CVar, a type and an options struct — and publishes that declaration as JSON;
// this reads it back. A setting added upstream appears in the window without a
// line changing here, and a setting removed upstream disappears, which is the
// whole reason for going the long way round instead of hand-writing a form.
//
// See SpaghettiKart:src/port/ui/SpaghettiPadMenuBridge.cpp for the publishing
// side and, more importantly, for the threading rules. The short version: every
// bridge call below is safe from the main actor. Reads copy the last snapshot
// the engine published rather than waiting for a fresh one, and writes are
// queued for the engine's next frame rather than applied here. So a toggle does
// not change its own value — it asks, and the next poll shows the answer.

import Foundation
import OSLog
import SwiftUI
// For UIColor, which is what a SwiftUI Color has to be resolved through to get
// components out of it.
import UIKit

private let log = Logger(subsystem: "com.subtlepath.spaghettipad", category: "settings")

// MARK: - What the engine publishes

/// One widget, exactly as declared upstream.
struct MenuWidget: Decodable, Identifiable, Hashable {
    let id: Int
    let type: String
    let label: String
    let cvar: String
    let window: String
    let tooltip: String?

    // Present only for the types that have them; a checkbox has no `min`.
    let min: Double?
    let max: Double?
    let step: Double?
    let `default`: Double?
    let format: String?
    let isPercentage: Bool?
    let entries: [Entry]?

    struct Entry: Decodable, Hashable, Identifiable {
        let value: Int
        let label: String
        var id: Int { value }
    }

    /// The tooltip, or nil when upstream left it empty — which many widgets do,
    /// and an empty help string is worse than none.
    var help: String? {
        guard let tooltip, !tooltip.isEmpty else { return nil }
        return tooltip
    }
}

struct MenuPage: Decodable, Identifiable, Hashable {
    let name: String
    let widgets: [MenuWidget]
    var id: String { name }
}

struct MenuSection: Decodable, Identifiable, Hashable {
    let name: String
    let pages: [MenuPage]
    var id: String { name }
}

private struct MenuStructure: Decodable {
    let generation: UInt32
    let sections: [MenuSection]
}

/// Compact triples — `[id, value, flags]` — because this document is rebuilt
/// every frame the window is open and named keys would be most of its bytes.
private struct MenuValues: Decodable {
    let generation: UInt32
    let values: [[Double]]
}

/// What a widget's value and state are right now.
struct MenuValue: Hashable {
    var number: Double = 0
    var isHidden = false
    var isDisabled = false

    var bool: Bool { number != 0 }
    var int: Int { Int(number.rounded()) }
}

// MARK: - Reading the bridge

/// Calls one of the JSON bridge functions, growing the buffer until the whole
/// document fits.
///
/// Both functions follow the snprintf convention — they return the length the
/// document needs and truncate to the capacity given — so a document that grew
/// between the sizing call and the fetch is a short read rather than a smashed
/// buffer. Retried rather than trusted, twice, which is one more time than a
/// menu whose shape changes at most when a search bar appears will ever need.
private func fetchJSON(
    _ call: (UnsafeMutablePointer<CChar>?, Int32) -> Int32
) -> Data? {
    var capacity = Int(call(nil, 0))
    guard capacity > 0 else { return nil }

    for _ in 0..<3 {
        var buffer = [CChar](repeating: 0, count: capacity + 1)
        let needed = Int(buffer.withUnsafeMutableBufferPointer {
            call($0.baseAddress, Int32($0.count))
        })
        guard needed > 0 else { return nil }
        if needed <= capacity {
            return String(cString: buffer).data(using: .utf8)
        }
        capacity = needed
    }
    log.error("menu document kept growing under us; giving up on this poll")
    return nil
}

// MARK: - The model

@MainActor
@Observable
final class SettingsModel {
    private(set) var sections: [MenuSection] = []
    private(set) var values: [Int: MenuValue] = [:]
    private(set) var isReady = false

    /// What the user typed into the search field. Filtering happens here rather
    /// than in the engine's own search widget, which is an ImGui text filter and
    /// has nothing to say to a SwiftUI window.
    var searchText = ""

    private var generation: UInt32 = .max
    private var pollTask: Task<Void, Never>?

    /// Roughly fifteen times a second. Fast enough that a slider dragged with
    /// one hand and a value read with the other agree, slow enough that the
    /// engine's own frame is not spent encoding JSON for a window nobody is
    /// looking at. The engine skips the work entirely when polling is off.
    private static let pollInterval = Duration.milliseconds(66)

    func start() {
        guard pollTask == nil else { return }
        SpaghettiPad_MenuSetPolling(1)
        log.info("settings window opened; the engine is publishing snapshots")

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.poll()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        SpaghettiPad_MenuSetPolling(0)
        log.info("settings window closed; snapshots stopped")
    }

    private func poll() {
        let published = SpaghettiPad_MenuGeneration()
        if published != generation, let data = fetchJSON(SpaghettiPad_MenuStructureJSON) {
            do {
                let structure = try JSONDecoder().decode(MenuStructure.self, from: data)
                sections = structure.sections
                generation = structure.generation
                log.info("""
                    menu structure generation \(structure.generation, privacy: .public): \
                    \(structure.sections.count, privacy: .public) sections, \
                    \(structure.sections.reduce(0) { $0 + $1.pages.count }, privacy: .public) pages, \
                    \(structure.sections.reduce(0) { $0 + $1.pages.reduce(0) { $0 + $1.widgets.count } }, privacy: .public) widgets
                    """)
            } catch {
                log.error("could not decode the menu structure: \(error.localizedDescription, privacy: .public)")
            }
        }

        guard let data = fetchJSON(SpaghettiPad_MenuValuesJSON) else { return }
        do {
            let decoded = try JSONDecoder().decode(MenuValues.self, from: data)
            var next: [Int: MenuValue] = [:]
            next.reserveCapacity(decoded.values.count)
            for triple in decoded.values where triple.count == 3 {
                let flags = UInt32(max(0, triple[2]))
                next[Int(triple[0])] = MenuValue(
                    number: triple[1],
                    isHidden: flags & 1 != 0,
                    isDisabled: flags & 2 != 0
                )
            }
            values = next
            isReady = !sections.isEmpty
        } catch {
            log.error("could not decode the menu values: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Reading

    func value(_ widget: MenuWidget) -> MenuValue {
        values[widget.id] ?? MenuValue()
    }

    /// Widgets worth drawing on a page: upstream hides some of them depending on
    /// other settings, and the separators and labels that were arranging an
    /// ImGui column are not arranging anything here.
    func visibleWidgets(on page: MenuPage) -> [MenuWidget] {
        page.widgets.filter { widget in
            if value(widget).isHidden { return false }
            if widget.type == "search" { return false }
            if widget.type == "custom" { return false }
            return true
        }
    }

    /// Every widget matching the search field, with the page it came from, so a
    /// result can say where it lives.
    func searchResults() -> [(section: String, page: String, widget: MenuWidget)] {
        let needle = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }

        var results: [(section: String, page: String, widget: MenuWidget)] = []
        for section in sections {
            for page in section.pages {
                for widget in visibleWidgets(on: page) {
                    let haystack = "\(widget.label) \(widget.tooltip ?? "") \(widget.cvar)".lowercased()
                    if haystack.contains(needle) {
                        results.append((section.name, page.name, widget))
                    }
                }
            }
        }
        return results
    }

    // MARK: Writing

    // None of these change `values`. The engine owns that, and writing it here
    // would make a control that snaps back look like a control that worked.
    // The next poll is 66 ms away and carries the truth.

    func setBool(_ widget: MenuWidget, _ newValue: Bool) {
        SpaghettiPad_MenuSetInt(Int32(widget.id), newValue ? 1 : 0)
    }

    func setInt(_ widget: MenuWidget, _ newValue: Int) {
        SpaghettiPad_MenuSetInt(Int32(widget.id), Int32(newValue))
    }

    func setDouble(_ widget: MenuWidget, _ newValue: Double) {
        SpaghettiPad_MenuSetFloat(Int32(widget.id), Float(newValue))
    }

    func setColor(_ widget: MenuWidget, _ newValue: Color) {
        SpaghettiPad_MenuSetColor(Int32(widget.id), newValue.packed(hasAlpha: widget.type == "color32"))
    }

    func activate(_ widget: MenuWidget) {
        SpaghettiPad_MenuActivate(Int32(widget.id))
    }
}

// MARK: - Colour packing

extension Color {
    /// RGBA8 or RGB8 in a word, matching what the bridge unpacks on the other
    /// side. Resolved against no particular environment because these are game
    /// colours — a HUD tint, a kart's paint — and not interface colours that
    /// should follow the wearer's appearance.
    func packed(hasAlpha: Bool) -> UInt32 {
        let resolved = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func byte(_ component: CGFloat) -> UInt32 {
            UInt32((component.clamped() * 255).rounded())
        }

        if hasAlpha {
            return byte(red) << 24 | byte(green) << 16 | byte(blue) << 8 | byte(alpha)
        }
        return byte(red) << 16 | byte(green) << 8 | byte(blue)
    }

    /// The inverse, for showing what the engine currently holds.
    static func unpacked(_ value: UInt32, hasAlpha: Bool) -> Color {
        func component(_ shift: UInt32) -> Double {
            Double((value >> shift) & 0xFF) / 255.0
        }
        if hasAlpha {
            return Color(
                .sRGB,
                red: component(24), green: component(16), blue: component(8),
                opacity: component(0)
            )
        }
        return Color(.sRGB, red: component(16), green: component(8), blue: component(0), opacity: 1)
    }
}

private extension CGFloat {
    func clamped() -> CGFloat { Swift.min(Swift.max(self, 0), 1) }
}
