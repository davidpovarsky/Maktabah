//
//  ReaderTabStripFlareView.swift
//  Maktabah
//
//  Downstream-owned subtle bottom corner flare view for the active tab cell in ReaderDocumentTabsBarController.
//
//  Attribution:
//  Adapted from duckduckgo/apple-browsers @ f1d574485cf2f0586bcb284e8b3ca8c2f6ff7f32
//  License: Apache License 2.0 (Copyright (c) DuckDuckGo)
//

#if os(iOS)
import UIKit

/// Draws a subtle concave bottom corner flare on the active tab so it visually merges into the reader surface below.
final class ReaderTabStripFlareView: UIView {
    enum Side {
        case leading
        case trailing
    }

    private let side: Side
    private let shapeLayer = CAShapeLayer()

    var fillColor: UIColor = .secondarySystemBackground {
        didSet {
            shapeLayer.fillColor = fillColor.cgColor
        }
    }

    init(side: Side) {
        self.side = side
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(shapeLayer)
        shapeLayer.fillColor = fillColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }

        let path = UIBezierPath()
        switch side {
        case .leading:
            path.move(to: CGPoint(x: w, y: 0))
            path.addQuadCurve(to: CGPoint(x: 0, y: h), controlPoint: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: w, y: h))
            path.close()
        case .trailing:
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: h), controlPoint: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.close()
        }
        shapeLayer.path = path.cgPath
    }
}
#endif
