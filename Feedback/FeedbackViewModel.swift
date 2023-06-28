//
//  FeedbackViewModel.swift
//  Chirp
//
//  Created by Felix Hu on 2022/11/2.
//  
//

import Action
import RxSwift
import RxCocoa

fileprivate struct FeedbackCacheModel {

  var category: FeedbackCategory

  var title: String

  var message: String

  var remainImages: [ImageSource] // waiting for upload images

  var remoteURLs: [String] // uploaded images

}

struct FeedbackPostParams {

  var category: FeedbackCategory

  var title: String

  var message: String?

  var images: [String] // uploaded images

}

protocol FeedbackViewModelInputs {

  func viewDidLoad()

  func categoryUpdate(_ category: FeedbackCategory)

  func titleUpdate(_ title: String)

  func messageUpdate(_ message: String)

  func append(images: [UIImage])

  func delete(_ image: ImageSource)

  func commit()
}

protocol FeedbackViewModelOutputs {

  var viewState: Observable<FeedbackViewState> { get }

  var commitable: Observable<Bool> { get }

  var onCommited: Observable<Void> { get }

  var value: FeedbackViewState { get }

}

protocol FeedbackViewModelType {

  var inputs: FeedbackViewModelInputs { get }

  var outputs: FeedbackViewModelOutputs { get }
}


final class FeedbackViewModel: FeedbackViewModelType, FeedbackViewModelInputs, FeedbackViewModelOutputs {

  var viewState: Observable<FeedbackViewState> {
    backingViewState.asObservable()
  }

  var value: FeedbackViewState {
    backingViewState.value
  }

  var commitable: Observable<Bool> {
    commitableOutput.asObservable()
  }

  var onCommited: Observable<Void> {
    onCommitedOutput.asObservable()
  }

  private let disposeBag = DisposeBag()

  private let viewDidLoadInput = PublishRelay<Void>()
  
  private let backingViewState = BehaviorRelay<FeedbackViewState>(value: .init())

  private let imagesInput = BehaviorRelay<[UIImage]>(value: [])

  private let titleInput = BehaviorRelay<String>(value: "")

  private let messageInput = PublishRelay<String>()

  private let commitInput = PublishRelay<Void>()

  private let commitableOutput = BehaviorRelay<Bool>(value: false)

  private let onCommitedOutput = PublishRelay<Void>()

  private let imagesUploadGroupTaskFinished = PublishRelay<Void>()

  private let onFileUploaded = PublishRelay<FileResponse>()

  private let fileService: FileService

