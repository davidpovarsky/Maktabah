//
//  ReaderTabStripCell.swift
//  Maktabah
//
//  Downstream-owned UICollectionViewCell for a single reader document tab in ReaderDocumentTabsBarController.
//
//  Attribution:
//  Adapted from duckduckgo/apple-browsers @ f1d574485cf2f0586bcb284e8b3ca8c2f6ff7f32
//  License: Apache License 2.0 (Copyright (c) DuckDuckGo)
//

#if os(iOS)
import UIKit

/// Represents the display model for a single cell in the document tab strip.
public struct ReaderTabStripItemModel: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String?
    public let backend: BackendID
    public let isSelected: Bool
    public let isDormantUnavailable: Bool

    public init(
        id: UUID,
        title: String,
        subtitle: String? = nil,
        backend: BackendID = .otzaria,
        isSelected: Bool = false,
        isDormantUnavailable: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.backend = backend
        self.isSelected = isSelected
        self.isDormantUnavailable = isDormantUnavailable
    }
}

/// UIKit collection-view cell rendering a reader document tab with title, icon, close button, pointer hover, and active flare.
final class ReaderTabStripCell: UICollectionViewCell {
    static let reuseIdentifier = "ReaderTabStripCell"

    var onCloseTapped: (() -> Void)?

    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let leadingFlare = ReaderTabStripFlareView(side: .leading)
    private let trailingFlare = ReaderTabStripFlareView(side: .trailing)

    private var isHovered: Bool = false {
        didSet {
            guard isHovered != oldValue else { return }
            updateAppearance()
        }
    }

    private var currentModel: ReaderTabStripItemModel?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = 10
        cardView.layer.cornerCurve = .continuous
        contentView.addSubview(cardView)

        leadingFlare.translatesAutoresizingMaskIntoConstraints = false
        trailingFlare.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(leadingFlare)
        contentView.addSubview(trailingFlare)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.numberOfLines = 1

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        let closeConfig = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: closeConfig), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.addTarget(self, action: #selector(handleCloseTap), for: .touchUpInside)
        closeButton.accessibilityLabel = "סגור כרטיסייה"

        cardView.addSubview(iconImageView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            leadingFlare.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            leadingFlare.trailingAnchor.constraint(equalTo: cardView.leadingAnchor),
            leadingFlare.widthAnchor.constraint(equalToConstant: 8),
            leadingFlare.heightAnchor.constraint(equalToConstant: 8),

            trailingFlare.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            trailingFlare.leadingAnchor.constraint(equalTo: cardView.trailingAnchor),
            trailingFlare.widthAnchor.constraint(equalToConstant: 8),
            trailingFlare.heightAnchor.constraint(equalToConstant: 8),

            iconImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            iconImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 15),
            iconImageView.heightAnchor.constraint(equalToConstant: 15),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),

            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        cardView.addGestureRecognizer(hoverGesture)
    }

    func configure(with model: ReaderTabStripItemModel, onClose: @escaping () -> Void) {
        self.currentModel = model
        self.onCloseTapped = onClose

        if let subtitle = model.subtitle, !subtitle.isEmpty, subtitle != model.title {
            titleLabel.text = "\(model.title) · \(subtitle)"
        } else {
            titleLabel.text = model.title
        }

        let symbolName = model.isDormantUnavailable ? "exclamationmark.triangle" : "book.closed"
        iconImageView.image = UIImage(systemName: symbolName)

        isAccessibilityElement = true
        accessibilityLabel = titleLabel.text
        accessibilityTraits = model.isSelected ? [.button, .selected] : [.button]

        updateAppearance()
    }

    private func updateAppearance() {
        guard let model = currentModel else { return }

        if model.isSelected {
            let activeBg = UIColor.systemBackground
            cardView.backgroundColor = activeBg
            cardView.layer.borderWidth = 0.8
            cardView.layer.borderColor = UIColor.separator.withAlphaComponent(0.45).cgColor
            titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = .label
            iconImageView.tintColor = .tintColor
            closeButton.alpha = 1.0
            leadingFlare.isHidden = false
            trailingFlare.isHidden = false
            leadingFlare.fillColor = activeBg
            trailingFlare.fillColor = activeBg
        } else if isHovered {
            cardView.backgroundColor = UIColor.secondarySystemFill
            cardView.layer.borderWidth = 0
            titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            titleLabel.textColor = .label
            iconImageView.tintColor = .secondaryLabel
            closeButton.alpha = 0.9
            leadingFlare.isHidden = true
            trailingFlare.isHidden = true
        } else {
            cardView.backgroundColor = UIColor.tertiarySystemFill.withAlphaComponent(0.65)
            cardView.layer.borderWidth = 0
            titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            titleLabel.textColor = model.isDormantUnavailable ? .tertiaryLabel : .secondaryLabel
            iconImageView.tintColor = model.isDormantUnavailable ? .systemOrange : .secondaryLabel
            closeButton.alpha = 0.65
            leadingFlare.isHidden = true
            trailingFlare.isHidden = true
        }
    }

    @objc private func handleCloseTap() {
        onCloseTapped?()
    }

    @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            isHovered = true
        case .ended, .cancelled, .failed:
            isHovered = false
        default:
            break
        }
    }
}
#endif
