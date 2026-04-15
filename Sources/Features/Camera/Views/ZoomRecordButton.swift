//
//  ZoomRecordButton.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import SwiftUI

struct ZoomDialControl: View {
    let zoomFactor: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onZoomChange: (CGFloat) -> Void

    @State private var isExpanded = false
    @State private var dragStartZoom: CGFloat = 1.0
    @State private var collapseTask: DispatchWorkItem?

    private let dialWidth: CGFloat = 280
    private let dialHeight: CGFloat = 44

    var body: some View {
        ZStack {
            if isExpanded {
                expandedDial
                    .transition(.scale.combined(with: .opacity))
            }

            // 줌 버튼
            Text(String(format: "%.1fx", zoomFactor))
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.yellow)
                .frame(width: 52, height: 36)
                .background(.black.opacity(isExpanded ? 0 : 0.5))
                .clipShape(Capsule())
                .opacity(isExpanded ? 0 : 1)
        }
        .frame(width: UIScreen.main.bounds.width, height: 200)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    cancelCollapse()

                    if !isExpanded {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded = true
                        }
                        dragStartZoom = zoomFactor
                    }

                    let translationX = value.translation.width
                    let sensitivity: CGFloat = 250
                    let normalizedDrag = translationX / sensitivity
                    let zoomRange = maxZoom - minZoom
                    let newZoom = dragStartZoom + normalizedDrag * zoomRange
                    let clamped = min(max(newZoom, minZoom), maxZoom)
                    onZoomChange(clamped)
                }
                .onEnded { _ in
                    scheduleCollapse()
                }
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private var expandedDial: some View {
        let scaleWidth: CGFloat = 400
        let progress = (zoomFactor - minZoom) / max(maxZoom - minZoom, 0.01)
        let scaleOffset = (progress - 0.5) * scaleWidth

        return ZStack {
            Capsule()
                .fill(.black.opacity(0.7))
                .frame(width: dialWidth, height: dialHeight)

            // 눈금 — 현재 줌이 중앙에 오도록 전체 스케일을 이동
            Canvas { context, size in
                let ticks = tickValues
                let count = ticks.count
                guard count > 1 else { return }

                for (i, value) in ticks.enumerated() {
                    // 각 눈금의 위치를 scaleWidth 기준으로 계산
                    let tickProgress = CGFloat(i) / CGFloat(count - 1)
                    let x = tickProgress * scaleWidth + scaleOffset + size.width / 2 - scaleWidth / 2

                    guard x > 4 && x < size.width - 4 else { continue }

                    let isMain = value.truncatingRemainder(dividingBy: 1.0) == 0
                    let isFilled = value <= zoomFactor

                    if isMain {
                        let text = Text(String(format: "%.0f", value))
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(isFilled ? .yellow : .white.opacity(0.5))
                        context.draw(
                            context.resolve(text),
                            at: CGPoint(x: x, y: size.height / 2)
                        )
                    } else {
                        let rect = CGRect(
                            x: x - 0.5,
                            y: (size.height - 8) / 2,
                            width: 1,
                            height: 8
                        )
                        context.fill(
                            Path(rect),
                            with: .color(isFilled ? .yellow : .white.opacity(0.25))
                        )
                    }
                }
            }
            .frame(width: dialWidth - 8, height: dialHeight)
            .clipShape(Capsule())

            // 노브 — 항상 중앙 고정
            Circle()
                .fill(.yellow)
                .frame(width: 30, height: 30)
                .overlay {
                    Text(String(format: "%.1f", zoomFactor))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                }
        }
        .allowsHitTesting(false)
    }

    private var tickValues: [CGFloat] {
        var marks: [CGFloat] = []
        var v = minZoom
        while v <= maxZoom {
            marks.append(v)
            v += 0.5
        }
        return marks
    }

    private func scheduleCollapse() {
        let item = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = false
            }
        }
        collapseTask = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
    }

    private func cancelCollapse() {
        collapseTask?.cancel()
        collapseTask = nil
    }
}