  init(
    service: SystemService = .live,
    fileService: FileService = .live
  ) {

    self.fileService = fileService

    let postAction = Action { params in
      service.feedback(params)
    }

    postAction.elements
      .map(to: ())
      .bind(to: onCommitedOutput)
      .disposed(by: disposeBag)

    postAction.executing
      .reduce( backingViewState) { viewState, isActioning in
        viewState.isActioning = isActioning
        viewState.actionError = nil
      }
      .disposed(by: disposeBag)

    postAction.underlyingError
      .reduce(backingViewState) { viewState, error in
        viewState.isActioning = false
        viewState.actionError = error
      }
      .disposed(by: disposeBag)

    imagesInput
      .reduce(backingViewState) { viewState, images in
        viewState.append(images: images)
      }
      .disposed(by: disposeBag)

//    Observable.combineLatest(titleInput, backingViewState)
//      .map { text, viewState in
//        return !text.isEmpty && viewState.category != nil
//      }
//      .bind(to: commitableOutput)
//      .disposed(by: disposeBag)

    titleInput
      .reduce(backingViewState) { viewState, title in
        viewState.commitable = (!title.isEmpty && viewState.category != nil)
      }
      .disposed(by: disposeBag)

    let postParams = commitInput
      .withLatestFrom(
        Observable.combineLatest(
          titleInput,
          messageInput.startWith(""),
          backingViewState
        )
      ).map { title, message, viewState in
        FeedbackCacheModel(
          category: viewState.category ?? .other,
          title: title,
          message: message,
          remainImages: viewState.remainUnloadImages,
          remoteURLs: viewState.remoteURLs
        )
      }

    postParams
      .filter { $0.remainImages.isEmpty && !$0.title.isEmpty } // no images
      .map {
        FeedbackPostParams(
          category: $0.category,
          title: $0.title,
          message: $0.message.isEmpty ? nil : $0.message,
          images: $0.remoteURLs
        )
      }
      .bind(to: postAction.inputs)
      .disposed(by: disposeBag)

    postParams.filter { !$0.remainImages.isEmpty } // has images not upload
      .map { $0.remainImages }
      .bind(with: self, onNext: { target, images in
        target.groupUpload(images)
      })
      .disposed(by: disposeBag)

    onFileUploaded
      .reduce(backingViewState) { viewState, fileModel in
        viewState.update(.remoteURL(url: fileModel.fileUrl, key: fileModel.originalFileName, placeholder: nil))
      }
      .disposed(by: disposeBag)

    imagesUploadGroupTaskFinished
      .reduce(backingViewState) { viewState, _ in
        viewState.isActioning = false
      }
      .disposed(by: disposeBag)

    imagesUploadGroupTaskFinished
      .withLatestFrom(backingViewState)
      .map { $0.remainUnloadImages.count }
      .filter { $0 != 0 }
      .reduce(backingViewState) { viewState, failedCount in
        viewState.actionError = CustomError.custom(R.string.localizable.newMomentImageUpdateFailed(failedCount, preferredLanguages: .currentLang))
      }
      .disposed(by: disposeBag)

    imagesUploadGroupTaskFinished
      .withLatestFrom(backingViewState)
      .filter { $0.remainUnloadImages.isEmpty }
      .map { $0.remoteURLs }
      .filter { !$0.isEmpty }
      .asObservable()
      .withLatestFrom(postParams) { urls, cacheParams in
        FeedbackPostParams(
          category: cacheParams.category,
          title: cacheParams.title,
          message: cacheParams.message,
          images: urls
        )
      }
      .bind(to: postAction.inputs)
      .disposed(by: disposeBag)
  }

  private func groupUpload(_ images: [ImageSource]) {
    setViewState {
      $0.isActioning = true
    }
    let queue = DispatchQueue(label: "feedback.upload.chirp.com", attributes: .concurrent)
    queue.async { [weak self] in
      guard let self = self else {
        DispatchQueue.main.async {
          self?.setViewState {
            $0.isActioning = false
          }
        }
        return
      }
      let semaphore = DispatchSemaphore(value: min(images.count, 6))
      let group = DispatchGroup()
      for source in images {
        if let image = source.image, let imageName = source.bindKey {
          semaphore.wait()
          group.enter()

          self.fileService.upload(image, .feedback, imageName)
            .subscribe(
              onSuccess: { file in
                self.onFileUploaded.accept(file)
                group.leave()
                semaphore.signal()
              },
              onFailure: { error in
                group.leave()
                semaphore.signal()
              }
            )
            .disposed(by: self.disposeBag)
        }
      }

      group.notify(queue: DispatchQueue.main) {
        self.imagesUploadGroupTaskFinished.accept(())
      }
    }
  }

  func viewDidLoad() {
    viewDidLoadInput.accept(())
  }

  func categoryUpdate(_ category: FeedbackCategory) {
    setViewState {
      $0.category = category
    }
  }

  func append(images: [UIImage]) {
    imagesInput.accept(images)
  }

  func titleUpdate(_ title: String) {
    titleInput.accept(title)
  }

  func messageUpdate(_ message: String) {
    messageInput.accept(message)
  }

  func commit() {
    commitInput.accept(())
  }

  func delete(_ image: ImageSource) {
    setViewState {
      $0.delete(image)
    }
  }

  func setViewState(_ setter: (inout FeedbackViewState) -> Void) {
    var viewState = backingViewState.value
    setter(&viewState)
    backingViewState.accept(viewState)
  }

  var inputs: FeedbackViewModelInputs { return self }

  var outputs: FeedbackViewModelOutputs { return self }
}
