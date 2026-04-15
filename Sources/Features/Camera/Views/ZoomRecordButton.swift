//
//  ZoomRecordButton.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import SwiftUI
import UIKit

struct ZoomDialControl: View {
    let zoomFactor: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onZoomChange: (CGFloat) -> Void

    @State private var isExpanded = false
    @State private var dragStartZoom: CGFloat?
    @State private var activeSnapZoom: CGFloat?
    @State private var collapseTask: DispatchWorkItem?
    @State private var haptics = ZoomDialHaptics()

    private let controlHeight: CGFloat = 264
    private let centerAngle: CGFloat = 270
    private let visibleHalfSpan: CGFloat = 76
    private let entrySnapThreshold: CGFloat = 0.12
    private let releaseSnapThreshold: CGFloat = 0.24

    var body: some View {
        GeometryReader { proxy in
            let layout = dialLayout(in: proxy.size)

            ZStack(alignment: .bottom) {
                expandedDial(layout: layout)
                    .opacity(isExpanded ? 1 : 0)
                    .offset(y: isExpanded ? 0 : 16)
                    .scaleEffect(isExpanded ? 1 : 0.985, anchor: .bottom)
                    .allowsHitTesting(isExpanded)
                    .gesture(dragGesture(layout: layout))

                collapsedButton
                    .opacity(isExpanded ? 0 : 1)
                    .offset(y: isExpanded ? 10 : -44)
                    .allowsHitTesting(!isExpanded)
                    .gesture(dragGesture(layout: layout))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity)
        .frame(height: controlHeight)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: isExpanded)
        .onDisappear {
            cancelCollapse()
            haptics.reset()
        }
    }

    private var collapsedButton: some View {
        Text(formattedZoom(zoomFactor))
            .font(.system(.subheadline, design: .monospaced))
            .fontWeight(.semibold)
            .foregroundStyle(.yellow)
            .frame(width: 58, height: 38)
            .background(.black.opacity(0.56))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
    }

