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

            // 줌 버튼 (항상 존재, 확장 시 투명)
            Text(String(format: "%.1fx", zoomFactor))
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.yellow)
                .frame(width: 52, height: 36)
                .background(.black.opacity(isExpanded ? 0 : 0.5))
                .clipShape(Capsule())
                .opacity(isExpanded ? 0 : 1)
        }
        // 제스처 영역: 화면 너비 × 세로 200pt — 손가락이 위아래로 벗어나도 추적
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

                    // translation 기반 — 손가락이 어디에 있든 좌우 이동량만 추적
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
        ZStack {
            Capsule()
                .fill(.black.opacity(0.7))
                .frame(width: dialWidth, height: dialHeight)

            // 눈금
            HStack(spacing: 0) {
                ForEach(tickValues, id: \.self) { value in
                    if value.truncatingRemainder(dividingBy: 1.0) == 0 {
                        Text(String(format: "%.0f", value))
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(value <= zoomFactor ? .yellow : .white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    } else {
                        Rectangle()
                            .fill(value <= zoomFactor ? .yellow : .white.opacity(0.25))
                            .frame(width: 1, height: 8)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(width: dialWidth - 40)

            // 인디케이터
            let progress = (zoomFactor - minZoom) / max(maxZoom - minZoom, 0.01)
            let xOffset = (progress - 0.5) * (dialWidth - 52)

            Circle()
                .fill(.yellow)
                .frame(width: 30, height: 30)
                .overlay {
                    Text(String(format: "%.1f", zoomFactor))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                }
                .offset(x: xOffset)
        }
        .allowsHitTesting(false) // 제스처는 부모에서 처리
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
