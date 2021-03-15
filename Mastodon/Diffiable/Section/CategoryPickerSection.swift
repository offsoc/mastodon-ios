//
//  CategoryPickerSection.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021/3/5.
//

import UIKit

enum CategoryPickerSection: Equatable, Hashable {
    case main
}

extension CategoryPickerSection {
    static func collectionViewDiffableDataSource(
        for collectionView: UICollectionView,
        dependency: NeedsDependency
    ) -> UICollectionViewDiffableDataSource<CategoryPickerSection, CategoryPickerItem> {
        UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: PickServerCategoryCollectionViewCell.self), for: indexPath) as! PickServerCategoryCollectionViewCell
            switch item {
            case .all:
                cell.categoryView.titleLabel.font = .systemFont(ofSize: 17)
            case .category:
                cell.categoryView.titleLabel.font = .systemFont(ofSize: 28)
            }
            cell.categoryView.titleLabel.text = item.title
            cell.observe(\.isSelected, options: [.initial, .new]) { cell, _ in
                if cell.isSelected {
                    cell.categoryView.bgView.backgroundColor = Asset.Colors.lightBrandBlue.color
                    cell.categoryView.bgView.applyShadow(color: Asset.Colors.lightBrandBlue.color, alpha: 1, x: 0, y: 0, blur: 4.0)
                    if case .all = item {
                        cell.categoryView.titleLabel.textColor = Asset.Colors.lightWhite.color
                    }
                } else {
                    cell.categoryView.bgView.backgroundColor = Asset.Colors.lightWhite.color
                    cell.categoryView.bgView.applyShadow(color: Asset.Colors.lightBrandBlue.color, alpha: 0, x: 0, y: 0, blur: 0.0)
                    if case .all = item {
                        cell.categoryView.titleLabel.textColor = Asset.Colors.lightBrandBlue.color
                    }
                }
            }
            .store(in: &cell.observations)
            return cell
        }
    }
}