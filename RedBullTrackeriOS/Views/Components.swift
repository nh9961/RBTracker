import SwiftUI

extension View {
  func materialCard(radius: CGFloat = 24) -> some View {
    liquidGlass(radius: radius)
  }

  // ios 26 gets the fancy glass; everyone else gets regular material and cope.
  @ViewBuilder
  func liquidGlass(radius: CGFloat = 24, tint: Color? = nil) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    if #available(iOS 26.0, *) {
      if let tint {
        self
          .glassEffect(.regular.tint(tint.opacity(0.18)), in: shape)
          .overlay(shape.stroke(.white.opacity(0.28), lineWidth: 0.8))
      } else {
        self
          .glassEffect(.regular, in: shape)
          .overlay(shape.stroke(.white.opacity(0.28), lineWidth: 0.8))
      }
    } else {
      self
        .background(.regularMaterial, in: shape)
        .overlay(shape.stroke(.white.opacity(0.38), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.08), radius: 22, x: 0, y: 12)
    }
  }

  @ViewBuilder
  func liquidBackground(_ theme: AppTheme) -> some View {
    self
      .background {
        AppBackground(theme: theme)
      }
  }

  @ViewBuilder
  func glassButton() -> some View {
    if #available(iOS 26.0, *) {
      self.buttonStyle(.glass)
    } else {
      self.buttonStyle(.bordered)
    }
  }

  @ViewBuilder
  func glassProminentButton() -> some View {
    if #available(iOS 26.0, *) {
      self.buttonStyle(.glassProminent)
    } else {
      self.buttonStyle(.borderedProminent)
    }
  }
}

struct AppBackground: View {
  var theme: AppTheme

  var body: some View {
    LinearGradient(
      colors: [
        Color(.systemBackground),
        theme.background,
        theme.primary.opacity(0.10),
        theme.secondary.opacity(0.08),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
  }
}

struct GlassSection<Content: View>: View {
  var title: String
  var subtitle: String?
  var symbol: String?
  var tint: Color?
  @ViewBuilder var content: Content

  init(title: String, subtitle: String? = nil, symbol: String? = nil, tint: Color? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.subtitle = subtitle
    self.symbol = symbol
    self.tint = tint
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        if let symbol {
          Image(systemName: symbol)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint ?? .primary)
            .frame(width: 32, height: 32)
            .background((tint ?? .primary).opacity(0.11), in: Circle())
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.headline)
          if let subtitle {
            Text(subtitle)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 0)
      }

      content
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .liquidGlass(radius: 26, tint: tint)
  }
}

struct SectionCard<Content: View>: View {
  var title: String
  var subtitle: String?
  @ViewBuilder var content: Content

  var body: some View {
    GlassSection(title: title, subtitle: subtitle, content: { content })
  }
}

struct MetricTile: View {
  var label: String
  var value: String
  var detail: String
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Image(systemName: symbol)
        .font(.headline.weight(.semibold))
        .foregroundStyle(color)
        .frame(width: 34, height: 34)
        .background(color.opacity(0.12), in: Circle())

      VStack(alignment: .leading, spacing: 4) {
        Text(value)
          .font(.title3.weight(.semibold))
          .lineLimit(2)
          .minimumScaleFactor(0.72)
        Text(label)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
        Text(detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(16)
    .frame(width: 154, height: 148, alignment: .topLeading)
    .liquidGlass(radius: 22, tint: color)
  }
}

struct EmptyStateView: View {
  var title: String
  var copy: String
  var actionLabel: String?
  var systemImage: String = "bolt.fill"
  var action: (() -> Void)?

  init(title: String, copy: String, actionLabel: String? = nil, systemImage: String = "bolt.fill", action: (() -> Void)? = nil) {
    self.title = title
    self.copy = copy
    self.actionLabel = actionLabel
    self.systemImage = systemImage
    self.action = action
  }

  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: systemImage)
        .font(.title3.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 48, height: 48)
        .background(.thinMaterial, in: Circle())
      VStack(spacing: 5) {
        Text(title)
          .font(.headline)
        Text(copy)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      if let actionLabel, let action {
        Button(actionLabel, systemImage: "plus", action: action)
          .glassButton()
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
  }
}

struct StatusRail: View {
  @EnvironmentObject private var store: AppStore

  var body: some View {
    VStack(spacing: 10) {
      if let busy = store.busyAction {
        StatusCapsule(text: "Working on \(busy.replacingOccurrences(of: "-", with: " "))", symbol: "arrow.triangle.2.circlepath", color: .blue)
      }
      if !store.syncError.isEmpty {
        StatusCapsule(text: store.syncError, symbol: "exclamationmark.triangle.fill", color: .red)
      }
      if !store.setupStatus.isOK {
        StatusCapsule(text: store.setupStatus.message, symbol: "exclamationmark.circle.fill", color: .orange)
      }
    }
  }
}

struct StatusCapsule: View {
  var text: String
  var symbol: String
  var color: Color

  var body: some View {
    Label(text, systemImage: symbol)
      .font(.footnote.weight(.medium))
      .foregroundStyle(color)
      .padding(.horizontal, 13)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(color.opacity(0.11), in: Capsule())
  }
}

extension View {
  func statusStyle(color: Color) -> some View {
    self
      .font(.footnote.weight(.medium))
      .foregroundStyle(color)
      .padding(.horizontal, 13)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

struct LimitProgressRow: View {
  var label: String
  var value: String
  var progress: Double
  var isOver: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(label)
          .font(.subheadline.weight(.medium))
        Spacer()
        Text(value)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(isOver ? .red : .primary)
      }
      ProgressView(value: progress)
        .tint(isOver ? .red : progress >= 0.75 ? .orange : .green)
    }
  }
}

struct EntryRowView: View {
  var entry: RedBullEntry
  var onEdit: () -> Void
  var onDelete: () -> Void

  var body: some View {
    HStack(spacing: 14) {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(Color(hex: entry.flavourAccent))
        .frame(width: 5)

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(entry.flavour)
            .font(.headline)
          Text(entry.source.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }

        if let date = DateCodec.date(from: entry.dateTime) {
          Text(DateFormatters.humanDateTime.string(from: date))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        HStack(spacing: 10) {
          Label("\(Metrics.one(entry.cans))", systemImage: "bolt.fill")
          Label(Metrics.money(Metrics.spend(for: entry)), systemImage: "sterlingsign")
          Label("\(Metrics.whole(Metrics.caffeine(for: entry)))mg", systemImage: "waveform.path.ecg")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)

        if !entry.store.isEmpty || !entry.notes.isEmpty {
          Text([entry.store, entry.notes].filter { !$0.isEmpty }.joined(separator: " . "))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      Spacer(minLength: 0)

      Menu {
        Button("Edit", systemImage: "pencil", action: onEdit)
        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
      } label: {
        Image(systemName: "ellipsis")
          .font(.headline.weight(.semibold))
          .frame(width: 36, height: 36)
          .contentShape(Circle())
      }
      .glassButton()
    }
    .padding(14)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

struct LegalFootnote: View {
  var body: some View {
    Text("Synced with Appwrite. Your intake history stays tied to your account.")
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct ConfigValueRow: View {
  var label: String
  var value: String

  var body: some View {
    LabeledContent(label) {
      Text(value.isEmpty ? "not set" : value)
        .font(.caption.monospaced())
        .lineLimit(1)
        .truncationMode(.middle)
        .foregroundStyle(.secondary)
    }
  }
}
