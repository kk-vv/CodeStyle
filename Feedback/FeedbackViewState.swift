//
//  FeedbackViewState.swift
//  Chirp
//
//  Created by Felix Hu on 2022/11/2.
//  
//

import UIKit

struct FeedbackViewState {

  var commitable: Bool = false

  var category: FeedbackCategory?
  
  var images: [ImageSource] = []

  var isActioning: Bool = false

  var actionError: Error? = nil

  var imageCount: Int {
    images.count
  }

  mutating func delete(_ image: ImageSource) {
    guard let bindKey = image.bindKey else { return }
    self.images = images.filter { $0.bindKey != bindKey }
  }

  mutating func update(_ image: ImageSource) {
    guard let bindKey = image.bindKey else { return }
    self.images = images.map {
      if $0.bindKey == bindKey {
        return image
      }
      return $0
    }
  }

  var remoteURLs: [String] {
    images.compactMap { source in
      switch source {
      case .remoteURL(let url, _, _):
        return url
      default:
        return nil
      }
    }
  }

  var remainUnloadImages: [ImageSource] {
    images.compactMap { source in
      switch source {
      case .image:
        return source
      default:
        return nil
      }
    }
  }

  func index(of image: ImageSource) -> Int? {
    guard let bindKey = image.bindKey else { return nil}
    var index: Int?
    for (idx, item) in images.enumerated() {
      if item.bindKey == bindKey {
        index = idx
        break
      }
    }
    return index
  }

  mutating func append(images: [UIImage]) {
    self.images.append(contentsOf: images.map { ImageSource.image(image: $0, key: UUID().uuidString)})
  }

}
