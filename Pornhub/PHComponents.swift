import SwiftUI

struct PHVideoCard: View {
    let video: PHVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                PHRemoteImage(url: video.thumb)
                if !video.duration.isEmpty {
                    Text(video.duration)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PHLayout.radius, style: .continuous))
            VStack(alignment: .leading, spacing: 7) {
                Text(video.title)
                    .font(.system(.headline, design: .default).weight(.semibold))
                    .foregroundStyle(PHTheme.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    Text(video.author.isEmpty ? "Pornhub" : video.author)
                        .lineLimit(1)
                    if video.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2).foregroundStyle(PHTheme.orange)
                    }
                    Spacer(minLength: 4)
                    if !video.views.isEmpty { Text(video.views).lineLimit(1) }
                }
                .font(.caption)
                .foregroundStyle(PHTheme.secondary)
            }
            .padding(.horizontal, 2)
        }
        .padding(.bottom, 8)
        .padding(.horizontal, PHLayout.gutter)
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

struct PHFilterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PHTheme.text)
            .padding(.horizontal, 14)
            .frame(minHeight: PHLayout.controlHeight)
            .background(PHTheme.card.opacity(configuration.isPressed ? 0.55 : 1), in: Capsule())
            .contentShape(Capsule())
    }
}

struct PHChipRow: View {
    let chips: [PHChip]
    let onSelect: (PHChip) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    Button { onSelect(chip) } label: {
                        HStack(spacing: 6) {
                            if let icon = chip.systemImage { Image(systemName: icon) }
                            Text(chip.title).lineLimit(1)
                        }
                    }
                    .buttonStyle(PHFilterButtonStyle())
                }
            }
            .padding(.horizontal, PHLayout.gutter)
        }
    }
}

struct PHLogo: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Porn").foregroundStyle(.white)
            Text("hub").foregroundStyle(.black)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(PHTheme.orange, in: RoundedRectangle(cornerRadius: 4))
        }
        .font(.system(size: 22, weight: .black)).tracking(-0.6)
    }
}

struct PHScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack {
            Text(title).font(.title2.bold())
            Spacer()
            trailing()
        }
        .padding(.horizontal, PHLayout.gutter).padding(.top, 12)
    }
}

struct PHEmptyState: View {
    let title: String
    let icon: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 30, weight: .light)).foregroundStyle(PHTheme.orange)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(PHTheme.secondary).multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 200)
        .accessibilityElement(children: .combine)
    }
}

struct PHLoading: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView().tint(PHTheme.orange)
            Text("正在加载").font(.caption).foregroundStyle(PHTheme.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .combine)
    }
}

struct PHErrorBanner: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(PHTheme.orange)
            Text("暂时无法加载").font(.headline)
            Text(message).font(.subheadline).foregroundStyle(PHTheme.secondary).multilineTextAlignment(.center)
            Button("重试", action: retry)
                .frame(minHeight: PHLayout.controlHeight)
                .buttonStyle(PHFilterButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
