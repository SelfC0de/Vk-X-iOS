import SwiftUI

struct RegDateResult {
    let name: String
    let avatarUrl: String?
    let regDate: String
    let elapsed: String
    let isVerified: Bool
    let profileUrl: String
}

struct RegDateCheckerView: View {
    @State private var inputId   = ""
    @State private var isLoading = false
    @State private var result: RegDateResult? = nil
    @State private var errorMsg: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            inputRow
            if let err = errorMsg {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange).font(.system(size: 13))
                    Text(err).font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
            }
            if let r = result {
                Divider().background(Color.divider)
                resultCard(r)
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(Color.onSurfaceMut).font(.system(size: 14))
                TextField("ID или ссылка (id1, vk.com/durov)", text: $inputId)
                    .foregroundStyle(Color.onSurface).font(.system(size: 14))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .onSubmit { Task { await fetch() } }
                if !inputId.isEmpty {
                    Button { inputId = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.onSurfaceMut).font(.system(size: 13))
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color(red: 0.07, green: 0.08, blue: 0.13))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.divider, lineWidth: 0.8))

            Button { Task { await fetch() } } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Text("Получить").font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(inputId.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.cyberBlue.opacity(0.4) : Color.cyberBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(inputId.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func resultCard(_ r: RegDateResult) -> some View {
        HStack(spacing: 14) {
            Group {
                if let us = r.avatarUrl, let url = URL(string: us) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                    placeholder: { Color.surfaceVar }
                } else {
                    ZStack { Color.surfaceVar; Image(systemName: "person.fill").foregroundStyle(Color.onSurfaceMut) }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text(r.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.onSurface).lineLimit(1)
                    if r.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.11, green: 0.63, blue: 0.95))
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "calendar").font(.system(size: 11)).foregroundStyle(Color.cyberBlue)
                    Text(r.regDate).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.cyberBlue)
                }
                if !r.elapsed.isEmpty {
                    Text(r.elapsed).font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                }
            }

            Spacer()

            Button {
                UIPasteboard.general.string = r.profileUrl
                ToastManager.shared.show("Ссылка скопирована", icon: "link", style: .success)
            } label: {
                Image(systemName: "link").font(.system(size: 14)).foregroundStyle(Color.onSurfaceMut)
                    .frame(width: 32, height: 32).background(Color.surfaceVar)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - Fetch
    private func fetch() async {
        let raw = inputId.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        let id = extractId(raw)
        isLoading = true; errorMsg = nil; result = nil

        if let r = await fetchSmmE(id: id) { result = r; isLoading = false; return }
        if let r = await fetchRegVk(id: id) { result = r; isLoading = false; return }

        errorMsg = "Не удалось получить данные. Проверьте ID."
        isLoading = false
    }

    private func extractId(_ raw: String) -> String {
        var s = raw
        for p in ["https://vk.com/", "https://vk.ru/", "http://vk.com/", "vk.com/", "vk.ru/"] {
            if s.hasPrefix(p) { s = String(s.dropFirst(p.count)) }
        }
        return s.isEmpty ? raw : s
    }

    // MARK: - smm-e.ru
    private func fetchSmmE(id: String) async -> RegDateResult? {
        guard let url = URL(string: "https://smm-e.ru/services/vk/users/registration/") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        req.setValue("https://smm-e.ru/services/vk/users/registration/", forHTTPHeaderField: "Referer")
        req.timeoutInterval = 10
        req.httpBody = "vk_users_registration-get-url=https%3A%2F%2Fvk.ru%2F\(id)".data(using: .utf8)
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) else { return nil }

        // Date: <span class="fw-600 text-se">23 сентября 2006</span>
        guard let dr = html.range(of: #"<span class="fw-600 text-se">([^<]+)</span>"#,
                                   options: .regularExpression) else { return nil }
        let regDate = String(html[dr])
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard !regDate.isEmpty else { return nil }

        // Elapsed
        var elapsed = ""
        if let er = html.range(of: #"Прошло:[^<\n]+"#, options: .regularExpression) {
            elapsed = String(html[er])
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .trimmingCharacters(in: .whitespaces)
        }

        // Avatar
        var avatarUrl: String? = nil
        if let ir = html.range(of: #"src="(https://sun[^"]+)""#, options: .regularExpression) {
            avatarUrl = String(html[ir])
                .replacingOccurrences(of: "src=\"", with: "")
                .replacingOccurrences(of: "\"", with: "")
        }

        // Extract name from HTML — smm-e.ru shows it in various places
        var smmName = "id\(id)"
        // Try <title>Дата регистрации — Имя Фамилия</title>
        if let tr = html.range(of: #"<title>[^<]+"#, options: .regularExpression) {
            let t = String(html[tr])
                .replacingOccurrences(of: "<title>", with: "")
                .replacingOccurrences(of: "Дата регистрации ВК — ", with: "")
                .replacingOccurrences(of: "Дата регистрации — ", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !t.isEmpty && !t.lowercased().contains("smm") && t.count > 1 { smmName = t }
        }
        // Try <h1> or <h2> with name
        if smmName == "id\(id)" {
            for tag in ["h1", "h2", "h3"] {
                if let nr = html.range(of: "<\(tag)>([^<]+)</\(tag)>", options: .regularExpression) {
                    let nm = String(html[nr])
                        .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    if nm.count > 2 && !nm.lowercased().contains("smm") && !nm.lowercased().contains("регистрац") {
                        smmName = nm; break
                    }
                }
            }
        }
        // Fallback: fetch name from VK API
        if smmName == "id\(id)", let numId = Int(id) {
            if let user = try? await VKAPIClient.shared.getUserById("\(numId)") {
                smmName = "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespaces)
            }
        }
        return RegDateResult(name: smmName, avatarUrl: avatarUrl,
                             regDate: regDate, elapsed: elapsed,
                             isVerified: false, profileUrl: "https://vk.com/\(id)")
    }

    // MARK: - regvk.com
    private func fetchRegVk(id: String) async -> RegDateResult? {
        guard let url = URL(string: "https://regvk.com/") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        req.setValue("https://regvk.com/", forHTTPHeaderField: "Referer")
        req.timeoutInterval = 8
        let enc = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        req.httpBody = "link=\(enc)&button=Определить+дату+регистрации".data(using: .utf8)
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) else { return nil }

        // Name + verified flag
        var name = "id\(id)"; var isVerified = false
        // Try multiple patterns for name extraction
        let namePatterns = [
            #"<h[123][^>]*>([^<]+(?:<[^/][^>]*>[^<]*</[^>]+>)?[^<]*)</h[123]>"#,
            #"<h[123]>([^<]+)</h[123]>"#,
            #"class="name[^"]*">([^<]+)<"#,
            #"<strong>([^<]+)</strong>"#,
        ]
        for pattern in namePatterns {
            if let nr = html.range(of: pattern, options: .regularExpression) {
                let block = String(html[nr])
                isVerified = block.contains("verified") || block.contains("✓")
                let extracted = block
                    .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                if extracted.count > 2 && !extracted.lowercased().contains("regvk")
                    && !extracted.lowercased().contains("дата") && !extracted.lowercased().contains("регистрац") {
                    name = extracted; break
                }
            }
        }
        // Fallback: VK API
        if name == "id\(id)" {
            let numericId = id.trimmingCharacters(in: .letters) // handle "id12345" → "12345"
            let lookupId = id.hasPrefix("id") ? String(id.dropFirst(2)) : id
            if let user = try? await VKAPIClient.shared.getUserById(lookupId) {
                name = "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespaces)
                isVerified = user.isVerified
            }
        }

        // Date
        var regDate = ""
        if let dr = html.range(of: #"Дата регистрации: ([^<\n<br>]+)"#, options: .regularExpression) {
            regDate = String(html[dr])
                .replacingOccurrences(of: "Дата регистрации: ", with: "")
                .replacingOccurrences(of: "<br>", with: "")
                .replacingOccurrences(of: " года", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        guard !regDate.isEmpty else { return nil }

        // Elapsed
        var elapsed = ""
        if let er = html.range(of: #"Прошло времени: ([^<\n]+)"#, options: .regularExpression) {
            elapsed = String(html[er])
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .trimmingCharacters(in: .whitespaces)
        }

        // Avatar — photo200 src
        var avatarUrl: String? = nil
        if let ir = html.range(of: #"class="photo200" src="([^"]+)""#, options: .regularExpression) {
            avatarUrl = String(html[ir])
                .replacingOccurrences(of: #"class="photo200" src=""#, with: "")
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "&amp;", with: "&")
        }

        return RegDateResult(name: name, avatarUrl: avatarUrl,
                             regDate: regDate, elapsed: elapsed,
                             isVerified: isVerified, profileUrl: "https://vk.com/\(id)")
    }
}
