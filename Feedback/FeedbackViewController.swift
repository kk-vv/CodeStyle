//
//  FeedbackViewController.swift
//  Chirp
//
//  Created by Felix Hu on 2022/11/2.
//  
//

import UIKit
import Epoxy
import RxSwift
import RxCocoa
import ZLPhotoBrowser

/// System feedback
final class FeedbackViewController:
  CollectionViewController,
  ViewActionProtocol,
  UIGestureRecognizerDelegate {

  private let viewModel: FeedbackViewModelType

  enum SectionID: Hashable {
    case title(AnyHashable)
    case category
    case titleContent
    case message
    case images
    case commit
  }

  enum DataID: Hashable {
    case image(AnyHashable)
    case addAttach
  }

  init(viewModel: FeedbackViewModelType) {
    self.viewModel = viewModel
    super.init(layout: UICollectionViewCompositionalLayout.epoxy)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  static func instantiate() -> Self {
    .init(viewModel: FeedbackViewModel())
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .chirpWhite
    collectionView.backgroundColor = .chirpWhite

    self.title = R.string.localizable.settingMenuFeedback(preferredLanguages: .currentLang)

    // MARK: - Bind view model
    rx.disposeBag.insert {
      viewModel.outputs.viewState
        .enumerated()
        .bind(with: self) { target, value in
          target.setViewState(value.element, animated: value.index > 0)
        }

      viewModel.outputs.viewState
        .map { $0.isActioning }
        .bind(to: rx.isLoading)

      viewModel.outputs.viewState
        .compactMap { $0.actionError }
        .bind(to: rx.onError)

      viewModel.outputs.onCommited
        .bind(with: self) { target, _ in
          target.navigationController?.popViewController(animated: true)
        }

    }

    viewModel.inputs.viewDidLoad()


    RxKeyboard.instance
      .bind(to: collectionView)
      .disposed(by: rx.disposeBag)

    let tap = UITapGestureRecognizer().then {
      $0.rx.event
        .bind { [weak self] _ in
          self?.view.endEditing(true)
        }
        .disposed(by: rx.disposeBag)
    }
    tap.delegate = self
    collectionView.addGestureRecognizer(tap)

  }

  private var categoryView: UIView?

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
//    if touch.view is UICollectionView {
//      return true
//    }
    if touch.view is UIControl
        || touch.view is FeedbackAttachItemView
        || touch.view is FeedbackCategorySelectItemView {
      return false
    }
    return true
  }


  func setViewState(_ viewState: FeedbackViewState, animated: Bool) {
    setSections(with: viewState, animated: animated)
  }

  private func setSections(with viewState: FeedbackViewState, animated: Bool) {
    setSections(sections(with: viewState), animated: animated)
  }

  @SectionModelBuilder
  private func sections(with viewState: FeedbackViewState) -> [SectionModel] {
    SectionModel(
      dataID: SectionID.title(R.string.localizable.feedbackInputCategory(preferredLanguages: .currentLang)),
      items: {
        SingleTextHeader.itemModel(
          dataID: DefaultDataID.noneProvided,
          content: .init(text: R.string.localizable.feedbackInputCategory(preferredLanguages: .currentLang)),
          style: .init(
            textColor: .chirpDark,
            font: .medium(15),
            backgroundColor: .chirpWhite,
            alignment: .left
          )
        )
      }
    )
    .compositionalLayoutSection(.list(itemHeight: 35))

    SectionModel(
      dataID: SectionID.category,
      items: {
        FeedbackCategorySelectItemView.itemModel(
          dataID: DefaultDataID.noneProvided,
          content: .init(category: viewState.category),
          behaviors: .init(onTap: { [weak self] in
            self?.showCategory()
          })
        )
      }
    )
    .compositionalLayoutSection(.list(itemHeight: FeedbackCategorySelectItemView.staticHeight))

    SectionModel(
      dataID: SectionID.title(R.string.localizable.feedbackInputTitle(preferredLanguages: .currentLang)),
      items: {
        SingleTextHeader.itemModel(
          dataID: DefaultDataID.noneProvided,
          content: .init(text: R.string.localizable.feedbackInputTitle(preferredLanguages: .currentLang)),
          style: .init(
            textColor: .chirpDark,
            font: .medium(15),
            backgroundColor: .chirpWhite,
            alignment: .left
          )
        )
      }
    )
    .compositionalLayoutSection(.list(itemHeight: 35))

    SectionModel(
      dataID: SectionID.titleContent,
      items: {
        GroupEditTextFiledInput.itemModel(
          dataID: DefaultDataID.noneProvided,
          content: .init(
            placeholder: R.string.localizable.feedbackPlaceholderTitle(preferredLanguages: .currentLang),
            text: ""
          ),
          behaviors: .init(onValueChange: { [weak self] title in
            self?.viewModel.inputs.titleUpdate(title)
          })
        )
      }
    ).compositionalLayoutSection(.list(itemHeight: 40))

    SectionModel(
      dataID: SectionID.title(R.string.localizable.feedbackInputMessage(preferredLanguages: .currentLang)),
      items: {
        SingleTextHeader.itemModel(
          dataID: DefaultDataID.noneProvided,
          content: .init(text: R.string.localizable.feedbackInputMessage(preferredLanguages: .currentLang)),
          style: .init(
            textColor: .chirpDark,
            font: .medium(15),
            backgroundColor: .chirpWhite,
            alignment: .left
          )
        )
      }
    ).compositionalLayoutSection(.list(itemHeight: 35))

    SectionModel(
      dataID: SectionID.message,
      items: {
        GroupEditTextViewInput.itemModel(
          dataID: DefaultDataID.noneProvided,
          content: .init(
            placeholder: R.string.localizable.feedbackPlaceholderMessage(preferredLanguages: .currentLang),
            text: ""
          ),
          behaviors: .init(onValueChange: { message in
            self.viewModel.inputs.messageUpdate(message)
          })
        )
      }
    ).compositionalLayoutSection(.list(itemHeight: 180))

    SectionModel(
      dataID: SectionID.title(R.string.localizable.feedbackInputImages(preferredLanguages: .currentLang)),
      items: {
        SingleTextHeader.itemModel(
          dataID: DefaultDataID.noneProvided,
          content: .init(text: R.string.localizable.feedbackInputImages(preferredLanguages: .currentLang)),
          style: .init(
            textColor: .chirpDark,
            font: .medium(15),
            backgroundColor: .chirpWhite,
            alignment: .left
          )
        )
      }
    )
    .compositionalLayoutSection(.list(itemHeight: 35))

    SectionModel(
      dataID: SectionID.images,
      items: {
        viewState.images.map { image in
          FeedbackAttachItemView.itemModel(
            dataID: DataID.image(image),
            content: .init(image: image),
            behaviors: .init(
              onDelete: { [weak self] in
                self?.viewModel.inputs.delete(image)
              },
              onSelected: { [weak self] in
                self?.onImages([image], index: nil)
              }
            )
          )
        }

        if viewState.images.count < 6 {
          FeedbackAttachItemView.itemModel(
            dataID: DataID.addAttach,
            content: .init(image: nil),
            behaviors: .init(
              onDelete: {},
              onSelected: { [weak self] in
                self?.showImagePicker()
              }
            )
          )
        }
      }
    ).compositionalLayoutSectionProvider { environment in
      FeedbackAttachItemView.layout(with: environment)
    }

    SectionModel(
      dataID: SectionID.commit,
      items: {
        ButtonItemView.itemModel(
          dataID: DefaultDataID.noneProvided,
          content: .init(
            title: R.string.localizable.buttonSubmit(preferredLanguages: .currentLang),
            color: viewState.commitable ? .chirpMain : .chirpGray,
            backgroundColor: .chirpWhite
          ),
          behaviors: .init(onNext: { [weak self] in
            self?.viewModel.inputs.commit()
          })
        )
      }
    ).compositionalLayoutSection(.list(itemHeight: 100))
  }

  private func showCategory() {
    let controller = FeedbackCategoryViewController()
    controller.onSelect = { [weak self] category in
      self?.dismiss(animated: true)
      self?.viewModel.inputs.categoryUpdate(category)
    }
    self.present(controller, animated: true)
  }

  private func showImagePicker() {
    let maxCount = 6
    let remainCount = maxCount - viewModel.outputs.value.imageCount
    if remainCount > 0 {
      ZLPickerConfig.setMaxCount(remainCount)
      let picker = ZLPhotoPreviewSheet()
      picker.selectImageBlock = { [weak self] items, isFullImage in
        self?.viewModel.inputs.append(images: items.compactMap { $0.image })
      }
      picker.showPhotoLibrary(sender: self)
    } else {
      Toast.showMessage(R.string.localizable.imageMaximun(maxCount, preferredLanguages: .currentLang))
    }

  }

}
