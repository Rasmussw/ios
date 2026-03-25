//
//  NCUploadAssetsView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit

struct NCUploadAssetsView: View {
    @ObservedObject var model: NCUploadAssetsModel

    @State private var showSelect = false
    @State private var showRenameAlert = false
    @State private var renameFileName: String = ""
    @State private var renameIndex: Int = 0
    @State private var didAutoUpload = false

    let gridItems: [GridItem] = [GridItem()]

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                List {
                    // Preview
                    if !model.previewStore.isEmpty {
                        Section(footer: Text(NSLocalizedString("_modify_image_desc_", comment: "")).font(.footnote)) {
                            ScrollView(.horizontal) {
                                LazyHGrid(rows: gridItems, alignment: .center, spacing: 10) {
                                    ForEach(0..<model.previewStore.count, id: \.self) { index in
                                        let item = model.previewStore[index]

                                        Menu {
                                            Button(action: {
                                                renameFileName = item.fileName
                                                renameIndex = index
                                                showRenameAlert = true
                                            }) {
                                                Label(NSLocalizedString("_rename_", comment: ""), systemImage: "pencil")
                                            }

                                            Button(role: .destructive, action: {
                                                model.deleteAsset(index: index)
                                            }) {
                                                Label(NSLocalizedString("_remove_", comment: ""), systemImage: "trash")
                                            }

                                        } label: {
                                            ImageAsset(model: model, index: index)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Button("Upload") {
                            model.uploadInProgress = true

                            model.save { metadatasNOConflict, metadatasUploadInConflict in

                                if metadatasUploadInConflict.isEmpty {
                                    model.dismissCreateFormUploadConflict(metadatas: metadatasNOConflict)
                                } else {
                                    model.metadatasNOConflict = metadatasNOConflict
                                    model.metadatasUploadInConflict = metadatasUploadInConflict
                                    // hvis du ikke har UI til conflicts:
                                    model.dismissCreateFormUploadConflict(metadatas: metadatasNOConflict)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(model.uploadInProgress)
                    }
                }
            }
            .navigationTitle("Upload")
            .navigationBarItems(trailing: Button(action: {
                model.dismissView = true
            }) {
                Image(systemName: "xmark")
            })
        }
        .onReceive(model.$dismissView) { newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onAppear {
            model.startAutoUploadIfNeeded()
        }
    }

    struct ImageAsset: View {
        @ObservedObject var model: NCUploadAssetsModel
        @State var index: Int

        var body: some View {
            if index < model.previewStore.count {
                let item = model.previewStore[index]

                if let image = item.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                } else {
                    Color.gray
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                }
            }
        }
    }
}
