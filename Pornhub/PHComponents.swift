import SwiftUI

struct PHVideoCard: View {
    let video: PHVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                PHRemoteImage(url: video.thumb)
                if !video.duration.isEmpty {
                    Text(video.duration)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 4))
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(video.author.isEmpty ? "Pornhub" : video.author)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PHTheme.secondary)
                            .lineLimit(1)
                        if video.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(red: 0.25, green: 0.55, blue: 1))
                        }
                        Spacer(minLength: 8)
                        if !video.views.isEmpty {
                            Label(video.views, systemImage: "eye")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PHTheme.secondary)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    Text(video.title)
                        .font(.headline)
                        .foregroundStyle(PHTheme.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 14)
        .phCard()
        .padding(.horizontal, PHLayout.gutter)
    }
}

struct PHChipRow: View {
    let chips: [PHChip]
    let onSelect: (PHChip) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    Button {
                        onSelect(chip)
                    } label: {
                        HStack(spacing: 6) {
                            if let icon = chip.systemImage {
                                Image(systemName: icon)
                                    .font(.system(size: 12, weight: .bold))
                            }
                            Text(chip.title)
                                .lineLimit(1)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: PHLayout.controlHeight)
                        .background(Color(white: 0.16), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PHLayout.gutter)
        }
    }
}

struct PHLogo: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Porn")
                .foregroundStyle(.white)
            Text("hub")
                .foregroundStyle(.black)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(PHTheme.orange, in: RoundedRectangle(cornerRadius: 3))
        }
        .font(.system(size: 24, weight: .black))
        .tracking(-0.6)
    }
}

struct PHScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 28, weight: .bold))
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct PHLoading: View {
    var body: some View {
        ProgressView()
            .tint(PHTheme.orange)
            .frame(maxWidth: .infinity, minHeight: 160)
    }
}

struct PHErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(PHTheme.secondary)
                .multilineTextAlignment(.center)
            Button("重试", action: retry)
                .phAction(prominent: true)
        }
        .padding(24)
    }
}
