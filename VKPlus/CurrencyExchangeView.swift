import SwiftUI

struct CurrencyExchangeView: View {
    @State private var state = CurrencyState()
    @State private var baseExpanded   = false
    @State private var targetExpanded = false

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: "dollarsign.arrow.circlepath")
                            .font(.system(size: 36)).foregroundStyle(Color(r:0xFF,g:0xD7,b:0x00))
                        Text("Currency Exchange").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.onSurface)
                        Text("Актуальный курс через FreeCurrencyAPI")
                            .font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                    }
                    .padding(20).cyberCard()

                    // Pickers row
                    HStack(spacing: 10) {
                        currencyPicker(title: "Base", selected: $state.base, expanded: $baseExpanded)
                        swapButton
                        currencyPicker(title: "To", selected: $state.target, expanded: $targetExpanded)
                    }

                    // Result
                    if state.isLoading {
                        HStack(spacing: 10) {
                            ProgressView().tint(.cyberBlue)
                            Text("Получаем курс...").foregroundStyle(Color.onSurfaceMut)
                        }
                        .padding(16).cyberCard()
                    } else if let rate = state.result {
                        VStack(spacing: 8) {
                            Text("1 \(state.base) =").font(.system(size: 14)).foregroundStyle(Color.onSurfaceMut)
                            HStack(alignment: .bottom, spacing: 6) {
                                Text(String(format: "%.4f", rate))
                                    .font(.system(size: 36, weight: .black)).foregroundStyle(Color.cyberBlue)
                                Text(state.target).font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color.onSurfaceMut).padding(.bottom, 4)
                            }
                            Text("100 \(state.base) = \(String(format: "%.2f", rate * 100)) \(state.target)")
                                .font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color.cyberBlue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyberBlue.opacity(0.3), lineWidth: 1))
                    } else if let err = state.error {
                        Text("⚠ \(err)").font(.system(size: 13)).foregroundStyle(Color.errorRed)
                            .padding(16).cyberCard()
                    }

                    Button { Task { await fetch() } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Получить курс").font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color.background)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(state.isLoading ? Color.cyberBlue.opacity(0.5) : Color.cyberBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(state.isLoading)
                }
                .padding(16)
            }
        }
        .navigationTitle("Currency Exchange").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    @ViewBuilder
    private func currencyPicker(title: String, selected: Binding<String>, expanded: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.onSurfaceMut)
            ZStack(alignment: .topLeading) {
                Button { withAnimation { expanded.wrappedValue.toggle() } } label: {
                    HStack {
                        Text(selected.wrappedValue)
                            .font(.system(size: 18, weight: .bold)).foregroundStyle(Color.onSurface)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundStyle(Color.onSurfaceMut).font(.system(size: 12))
                    }
                    .padding(12).background(Color.surfaceVar)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.divider, lineWidth: 1))
                }
                if expanded.wrappedValue {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(ALL_CURRENCIES, id: \.self) { cur in
                                Button {
                                    selected.wrappedValue = cur
                                    withAnimation { expanded.wrappedValue = false }
                                    state.result = nil
                                } label: {
                                    HStack {
                                        Text(cur).font(.system(size: 14))
                                            .foregroundStyle(cur == selected.wrappedValue ? Color.cyberBlue : Color.onSurface)
                                        Spacer()
                                        if cur == selected.wrappedValue {
                                            Image(systemName: "checkmark").foregroundStyle(Color.cyberBlue).font(.system(size: 12))
                                        }
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.divider, lineWidth: 1))
                    .offset(y: 44)
                    .zIndex(10)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var swapButton: some View {
        Button {
            let tmp = state.base; state.base = state.target; state.target = tmp
            state.result = nil
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 16)).foregroundStyle(Color.onSurfaceMut)
                .frame(width: 40, height: 44)
                .background(Color.surfaceVar).clipShape(Circle())
        }
        .padding(.top, 18)
    }

    private func fetch() async {
        state.isLoading = true; state.error = nil; state.result = nil
        do    { state.result = try await VKAPIClient.shared.getExchangeRate(base: state.base, target: state.target) }
        catch { state.error = error.localizedDescription }
        state.isLoading = false
    }
}
