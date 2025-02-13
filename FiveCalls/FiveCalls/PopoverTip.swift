//
//  PopoverTip.swift
//  FiveCalls
//
//  Created by Christopher Selin on 10/24/23.
//  Copyright © 2023 5calls. All rights reserved.
//

import SwiftUI
import TipKit

@available(iOS 17.0, *)
struct PopoverTip: Tip {
    var title: Text
    var message: Text?
    var image: Image?
    
    var options: [Option] {
        Tips.MaxDisplayCount(3)
    }
}

extension View {
    func popoverTipIfApplicable(title: Text, message: Text?) -> some View {
    if #available(iOS 17, *) {
        return self
            .popoverTip(
                PopoverTip(
                    title: title,
                    message: message
                ),
                arrowEdge: .top
            )
    } else {
      return self
    }
  }
}
