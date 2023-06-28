//
//  FeedbackAttachItemView.swift
//  Chirp
//
//  Created by Felix Hu on 2022/11/2.
//

import UIKit
import RxCocoa
import RxSwift
import EpoxyCore

final class FeedbackAttachItemView: View, EpoxyableView {

  static func layout(with environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
    let itemWidth = floor((UIScreen.width - NSPadding.screenEdge * 2 - 8 * 2) / 3)

    let item = NSCollectionLayoutItem(
      layoutSize: .init(
        widthDimension: .absolute(itemWidth),
        heightDimension: .fractionalHeight(1)
      )
    )

    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: .init(
        widthDimension: .fractionalWidth(1),
        heightDimension: .absolute(itemWidth)
      ),
      subitem: item,
      count: 3
    )
    group.interItemSpacing = .fixed(8)

    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = 8
    section.contentInsets = .init(
      top: 5,
      leading: NSPadding.screenEdge,
      bottom: 5,
      trailing: NSPadding.screenEdge
    )
    return section
  }

  struct Content: Equatable {

    let image: ImageSource?

  }

  struct Behaviors {

    let onDelete: EmptyCallback

    let onSelected: EmptyCallback

  }

  private var behaviors: Behaviors?

  private lazy var imageView = UIImageView().then {
    $0.contentMode = .scaleAspectFill
    $0.clipsToBounds = true
  }

  private let deleteButton = UIButton.with(R.image.camera.close()!)

  private let uploadImage = UIImageView.with(R.image.me.upload()!).then {
    $0.isHidden = true
  }

  override func configureView() {
    addSubview(imageView)
    addSubview(deleteButton)

    backgroundColor = .chirpWhite

    layer.cornerRadius = .corner8
    clipsToBounds = true

    imageView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }

    deleteButton.snp.makeConstraints { make in
      make.trailing.top.equalToSuperview()
      make.size.equalTo(24)
    }

    deleteButton.rx.tap
      .bind { [weak self] _ in
        self?.behaviors?.onDelete()
      }
      .disposed(by: rx.disposeBag)

    let tap = UITapGestureRecognizer().then {
      $0.rx.event
        .bind { [weak self] _ in
          self?.behaviors?.onSelected()
        }
        .disposed(by: rx.disposeBag)
    }

    addGestureRecognizer(tap)

    addSubview(uploadImage)
    uploadImage.snp.makeConstraints { make in
      make.center.equalToSuperview()
      make.width.height.equalTo(20)
    }
  }

  func setContent(_ content: Content, animated: Bool) {
    if let image = content.image {
      backgroundColor = .chirpWhite
      imageView.isHidden = false
      imageView.setImage(resource: image)
      deleteButton.isHidden = false
      uploadImage.isHidden = true
    } else {
      backgroundColor = .chirpBackground
      imageView.isHidden = true
      imageView.image = nil
      deleteButton.isHidden = true
      uploadImage.isHidden = false
    }
  }

  func setBehaviors(_ behaviors: Behaviors?) {
    self.behaviors = behaviors
  }

}
