import SwiftUI
import Network

struct ProxyEntry: Identifiable, Codable, Equatable {
    var id:     UUID   = UUID()
    var host:   String
    var port:   Int
    var type:   String = "SOCKS5"
    var secret: String = ""
    var pingMs: Int?   = nil
}

final class ProxyStore: ObservableObject {
    @Published var list: [ProxyEntry] = []
    @Published var proxyEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(proxyEnabled, forKey: "vkplus_proxy_enabled")
            applyToSession()
        }
    }
    @Published var activeProxyId: UUID? = nil {
        didSet {
            if let id = activeProxyId {
                UserDefaults.standard.set(id.uuidString, forKey: "vkplus_proxy_active")
            } else {
                UserDefaults.standard.removeObject(forKey: "vkplus_proxy_active")
            }
            applyToSession()
        }
    }
    private let key = "vkplus_proxy_v3"

    init() {
        load()
        proxyEnabled = UserDefaults.standard.bool(forKey: "vkplus_proxy_enabled")
        if let str = UserDefaults.standard.string(forKey: "vkplus_proxy_active"),
           let id = UUID(uuidString: str) {
            activeProxyId = id
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dec = try? JSONDecoder().decode([ProxyEntry].self, from: data)
        else { return }
        list = dec
    }

    func save() {
        guard let data = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func add(_ e: ProxyEntry) { list.append(e); save() }
    func remove(at idx: IndexSet) {
        let removing = idx.map { list[$0].id }
        list.remove(atOffsets: idx)
        if let active = activeProxyId, removing.contains(active) {
            activeProxyId = nil
        }
        save()
    }

    func ping(id: UUID) {
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        let entry = list[i]
        let conn  = NWConnection(
            host: NWEndpoint.Host(entry.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(entry.port)),
            using: .tcp
        )
        let start = Date()

        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                conn.cancel()
                DispatchQueue.main.async {
                    if let idx = self.list.firstIndex(where: { $0.id == id }) {
                        self.list[idx].pingMs = ms; self.save()
                    }
                }
            case .failed:
                conn.cancel()
                DispatchQueue.main.async {
                    if let idx = self.list.firstIndex(where: { $0.id == id }) {
                        self.list[idx].pingMs = -1; self.save()
                    }
                }
            default: break
            }
        }
        conn.start(queue: .global(qos: .utility))

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 4) {
            if conn.state != .cancelled { conn.cancel() }
            DispatchQueue.main.async {
                if let idx = self.list.firstIndex(where: { $0.id == id }),
                   self.list[idx].pingMs == nil {
                    self.list[idx].pingMs = -1; self.save()
                }
            }
        }
    }

    func pingAll() { list.forEach { ping(id: $0.id) } }

    func applyToSession() {
        guard proxyEnabled, let id = activeProxyId,
              let entry = list.first(where: { $0.id == id }) else {
            VKAPIClient.shared.setProxy(nil)
            return
        }
        VKAPIClient.shared.setProxy(entry)
    }
}

private func parseProxy(_ raw: String) -> ProxyEntry? {
    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }

    if let comps = URLComponents(string: s),
       (comps.scheme == "tg"    && comps.host == "proxy") ||
       (comps.scheme == "https" && comps.host == "t.me" && comps.path.hasPrefix("/proxy")) {
        let qi = comps.queryItems ?? []
        func q(_ n: String) -> String? { qi.first(where: { $0.name == n })?.value }
        guard let host = q("server") else { return nil }
        let port   = Int(q("port") ?? "443") ?? 443
        let secret = q("secret") ?? ""
        return ProxyEntry(host: host, port: port, type: "MTProto", secret: secret)
    }

    let parts = s.split(separator: ":", maxSplits: 1).map(String.init)
    if parts.count == 2, let port = Int(parts[1]), port > 0, port < 65536 {
        return ProxyEntry(host: parts[0], port: port)
    }
    return nil
}

