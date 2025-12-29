import SwiftUI
import Supabase

struct SupabaseTestView: View {
    // 使用共享的 Supabase 客户端
    private let supabase = SupabaseConfig.shared
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var debugLog: String = "点击按钮开始测试..."

    enum ConnectionStatus {
        case idle
        case testing
        case success
        case failed
    }

    var body: some View {
        VStack(spacing: 30) {
            // 状态图标
            statusIcon
                .font(.system(size: 80))

            // 调试日志文本框
            ScrollView {
                Text(debugLog)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            .frame(height: 300)
            .padding(.horizontal)

            // 测试按钮
            Button(action: testConnection) {
                HStack {
                    if connectionStatus == .testing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(connectionStatus == .testing ? "测试中..." : "测试连接")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: 250)
                .background(connectionStatus == .testing ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .disabled(connectionStatus == .testing)

            Spacer()
        }
        .padding()
        .navigationTitle("Supabase 连接测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // 状态图标
    @ViewBuilder
    private var statusIcon: some View {
        switch connectionStatus {
        case .idle:
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(.gray)
        case .testing:
            ProgressView()
                .scaleEffect(2)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }

    // 测试连接
    private func testConnection() {
        connectionStatus = .testing
        debugLog = "开始测试连接...\n"
        debugLog += "URL: https://dzfylsyvnskzvpwomcim.supabase.co\n"
        debugLog += "------------------------\n"

        Task {
            do {
                debugLog += "发送测试请求...\n"

                // 故意查询一个不存在的表来测试连接
                let _: [String] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果能执行到这里（不太可能），说明表存在
                await MainActor.run {
                    connectionStatus = .success
                    debugLog += "------------------------\n"
                    debugLog += "✅ 连接成功（表查询成功）\n"
                }

            } catch {
                await MainActor.run {
                    let errorMessage = error.localizedDescription
                    debugLog += "捕获到错误: \(errorMessage)\n"
                    debugLog += "------------------------\n"

                    // 判断错误类型
                    if errorMessage.contains("PGRST") ||
                       errorMessage.contains("PGRST205") ||
                       errorMessage.contains("Could not find the table") ||
                       errorMessage.contains("relation") && errorMessage.contains("does not exist") {
                        // 这些错误说明成功连接到了 Supabase 服务器
                        connectionStatus = .success
                        debugLog += "✅ 连接成功（服务器已响应）\n"
                        debugLog += "说明：收到了来自 Supabase 的错误响应，\n"
                        debugLog += "这证明连接是成功的。\n"
                        debugLog += "（查询的表不存在是预期行为）\n"

                    } else if errorMessage.contains("hostname") ||
                              errorMessage.contains("URL") ||
                              errorMessage.contains("NSURLErrorDomain") {
                        // URL 或网络错误
                        connectionStatus = .failed
                        debugLog += "❌ 连接失败：URL 错误或无网络\n"
                        debugLog += "详细信息：\(errorMessage)\n"

                    } else {
                        // 其他未知错误
                        connectionStatus = .failed
                        debugLog += "❌ 连接失败：未知错误\n"
                        debugLog += "详细信息：\(errorMessage)\n"
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
