import SwiftUI

/// The stepped 1–10 slider: no default position, faint per-stop histogram in
/// the track, tappable numbers, haptic per stop. Committing (drag release or
/// number tap) calls `onCommit` — release = done, no confirm step.
struct RatingSliderView: View {
    @Binding var selected: Int?
    let histogram: [Int]
    let onCommit: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            VStack(spacing: 6) {
                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 3) {
                        let peak = max(histogram.max() ?? 1, 1)
                        ForEach(0..<10, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.quaternary)
                                .frame(height: 4 + 24 * CGFloat(histogram[index]) / CGFloat(peak))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    Capsule().fill(.tertiary).frame(height: 4).offset(y: -2)
                    if let selected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 26, height: 26)
                            .position(x: xPosition(for: selected, in: width), y: 0)
                            .offset(y: -2)
                    }
                }
                .frame(height: 34)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            selected = stop(at: value.location.x, in: width)
                        }
                        .onEnded { value in
                            onCommit(stop(at: value.location.x, in: width))
                        }
                )
                HStack(spacing: 0) {
                    ForEach(1...10, id: \.self) { number in
                        Text("\(number)")
                            .font(.caption.monospacedDigit())
                            .fontWeight(selected == number ? .bold : .regular)
                            .foregroundStyle(selected == number ? Color.accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selected = number
                                onCommit(number)
                            }
                    }
                }
            }
        }
        .frame(height: 60)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func stop(at x: CGFloat, in width: CGFloat) -> Int {
        min(10, max(1, Int((x / width) * 10) + 1))
    }

    private func xPosition(for stop: Int, in width: CGFloat) -> CGFloat {
        width * (CGFloat(stop) - 0.5) / 10
    }
}