struct ProxyView: View {
    @StateObject private var store = ProxyStore()
    @State private var linkInput   = ""
    @State private var parseError  = false

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                if store.list.isEmpty {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.onSurfaceMut)
                        Text("Нет прокси")
                            .foregroundStyle(Color.onSurfaceMut)
                        Text("Вставьте ссылку tg:// или host:port")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.onSurfaceMut.opacity(0.6))
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(store.list) { entry in
                            ProxyRowView(entry: entry, onPing: { store.ping(id: entry.id) }, store: store)
                                .listRowBackground(Color.surface)
                                .listRowSeparatorTint(Color.divider)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                        .onDelete { store.remove(at: $0) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                // Proxy enable toggle + active selector
                if !store.list.isEmpty {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(store.proxyEnabled ? Color.cyberBlue.opacity(0.15) : Color.surfaceVar)
                                    .frame(width: 34, height: 34)
                                Image(systemName: "network")
                                    .font(.system(size: 15))
                                    .foregroundStyle(store.proxyEnabled ? Color.cyberBlue : Color.onSurfaceMut)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Прокси активен")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.onSurface)
                                if store.proxyEnabled, let id = store.activeProxyId,
                                   let e = store.list.first(where: { $0.id == id }) {
                                    Text("\(e.host):\(e.port)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color.cyberBlue)
                                } else {
                                    Text(store.proxyEnabled ? "Выберите прокси" : "Выключен")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.onSurfaceMut)
                                }
                            }
                            Spacer()
                            Toggle("", isOn: $store.proxyEnabled)
                                .labelsHidden()
                                .tint(Color.cyberBlue)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Color.surface)
                    }
                    .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.divider), alignment: .bottom)
                }

                Divider().background(Color.divider)
                HStack(spacing: 10) {
                    TextField("tg://proxy?... или host:port", text: $linkInput)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.surfaceVar)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(parseError ? Color.errorRed : Color.onSurface)
                        .font(.system(size: 13))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: linkInput) { _, _ in parseError = false }

                    Button {
                        if let e = parseProxy(linkInput) { store.add(e); linkInput = "" }
                        else { parseError = true }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(linkInput.isEmpty ? Color.onSurfaceMut : Color.cyberBlue)
                    }
                    .disabled(linkInput.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.surface)
            }
        }
        .navigationTitle("Прокси")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { store.pingAll() } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color.cyberBlue)
                }
            }
        }
    }
}

private struct ProxyRowView: View {
    let entry:  ProxyEntry
    let onPing: () -> Void
    @ObservedObject var store: ProxyStore

    private var dotColor: Color {
        guard let ms = entry.pingMs else { return Color.onSurfaceMut }
        if ms < 0   { return Color.errorRed }
        if ms < 150 { return Color(r: 0x4C, g: 0xAF, b: 0x50) }
        if ms < 400 { return Color(r: 0xFF, g: 0xAB, b: 0x40) }
        return Color.errorRed
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(dotColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.host):\(entry.port)")
                    .foregroundStyle(Color.onSurface)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(entry.type)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.onSurfaceMut)
                    if !entry.secret.isEmpty {
                        Text("• зашифрован")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cyberBlue.opacity(0.7))
                    }
                }
            }
            Spacer()
            if let ms = entry.pingMs {
                Text(ms < 0 ? "—" : "\(ms) ms")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(dotColor)
                    .frame(minWidth: 52, alignment: .trailing)
            }
            // Set as active button
            let isActive = store.activeProxyId == entry.id
            Button {
                store.activeProxyId = entry.id
                if !store.proxyEnabled { store.proxyEnabled = true }
            } label: {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isActive ? Color.cyberBlue : Color.onSurfaceMut.opacity(0.4))
                    .padding(.trailing, 2)
            }
            .buttonStyle(.plain)

            Button(action: onPing) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.cyberBlue)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .background(store.activeProxyId == entry.id && store.proxyEnabled
                    ? Color.cyberBlue.opacity(0.05) : Color.clear)
    }
}
