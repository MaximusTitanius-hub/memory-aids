import SwiftUI
import AppKit

@main
struct MemoryAidsApp: App {
    @StateObject private var store = Store()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Memory Aids") {
            ContentView()
                .environmentObject(store)
                .tint(Theme.brandColor)
                .frame(minWidth: 980, minHeight: 660)
        }
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

enum SidebarItem: Hashable {
    case new, study, set(UUID)
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var selection: SidebarItem? = .new

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().frame(width: 34, height: 34)
                    Text("Memory Aids").font(.rounded(.title3, weight: .heavy))
                }
                .padding(.vertical, 6)
                .selectionDisabled()
                Section {
                    Label("New study set", systemImage: "plus.circle.fill")
                        .tag(SidebarItem.new)
                    HStack {
                        Label("Study (recall)", systemImage: "brain.head.profile")
                        Spacer()
                        if store.totalDue > 0 {
                            Text("\(store.totalDue)")
                                .font(.caption.bold())
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange))
                                .foregroundStyle(.white)
                        }
                    }
                    .tag(SidebarItem.study)
                }
                Section("My study sets") {
                    ForEach(store.sets) { set in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(set.title).font(.rounded(.body, weight: .semibold)).lineLimit(1)
                            Text("\(set.aids.count) aids · \(set.cards.count) cards")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(SidebarItem.set(set.id))
                        .contextMenu {
                            Button("Delete", role: .destructive) { store.delete(set.id) }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            switch selection {
            case .study:
                StudyView(setId: nil)
            case .set(let id):
                if store.binding(for: id) != nil {
                    SetDetailView(setId: id)
                } else {
                    NewSetView { selection = .set($0) }
                }
            default:
                NewSetView { selection = .set($0) }
            }
        }
    }
}
