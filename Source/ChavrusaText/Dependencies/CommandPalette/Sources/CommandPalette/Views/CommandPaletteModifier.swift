import SwiftUI

extension View {
    /// Shows a command palette over this view while `isPresented` is `true`, and toggles it with ⌘K.
    ///
    /// ```swift
    /// @State private var showsPalette = false
    ///
    /// NotesView()
    ///     .commandPalette(isPresented: $showsPalette, commands: model.commands)
    /// ```
    ///
    /// The palette floats near the top over a dimmed backdrop; a click or tap on the backdrop, ⎋, or
    /// running a command closes it.
    ///
    /// - Parameters:
    ///   - isPresented: Whether the palette is shown.
    ///   - commands: All commands, in the order they are listed when the search field is empty.
    ///   - recents: Where recently run commands are remembered; ``RecentCommandsStore/shared`` when `nil`.
    ///   - shortcut: The keyboard shortcut that opens and closes the palette, ⌘K by default; `nil`
    ///     for none, for example when a menu item already has it.
    ///   - placeholder: The search field's placeholder.
    @MainActor
    public func commandPalette(
        isPresented: Binding<Bool>,
        commands: [Command],
        recents: RecentCommandsStore? = nil,
        shortcut: CommandShortcut? = .commandK,
        placeholder: String = "Search for a command…"
    ) -> some View {
        commandPalette(isPresented: isPresented, shortcut: shortcut) {
            CommandPaletteView(commands: commands, recents: recents, placeholder: placeholder, onDismiss: {
                isPresented.wrappedValue = false
            })
        }
    }

    /// Shows your own palette view, usually a configured ``CommandPaletteView``, in the same floating
    /// presentation, and toggles it with `shortcut`.
    ///
    /// ```swift
    /// .commandPalette(isPresented: $showsPalette) {
    ///     CommandPaletteView(commands: commands, recents: recents, placeholder: "Go to…") {
    ///         showsPalette = false
    ///     }
    /// }
    /// ```
    @MainActor
    public func commandPalette<Palette: View>(
        isPresented: Binding<Bool>,
        shortcut: CommandShortcut? = .commandK,
        @ViewBuilder palette: () -> Palette
    ) -> some View {
        modifier(CommandPalettePresentation(isPresented: isPresented, shortcut: shortcut, palette: palette()))
    }

    /// Toggles `isPresented` with a keyboard shortcut, ⌘K by default, while this view is on screen.
    ///
    /// Works on the Mac and on iPad with a hardware keyboard. ``commandPalette(isPresented:commands:recents:shortcut:placeholder:)``
    /// already does this; use it on its own when you present the palette yourself.
    @MainActor
    public func commandPaletteShortcut(_ shortcut: CommandShortcut = .commandK, isPresented: Binding<Bool>) -> some View {
        commandPaletteShortcut(shortcut) {
            isPresented.wrappedValue.toggle()
        }
    }

    /// Runs `action` for a keyboard shortcut, ⌘K by default, while this view is on screen.
    @MainActor
    public func commandPaletteShortcut(
        _ shortcut: CommandShortcut = .commandK,
        title: String = "Command Palette",
        action: @escaping () -> Void
    ) -> some View {
        background {
            ShortcutButton(shortcut: shortcut, title: title, action: action)
        }
    }
}

/// The floating presentation: a dimmed backdrop and the palette near the top.
struct CommandPalettePresentation<Palette: View>: ViewModifier {
    @Binding var isPresented: Bool
    let shortcut: CommandShortcut?
    let palette: Palette

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack(alignment: .top) {
                    if isPresented {
                        Color.black.opacity(0.22)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture { isPresented = false }
                            .accessibilityLabel(Text("Close command palette"))
                            .accessibilityAddTraits(.isButton)
                            .transition(.opacity)

                        palette
                            .padding(.horizontal, 20)
                            .padding(.top, 64)
                            .padding(.bottom, 20)
                            .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .animation(.snappy(duration: 0.18), value: isPresented)
            }
            .background {
                if let shortcut {
                    ShortcutButton(shortcut: shortcut, title: "Command Palette") {
                        isPresented.toggle()
                    }
                }
            }
    }
}

/// An invisible button that only exists for its keyboard shortcut.
private struct ShortcutButton: View {
    let shortcut: CommandShortcut
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .keyboardShortcut(shortcut.keyboardShortcut)
            .buttonStyle(.plain)
            .frame(width: 0, height: 0)
            .clipped()
            .opacity(0)
            .accessibilityHidden(true)
    }
}
