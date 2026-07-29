import SwiftUI
import SwiftData

// MARK: - Figure Type Badge

struct FigureTypeBadge: View {
    let figureType: FigureType?

    var body: some View {
        Text(figureType?.name ?? "Unknown")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(figureType?.color.opacity(0.12) ?? .gray.opacity(0.12))
            )
    }
}

// MARK: - Figure Icon Circle

struct FigureIconCircle: View {
    let figureType: FigureType?
    let size: CGFloat

    init(figureType: FigureType?, size: CGFloat = 48) {
        self.figureType = figureType
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(figureType?.color.opacity(0.2) ?? .gray.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: figureType?.icon ?? "questionmark")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(figureType?.color ?? .gray)
            )
    }
}

// MARK: - Figure Name with Gender

struct FigureNameWithGender: View {
    let name: String
    let gender: Figure.Gender
    let disambiguation: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.title.bold())
            Text(gender.symbol)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        if let disambiguation = disambiguation, !disambiguation.isEmpty {
            Text(disambiguation)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Figure Title Row

struct FigureTitleRow: View {
    let title: String

    var body: some View {
        if !title.isEmpty {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Figure Header

struct FigureHeaderView: View {
    let figure: Figure
    var showBirthDate: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            FigureIconCircle(figureType: figure.figureType)
            VStack(alignment: .leading, spacing: 2) {
                FigureNameWithGender(
                    name: figure.name,
                    gender: figure.gender,
                    disambiguation: figure.disambiguation
                )
                FigureTitleRow(title: figure.title)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                FigureTypeBadge(figureType: figure.figureType)
                if showBirthDate {
                    Text(figure.birthDate.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Figure Description

struct FigureDescriptionView: View {
    let text: String
    var richData: Data? = nil

    var body: some View {
        if !text.isEmpty || richData != nil {
            RichTextDisplay(richData: richData, fallback: text)
                .font(.body)
        }
    }
}

// MARK: - Figure Place Association Row

struct FigurePlaceAssociationRow: View {
    let association: FigurePlaceAssociation
    var onSelectPlace: ((Place) -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: association.place?.placeType?.icon ?? "mappin")
                .font(.caption)
                .foregroundStyle(.teal)
                .frame(width: 14)
            Text(association.roleType?.name ?? "—")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let place = association.place {
                if let onSelectPlace {
                    Button(action: { onSelectPlace(place) }) {
                        Text(place.name)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.accentColor)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .pointingHand()
                } else {
                    Text(place.name)
                        .font(.callout)
                        .fontWeight(.medium)
                }
            } else {
                Text("?")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !association.source.isEmpty {
                Text(association.source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Figure Place Association Row (Dossier style)

struct FigurePlaceAssociationDossierRow: View {
    let association: FigurePlaceAssociation

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: association.place?.placeType?.icon ?? "mappin")
                .font(.caption)
                .foregroundStyle(.teal)
                .frame(width: 14)
            Text(association.roleType?.name ?? "—")
                .font(.caption)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.teal.opacity(0.1)))
            if let place = association.place {
                EntityLink(name: place.name, kind: .place)
                    .font(.callout)
            } else {
                Text("?")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !association.source.isEmpty {
                Text(association.source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
    }
}

// MARK: - Figure Citations Row

struct FigureCitationsRow: View {
    let citation: Citation

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundStyle(.brown)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(citation.source?.name ?? "Unknown"), \(citation.safeLocation)")
                    .font(.caption)
                    .fontWeight(.medium)
                Text(citation.safeNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Figure Relationship Row

struct FigureRelationshipRow: View {
    let relationshipTypeName: String
    let relative: Figure
    var onSelectFigure: ((Figure) -> Void)?
    var icon: String?
    var color: Color?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon ?? "arrow.down")
                .font(.caption)
                .foregroundStyle(color ?? .gray)
                .frame(width: 16)
            Text("\(relationshipTypeName):")
                .font(.callout)
                .foregroundStyle(.secondary)
            if let onSelectFigure {
                Button(action: { onSelectFigure(relative) }) {
                    Text(relative.name)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accentColor)
                        .underline()
                }
                .buttonStyle(.plain)
                .pointingHand()
            } else {
                Text(relative.name)
                    .font(.callout)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Figure Dossier Relationship List (Parents / Spouses / Children / etc.)

struct FigureDossierRelationshipList: View {
    let label: String
    let figures: [Figure]

    var body: some View {
        if !figures.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Text(label + ":")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
                HStack(spacing: 4) {
                    ForEach(figures, id: \.persistentModelID) { fig in
                        EntityLink(name: fig.name, kind: .figure)
                    }
                }
                .font(.callout)
            }
        }
    }
}
