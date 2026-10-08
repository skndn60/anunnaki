import SwiftUI
import SwiftData
import MeCore

/// The figures that make up a collective, plus the collective itself.
///
/// A collective — the Anunnaki, the Assyrians — is an assembly of figures rather than an
/// individual, so father and mother do not apply to it. The lineage strip answers that by
/// rendering two red "unknown parent" slots, which is a claim about the data that is not
/// merely unresearched but false: there is no such thing as the father of the Assyrians.
/// This view stands in the lineage strip's place and shows the structure a collective
/// actually has — its members, read from the incoming `"Member of"` relationships (the
/// `membership` category) that the Relationships section already lists.
struct CollectiveMembershipStrip: View {
    /// Enough to read as a roll of names without pushing the description off-screen.
    static let memberLimit = 12

    let figure: Figure
    let relationships: [Relationship]
    var onSelectFigure: ((Figure) -> Void)?

    private var members: [Figure] {
        collectiveMembers(of: figure, from: relationships)
    }

    private var overflowCount: Int {
        max(0, members.count - Self.memberLimit)
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 12)

            VStack(spacing: 10) {
                if members.isEmpty {
                    noMembersChip
                } else {
                    memberGrid
                }

                trunk

                MiniChip(name: figure.name, symbol: figure.gender.symbol, color: chipColor(figure), isHighlighted: true)
            }
            .padding(.vertical, 8)
        }
    }

    private var memberGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 160), spacing: 6)], alignment: .center, spacing: 6) {
            ForEach(members.prefix(Self.memberLimit), id: \.persistentModelID) { member in
                MiniChip(name: member.name, symbol: member.gender.symbol, color: chipColor(member), isClickable: true) {
                    onSelectFigure?(member)
                }
            }
            if overflowCount > 0 {
                Text("+\(overflowCount) more")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help("Open the Relationships section to see every member")
            }
        }
    }

    /// A collective with no members recorded is a real gap — the Anunnaki and the Igigi
    /// both sit here — but it is not an unknown *parent*, so it must not borrow the red
    /// dashed styling or the "add father" affordance that `MiniLineageView` uses.
    private var noMembersChip: some View {
        MiniChip(name: "no members recorded", symbol: "—", color: .secondary, isClickable: false)
            .help("A collective is made up of members rather than parents. Link figures to this one with a “Member of” relationship.")
    }

    private var trunk: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1, height: 12)
            Image(systemName: "chevron.down")
                .font(.system(size: 8))
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }

    private func chipColor(_ fig: Figure) -> Color { fig.figureType?.color ?? .gray }
}
