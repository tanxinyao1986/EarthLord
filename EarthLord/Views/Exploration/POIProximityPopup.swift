//
//  POIProximityPopup.swift
//  EarthLord
//
//  Day22: POI 接近弹窗 - 玩家进入 POI 范围时显示
//

import SwiftUI
import CoreLocation

/// POI 接近弹窗
struct POIProximityPopup: View {
    // MARK: - Properties

    let poi: POI
    let onScavenge: () -> Void
    let onDismiss: () -> Void

    // MARK: - Animation State

    @State private var isAnimating = false
    @State private var pulseAnimation = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 弹窗卡片
            VStack(spacing: 20) {
                // 图标和标题
                headerSection

                // 分割线
                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // POI 信息
                infoSection

                // 按钮区域
                buttonSection
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(ApocalypseTheme.cardBackground)
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: -10)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 34)
            .offset(y: isAnimating ? 0 : 300)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isAnimating)
        }
        .background(
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // 点击背景关闭
                    withAnimation {
                        isAnimating = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                }
        )
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            // 启动脉冲动画
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // 发现图标（带脉冲效果）
            ZStack {
                // 脉冲圈
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)

                // 内圈
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                // 类型图标
                Image(systemName: poi.category.icon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }

            // 标题
            VStack(spacing: 4) {
                Text("发现废墟！")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(poi.name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        HStack(spacing: 20) {
            // 类型标签
            VStack(spacing: 4) {
                Text("类型")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)

                HStack(spacing: 4) {
                    Text(poi.category.emoji)
                        .font(.system(size: 16))
                    Text(poi.category.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.background.opacity(0.5))
            .cornerRadius(12)

            // 状态标签
            VStack(spacing: 4) {
                Text("状态")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("可搜刮")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.success)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.background.opacity(0.5))
            .cornerRadius(12)
        }
    }

    // MARK: - Button Section

    private var buttonSection: some View {
        HStack(spacing: 12) {
            // 稍后再说按钮
            Button(action: {
                withAnimation {
                    isAnimating = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }) {
                Text("稍后再说")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(ApocalypseTheme.background)
                    .cornerRadius(12)
            }

            // 立即搜刮按钮
            Button(action: {
                // 震动反馈
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                withAnimation {
                    isAnimating = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onScavenge()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .bold))
                    Text("立即搜刮")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            ApocalypseTheme.primary,
                            ApocalypseTheme.primaryDark
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    POIProximityPopup(
        poi: POI(
            id: "test_poi",
            name: "沃尔玛超市",
            coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            category: .supermarket
        ),
        onScavenge: { print("搜刮") },
        onDismiss: { print("关闭") }
    )
}
