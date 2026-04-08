import SwiftUI
import UIKit

// MARK: - BouncyDialogList
// Список диалогов с BouncyLayout (эластичная прокрутка)
struct BouncyDialogList: UIViewRepresentable {
    let items: [DialogItem]
    let onSelect: (DialogItem) -> Void

    func makeUIView(context: Context) -> UICollectionView {
        let layout = BouncyLayout(style: .regular)
        layout.minimumLineSpacing = 0
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width, height: 72)
        layout.scrollDirection = .vertical

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.alwaysBounceVertical = true
        cv.register(DialogCell.self, forCellWithReuseIdentifier: "cell")
        cv.dataSource = context.coordinator
        cv.delegate   = context.coordinator
        return cv
    }

    func updateUIView(_ cv: UICollectionView, context: Context) {
        context.coordinator.items    = items
        context.coordinator.onSelect = onSelect
        cv.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(items: items, onSelect: onSelect)
    }

    class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        var items:    [DialogItem]
        var onSelect: (DialogItem) -> Void

        init(items: [DialogItem], onSelect: @escaping (DialogItem) -> Void) {
            self.items = items; self.onSelect = onSelect
        }

        func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int {
            items.count
        }

        func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
            let cell = cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip) as! DialogCell
            cell.configure(with: items[ip.row])
            return cell
        }

        func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
            onSelect(items[ip.row])
        }
    }
}

// MARK: - DialogCell
private class DialogCell: UICollectionViewCell {
    private let avatarView  = UIImageView()
    private let nameLabel   = UILabel()
    private let msgLabel    = UILabel()
    private let timeLabel   = UILabel()
    private let badgePill   = UILabel()
    private let onlineDot   = UIView()
    private let separator   = UIView()
    private var currentUrl: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        // Avatar
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.layer.cornerRadius = 24
        avatarView.clipsToBounds = true
        avatarView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        contentView.addSubview(avatarView)

        // Online dot
        onlineDot.translatesAutoresizingMaskIntoConstraints = false
        onlineDot.backgroundColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
        onlineDot.layer.cornerRadius = 5
        onlineDot.layer.borderWidth = 2
        onlineDot.layer.borderColor = UIColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 1).cgColor
        contentView.addSubview(onlineDot)

        // Name
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .white
        contentView.addSubview(nameLabel)

        // Last message
        msgLabel.translatesAutoresizingMaskIntoConstraints = false
        msgLabel.font = .systemFont(ofSize: 13)
        msgLabel.textColor = UIColor(white: 0.55, alpha: 1)
        msgLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(msgLabel)

        // Time
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.textColor = UIColor(white: 0.4, alpha: 1)
        timeLabel.textAlignment = .right
        contentView.addSubview(timeLabel)

        // Unread badge
        badgePill.translatesAutoresizingMaskIntoConstraints = false
        badgePill.font = .systemFont(ofSize: 11, weight: .bold)
        badgePill.textColor = .white
        badgePill.textAlignment = .center
        badgePill.backgroundColor = UIColor(red: 0.1, green: 0.55, blue: 0.95, alpha: 1)
        badgePill.layer.cornerRadius = 9
        badgePill.clipsToBounds = true
        contentView.addSubview(badgePill)

        // Separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor(white: 1, alpha: 0.05)
        contentView.addSubview(separator)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 48),
            avatarView.heightAnchor.constraint(equalToConstant: 48),

            onlineDot.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 1),
            onlineDot.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 1),
            onlineDot.widthAnchor.constraint(equalToConstant: 10),
            onlineDot.heightAnchor.constraint(equalToConstant: 10),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),

            msgLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            msgLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            msgLabel.trailingAnchor.constraint(equalTo: badgePill.leadingAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            timeLabel.widthAnchor.constraint(equalToConstant: 52),

            badgePill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            badgePill.centerYAnchor.constraint(equalTo: msgLabel.centerYAnchor),
            badgePill.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            badgePill.heightAnchor.constraint(equalToConstant: 18),

            separator.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    func configure(with item: DialogItem) {
        nameLabel.text = item.name
        msgLabel.text  = item.lastMessage.isEmpty ? "Нет сообщений" : item.lastMessage
        onlineDot.isHidden = !item.isOnline

        // Unread badge
        if item.unreadCount > 0 {
            badgePill.text = item.unreadCount > 99 ? "99+" : "\(item.unreadCount)"
            badgePill.isHidden = false
        } else {
            badgePill.isHidden = true
        }

        // Avatar
        let urlStr = item.avatar ?? ""
        guard urlStr != currentUrl else { return }
        currentUrl = urlStr
        avatarView.image = nil
        if let url = URL(string: urlStr), !urlStr.isEmpty {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let img = UIImage(data: data),
                      self?.currentUrl == urlStr else { return }
                DispatchQueue.main.async { self?.avatarView.image = img }
            }.resume()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.image = nil; currentUrl = nil
        nameLabel.text = nil; msgLabel.text = nil
        timeLabel.text = nil; badgePill.isHidden = true
        onlineDot.isHidden = true
    }
}

// MARK: - BouncyNavDialogList
// SwiftUI wrapper: BouncyDialogList + NavigationLink
struct BouncyNavDialogList: View {
    let items: [DialogItem]
    @State private var selected: DialogItem? = nil

    var body: some View {
        ZStack {
            BouncyDialogList(items: items) { dialog in
                selected = dialog
            }
            // Hidden NavigationLink trigger
            if let sel = selected {
                NavigationLink(
                    destination: ChatView(peerId: sel.id, peerName: sel.name, peerAvatar: sel.avatar),
                    isActive: Binding(
                        get: { selected?.id == sel.id },
                        set: { if !$0 { selected = nil } }
                    )
                ) { EmptyView() }
                .hidden()
            }
        }
    }
}
