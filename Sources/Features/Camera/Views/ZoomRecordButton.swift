//
//  ZoomRecordButton.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import SwiftUI

struct ZoomRecordButton: View {
    let isRecording: Bool
    let zoomFactor: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onTap: () -> Void
    let onZoomChange: (CGFloat) -> Void

    @State private var isDragging = false
    @State private var dragStartZoom: CGFloat = 1.0
    @State private var buttonScale: CGFloat = 1.0

    private let buttonSize: CGFloat = 72
    private let innerSize: CGFloat = 60

    var body: some View {
        ZStack {
            // 드래그 중 반원 줌 게이지
            if isDragging {
                ZoomGaugeView(
                    zoomFactor: zoomFactor,
                    minZoom: minZoom,
                    maxZoom: maxZoom
                )
                .transition(.opacity)
            }

            // 녹화 버튼
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: buttonSize, height: buttonSize)

                if isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.red)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: innerSize, height: innerSize)
                }
            }
            .scaleEffect(buttonScale)
            .gesture(
                LongPressGesture(minimumDuration: 0.2)
                    .onEnded { _ in
                        isDragging = true
                        dragStartZoom = zoomFactor
                        withAnimation(.easeInOut(duration: 0.15)) {
                            buttonScale = 1.15
                        }
                    }
                    .sequenced(before:
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard isDragging else { return }
                                // 좌우 드래그로 줌 제어
                                let dragX = value.translation.width
                                let sensitivity: CGFloat = 200
                                let normalizedDrag = dragX / sensitivity
                                let zoomRange = maxZoom - minZoom
                                let newZoom = dragStartZoom + normalizedDrag * zoomRange
                                let clamped = min(max(newZoom, minZoom), maxZoom)
                                onZoomChange(clamped)
                            }
                            .onEnded { _ in
                                endDrag()
                            }
                    )
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if !isDragging {
                            onTap()
                        }
                    }
            )
        }
        .frame(height: 140)
    }

    private func endDrag() {
        isDragging = false
        withAnimation(.easeInOut(duration: 0.15)) {
            buttonScale = 1.0
        }
    }
}

// MARK: - 반원형 줌 게이지

struct ZoomGaugeView: View {
    let zoomFactor: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat

    private let gaugeRadius: CGFloat = 55
    private let startAngle: Double = 210
    private let endAngle: Double = 330

    var body: some View {
        ZStack {
            // 배경 호
            Arc(startAngle: .degrees(startAngle), endAngle: .degrees(endAngle))
                .stroke(.white.opacity(0.3), lineWidth: 4)
                .frame(width: gaugeRadius * 2, height: gaugeRadius * 2)

            // 채워진 호
            let progress = (zoomFactor - minZoom) / max(maxZoom - minZoom, 0.01)
            let fillEnd = startAngle + (endAngle - startAngle) * Double(progress)

            Arc(startAngle: .degrees(startAngle), endAngle: .degrees(fillEnd))
                .stroke(.yellow, lineWidth: 4)
                .frame(width: gaugeRadius * 2, height: gaugeRadius * 2)

            // 줌 수치
            Text(String(format: "%.1fx", zoomFactor))
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(.yellow)
                .offset(y: -gaugeRadius - 14)
        }
    }
}

struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