    private func expandedDial(layout: DialLayout) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.44),
                            .black.opacity(0.26),
                            .black.opacity(0.12),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [.white.opacity(0.06), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 70)
                }

            ZStack {
                arcPath(
                    from: centerAngle - visibleHalfSpan,
                    to: centerAngle + visibleHalfSpan,
                    radius: layout.arcRadius,
                    center: layout.center
                )
                .stroke(.white.opacity(0.12), style: StrokeStyle(lineWidth: 12, lineCap: .round))

                arcPath(
                    from: centerAngle - visibleHalfSpan,
                    to: centerAngle + visibleHalfSpan,
                    radius: layout.arcRadius,
                    center: layout.center
                )
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )

                ForEach(tickMarks) { tick in
                    if let angle = angle(for: tick.value, layout: layout) {
                        tickView(for: tick, angle: angle, layout: layout)
                    }
                }

                Capsule()
                    .fill(.yellow)
                    .frame(width: 76, height: 38)
                    .overlay {
                        Text(formattedZoom(zoomFactor))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                    }
                    .shadow(color: .black.opacity(0.24), radius: 10, y: 5)
                    .position(point(at: centerAngle, radius: layout.arcRadius, center: layout.center))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
    }

    private func tickView(for tick: TickMark, angle: CGFloat, layout: DialLayout) -> some View {
        let innerPoint = point(
            at: angle,
            radius: layout.arcRadius - tick.innerInset,
            center: layout.center
        )
        let outerPoint = point(
            at: angle,
            radius: layout.arcRadius + 3,
            center: layout.center
        )
        let labelPoint = point(
            at: angle,
            radius: layout.arcRadius + 22,
            center: layout.center
        )
        let distanceFromCenter = abs(angle - centerAngle)
        let falloff = max(0, 1 - (distanceFromCenter / (visibleHalfSpan + 8)))
        let opacity = 0.28 + (falloff * 0.72)
        let isSnapped = activeSnapZoom == tick.value

        return ZStack {
            Path { path in
                path.move(to: innerPoint)
                path.addLine(to: outerPoint)
            }
            .stroke(
                (isSnapped ? Color.yellow : tick.color).opacity(opacity),
                style: StrokeStyle(lineWidth: isSnapped ? tick.lineWidth + 0.8 : tick.lineWidth, lineCap: .round)
            )

            if tick.showsLabel && distanceFromCenter > 10 {
                Text(tick.label)
                    .font(.system(size: tick.labelSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle((isSnapped ? Color.yellow : .white).opacity(opacity))
                    .position(labelPoint)
            }
        }
    }

    private func dragGesture(layout: DialLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                cancelCollapse()

                if !isExpanded {
                    withAnimation {
                        isExpanded = true
                    }
                    haptics.prepare()
                }

                if dragStartZoom == nil {
                    dragStartZoom = zoomFactor
                    activeSnapZoom = nearestActiveSnap(to: zoomFactor)
                }

                guard let dragStartZoom else { return }

                let proposedZoom = dragStartZoom - (value.translation.width / layout.pointsPerZoomUnit)
                let resolvedZoom = resolvedZoom(for: proposedZoom)
                onZoomChange(resolvedZoom)
            }
            .onEnded { _ in
                dragStartZoom = nil
                activeSnapZoom = nil
                haptics.reset()
                scheduleCollapse()
            }
    }

    private var tickMarks: [TickMark] {
        let step: CGFloat = maxZoom - minZoom > 6 ? 0.5 : 0.25
        let count = Int(((maxZoom - minZoom) / step).rounded(.up))
        let snapStops = preferredSnapStops

        return (0...count).map { index in
            let rawValue = minZoom + (CGFloat(index) * step)
            let value = min(rawValue, maxZoom)
            let roundedValue = (value * 100).rounded() / 100
            let nearestInteger = roundedValue.rounded()
            let isInteger = abs(roundedValue - nearestInteger) < 0.01
            let isSnapStop = snapStops.contains { abs($0 - roundedValue) < 0.01 }

            if isInteger || isSnapStop {
                return TickMark(
                    id: index,
                    value: roundedValue,
                    innerInset: isSnapStop ? 22 : 18,
                    lineWidth: isSnapStop ? 2.6 : 2.1,
                    color: .white,
                    showsLabel: true,
                    label: formattedLabel(roundedValue),
                    labelSize: isSnapStop ? 12 : 11
                )
            }

            return TickMark(
                id: index,
                value: roundedValue,
                innerInset: step == 0.5 ? 12 : 14,
                lineWidth: step == 0.5 ? 1.4 : 1.1,
                color: .white.opacity(0.74),
                showsLabel: false,
                label: "",
                labelSize: 0
            )
        }
    }

    private var preferredSnapStops: [CGFloat] {
        let candidates: [CGFloat] = [minZoom, 1, 2, 3, 5, maxZoom]
        var stops: [CGFloat] = []

        for candidate in candidates where candidate >= minZoom - 0.01 && candidate <= maxZoom + 0.01 {
            let normalized = (candidate * 100).rounded() / 100
            if !stops.contains(where: { abs($0 - normalized) < 0.01 }) {
                stops.append(normalized)
            }
        }

        return stops.sorted()
    }

    private func resolvedZoom(for proposedZoom: CGFloat) -> CGFloat {
        let clampedZoom = clampZoom(proposedZoom)

        if let activeSnapZoom {
            if abs(clampedZoom - activeSnapZoom) <= releaseSnapThreshold {
                return activeSnapZoom
            }

            self.activeSnapZoom = nil
        }

        guard let nearest = nearestSnapStop(to: clampedZoom) else {
            return clampedZoom
        }

        guard abs(clampedZoom - nearest) <= entrySnapThreshold else {
            return clampedZoom
        }

        activeSnapZoom = nearest
        haptics.snap(to: nearest)
        return nearest
    }

    private func nearestSnapStop(to zoom: CGFloat) -> CGFloat? {
        preferredSnapStops.min { abs($0 - zoom) < abs($1 - zoom) }
    }

    private func nearestActiveSnap(to zoom: CGFloat) -> CGFloat? {
        guard let nearest = nearestSnapStop(to: zoom) else { return nil }
        return abs(nearest - zoom) <= entrySnapThreshold ? nearest : nil
    }

    private func angle(for value: CGFloat, layout: DialLayout) -> CGFloat? {
        let angle = centerAngle + ((value - zoomFactor) * layout.degreesPerZoomUnit)
        let minimumAngle = centerAngle - visibleHalfSpan - 3
        let maximumAngle = centerAngle + visibleHalfSpan + 3

        guard angle >= minimumAngle, angle <= maximumAngle else { return nil }
        return angle
    }

    private func dialLayout(in size: CGSize) -> DialLayout {
        let horizontalInset: CGFloat = 22
        let chordWidth = max(size.width - (horizontalInset * 2), 240)
        let spanRadians = visibleHalfSpan * .pi / 180
        let arcRadius = chordWidth / (2 * sin(spanRadians))
        let usableWidth = max(size.width - 56, 180)
        let zoomRange = max(maxZoom - minZoom, 0.01)
        let pointsPerZoomUnit = usableWidth / zoomRange
        let degreesPerZoomUnit = max((pointsPerZoomUnit / arcRadius) * 180 / .pi, 11)

        return DialLayout(
            center: CGPoint(x: size.width / 2, y: size.height - 10),
            arcRadius: arcRadius,
            pointsPerZoomUnit: pointsPerZoomUnit,
            degreesPerZoomUnit: degreesPerZoomUnit
        )
    }

    private func point(at angle: CGFloat, radius: CGFloat, center: CGPoint) -> CGPoint {
        let radians = angle * .pi / 180

        return CGPoint(
            x: center.x + (cos(radians) * radius),
            y: center.y + (sin(radians) * radius)
        )
    }

    private func arcPath(from startAngle: CGFloat, to endAngle: CGFloat, radius: CGFloat, center: CGPoint) -> Path {
        let step: CGFloat = startAngle < endAngle ? 2 : -2
        let firstPoint = point(at: startAngle, radius: radius, center: center)

        return Path { path in
            path.move(to: firstPoint)

            var current = startAngle
            while (step > 0 && current <= endAngle) || (step < 0 && current >= endAngle) {
                path.addLine(to: point(at: current, radius: radius, center: center))
                current += step
            }

            path.addLine(to: point(at: endAngle, radius: radius, center: center))
        }
    }

    private func clampZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, minZoom), maxZoom)
    }

    private func formattedZoom(_ value: CGFloat) -> String {
        String(format: "%.1fx", value)
    }

    private func formattedLabel(_ value: CGFloat) -> String {
        if abs(value.rounded() - value) < 0.01 {
            return String(format: "%.0f", value)
        }

        return String(format: "%.1f", value)
    }

    private func scheduleCollapse() {
        let item = DispatchWorkItem {
            withAnimation {
                isExpanded = false
            }
        }

        collapseTask = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: item)
    }

    private func cancelCollapse() {
        collapseTask?.cancel()
        collapseTask = nil
    }
}

private struct DialLayout {
    let center: CGPoint
    let arcRadius: CGFloat
    let pointsPerZoomUnit: CGFloat
    let degreesPerZoomUnit: CGFloat
}

private struct TickMark: Identifiable {
    let id: Int
    let value: CGFloat
    let innerInset: CGFloat
    let lineWidth: CGFloat
    let color: Color
    let showsLabel: Bool
    let label: String
    let labelSize: CGFloat
}

private final class ZoomDialHaptics {
    private let generator = UISelectionFeedbackGenerator()
    private var lastSnap: CGFloat?

    func prepare() {
        generator.prepare()
    }

    func snap(to value: CGFloat) {
        guard lastSnap == nil || abs((lastSnap ?? value) - value) > 0.01 else { return }
        lastSnap = value
        generator.selectionChanged()
        generator.prepare()
    }

    func reset() {
        lastSnap = nil
        generator.prepare()
    }
}
