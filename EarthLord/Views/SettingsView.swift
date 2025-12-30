//
//  SettingsView.swift
//  EarthLord
//
//  Created by Claude Code
//

import SwiftUI

struct SettingsView: View {
    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 是否显示删除账户确认对话框
    @State private var showDeleteConfirm = false

    /// 用户输入的确认文本
    @State private var confirmationText = ""

    /// 是否正在删除账户
    @State private var isDeletingAccount = false

    /// 是否显示删除结果提示
    @State private var showDeleteResult = false

    /// 删除结果消息
    @State private var deleteResultMessage = ""

    /// 删除是否成功
    @State private var deleteSuccess = false

    /// 环境变量 - 用于返回上一页
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 账户信息区域
                accountInfoSection
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // 危险区域
                dangerZoneSection
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDeleteConfirm) {
            deleteAccountConfirmSheet
        }
        .alert("删除账户", isPresented: $showDeleteResult) {
            Button("确定", role: .cancel) {
                if deleteSuccess {
                    // 删除成功，不需要额外操作，AuthManager 已经清空状态
                    // RootView 会自动跳转到登录页
                }
            }
        } message: {
            Text(deleteResultMessage)
        }
    }

    // MARK: - 账户信息区域

    private var accountInfoSection: some View {
        VStack(spacing: 15) {
            Text("账户信息")
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                infoRow(label: "邮箱", value: authManager.currentUser?.email ?? "")
                infoRow(label: "用户名", value: authManager.currentUser?.username ?? "未设置")

                if let userId = authManager.currentUser?.id {
                    infoRow(label: "用户ID", value: userId.uuidString.prefix(8) + "...")
                }
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(15)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }

    // MARK: - 危险区域

    private var dangerZoneSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("危险区域")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.red)
                Spacer()
            }

            VStack(spacing: 15) {
                Text("删除账户后，您的所有数据将被永久删除且无法恢复。此操作不可撤销。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)

                Button(action: {
                    print("🔴 点击删除账户按钮")
                    confirmationText = ""
                    showDeleteConfirm = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18))
                        Text("删除账户")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .disabled(isDeletingAccount)
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(15)
        }
    }

    // MARK: - 删除账户确认弹窗

    private var deleteAccountConfirmSheet: some View {
        NavigationStack {
            VStack(spacing: 25) {
                // 警告图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding(.top, 30)

                // 警告文本
                VStack(spacing: 12) {
                    Text("确认删除账户")
                        .font(.system(size: 24, weight: .bold))

                    Text("此操作将永久删除您的账户和所有相关数据，且无法恢复。")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // 确认输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("请输入 \"删除\" 以确认")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("删除", text: $confirmationText)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 20)
                }
                .padding(.horizontal, 20)

                Spacer()

                // 按钮区域
                VStack(spacing: 12) {
                    // 确认删除按钮
                    Button(action: {
                        handleDeleteAccount()
                    }) {
                        HStack {
                            if isDeletingAccount {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("确认删除")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(isDeleteButtonEnabled ? Color.red : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!isDeleteButtonEnabled || isDeletingAccount)
                    .padding(.horizontal, 20)

                    // 取消按钮
                    Button(action: {
                        print("🔵 取消删除账户")
                        showDeleteConfirm = false
                    }) {
                        Text("取消")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .padding(.horizontal, 20)
                    .disabled(isDeletingAccount)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showDeleteConfirm = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                    .disabled(isDeletingAccount)
                }
            }
        }
    }

    // MARK: - 辅助方法

    /// 删除按钮是否可用
    private var isDeleteButtonEnabled: Bool {
        confirmationText.trimmingCharacters(in: .whitespaces) == "删除"
    }

    /// 处理删除账户
    private func handleDeleteAccount() {
        guard isDeleteButtonEnabled else {
            print("⚠️ 确认文本不匹配")
            return
        }

        isDeletingAccount = true
        print("🗑️ 开始删除账户流程...")

        Task {
            let success = await authManager.deleteAccount()

            await MainActor.run {
                isDeletingAccount = false
                showDeleteConfirm = false

                if success {
                    deleteSuccess = true
                    deleteResultMessage = "账户已成功删除"
                    print("✅ 账户删除成功")
                } else {
                    deleteSuccess = false
                    deleteResultMessage = authManager.errorMessage ?? "删除账户失败，请稍后重试"
                    print("❌ 账户删除失败: \(authManager.errorMessage ?? "未知错误")")
                }

                showDeleteResult = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
