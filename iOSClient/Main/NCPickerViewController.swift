// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import AVFoundation
import SwiftUI
import TLPhotoPicker
import MobileCoreServices
import Photos
import NextcloudKit

// MARK: - Photo Picker

@MainActor
class NCPhotosPickerViewController: NSObject {
    var controller: NCMainTabBarController
    var maxSelectedAssets = 1
    var singleSelectedMode = false
    let global = NCGlobal.shared

    var windowScene: UIWindowScene? {
        SceneManager.shared.getWindowScene(controller: controller)
    }

    @discardableResult
    init(controller: NCMainTabBarController, maxSelectedAssets: Int, singleSelectedMode: Bool) {
        self.controller = controller
        super.init()
        self.maxSelectedAssets = maxSelectedAssets
        self.singleSelectedMode = singleSelectedMode

        openPhotosPickerViewController { assets in
            guard !assets.isEmpty else {
                return
            }
            let model = NCUploadAssetsModel(assets: assets, serverUrl: controller.currentServerUrl(), controller: controller)
            let view = NCUploadAssetsView(model: model)
            let viewController = UIHostingController(rootView: view)

            controller.present(viewController, animated: true, completion: nil)
        }
    }

    private func openPhotosPickerViewController(completition: @escaping ([TLPHAsset]) -> Void) {
        var configure = TLPhotosPickerConfigure()
        var pickerVC: TLPhotosPickerViewController?

        configure.cancelTitle = NSLocalizedString("_cancel_", comment: "")
        configure.doneTitle = NSLocalizedString("_add_", comment: "")
        configure.emptyMessage = NSLocalizedString("_no_albums_", comment: "")
        configure.tapHereToChange = NSLocalizedString("_tap_here_to_change_", comment: "")

        if maxSelectedAssets > 0 {
            configure.maxSelectedAssets = maxSelectedAssets
        }
        configure.selectedColor = NCBrandColor.shared.getElement(account: controller.account)
        configure.singleSelectedMode = singleSelectedMode
        configure.allowedAlbumCloudShared = true

        pickerVC = customPhotoPickerViewController(withTLPHAssets: { assets in
            pickerVC?.dismiss(animated: true) {
                completition(assets)
            }
        }, didCancel: nil)

        //pickerVC?.delegate = self
        configure.usedCameraButton = false
        pickerVC?.configure = configure

        pickerVC?.didExceedMaximumNumberOfSelection = { _ in
            Task {
                await showErrorBanner(windowScene: self.windowScene, text: "_limited_dimension_", errorCode: NCGlobal.shared.errorInternalError)
            }
        }

        pickerVC?.handleNoAlbumPermissions = { _ in
            Task {
                await showErrorBanner(windowScene: self.windowScene, text: "_denied_album_", errorCode: NCGlobal.shared.errorForbidden)
            }
        }

        pickerVC?.handleNoCameraPermissions = { _ in
            Task {
                await showErrorBanner(windowScene: self.windowScene, text: "_denied_camera_", errorCode: NCGlobal.shared.errorForbidden)
            }
        }

        pickerVC?.configure = configure
        guard let pickerVC else {
            return
        }

        DispatchQueue.main.async {
            self.controller.present(pickerVC, animated: true, completion: nil)
        }
    }
}

class customPhotoPickerViewController: TLPhotosPickerViewController {

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔥 customPhotoPickerViewController loaded")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyCustomButtons()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyCustomButtons() // 🔥 sikrer den ikke forsvinder
    }

    // MARK: - UI

    override func makeUI() {
        super.makeUI()
        // ❗️ Sæt IKKE knapper her – de bliver overskrevet
    }

    private func applyCustomButtons() {
        guard let navItem = self.customNavItem else { return }

        // Undgå at sætte dem igen og igen
        if navItem.rightBarButtonItem?.action == #selector(openMyCustomCamera) {
            return
        }

        let cameraBtn = UIBarButtonItem(
            barButtonSystemItem: .camera,
            target: self,
            action: #selector(openMyCustomCamera)
        )

        let closeBtn = UIBarButtonItem(
            barButtonSystemItem: .stop,
            target: self,
            action: #selector(customAction)
        )

        cameraBtn.tintColor = NCBrandColor.shared.iconImageColor
        closeBtn.tintColor = NCBrandColor.shared.iconImageColor

        navItem.rightBarButtonItem = cameraBtn
        navItem.leftBarButtonItem = closeBtn
    }

    // MARK: - Actions

    @objc private func openMyCustomCamera() {

        guard let tabBar = self.presentingViewController as? NCMainTabBarController
                ?? self.view.window?.rootViewController as? NCMainTabBarController
        else { return }

        let cameraVC = NCPhotosPickerCameraViewController(controller: tabBar)

        cameraVC.onCapture = { [weak self, weak cameraVC] url, isVideo in
            guard let self else { return }

            cameraVC?.dismiss(animated: true)

            self.handleCapturedMedia(url: url, isVideo: isVideo)
        }

        cameraVC.modalPresentationStyle = .fullScreen
        self.present(cameraVC, animated: true)
    }
    
    private func handleCapturedMedia(url: URL, isVideo: Bool) {

        guard let tabBar = self.view.window?.rootViewController as? NCMainTabBarController else { return }

        let model = NCUploadAssetsModel(
            tempAssets: [url],
            serverUrl: tabBar.currentServerUrl(),
            controller: tabBar
        )

        let view = NCUploadAssetsView(model: model)
        let vc = UIHostingController(rootView: view)

        tabBar.present(vc, animated: true)
    }
    
    private func presentUpload(url: URL, isVideo: Bool) {

        let tabBar = self.view.window?.rootViewController as! NCMainTabBarController

        let model = NCUploadAssetsModel(
            tempAssets: [url],
            serverUrl: tabBar.currentServerUrl(),
            controller: tabBar
        )

        let view = NCUploadAssetsView(model: model)
        let vc = UIHostingController(rootView: view)

        tabBar.present(vc, animated: true)
    }

    @objc private func customAction() {
        self.dismiss(animated: true)
    }
}


// menuActionElement.append(UIAction(
  //   title: NSLocalizedString("_upload_photos_videos_", comment: ""),
    // image: utility.loadImage(named: "photo", colors: [NCBrandColor.shared.iconImageColor])
 // ) { _ in

    // NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
        // if hasPermission {
            // DispatchQueue.main.async {
           //      let cameraVC = NCPhotosPickerCameraViewController(controller: controller)
         //        controller.present(cameraVC, animated: true)
       //      }
     //    }
   //  }
 //})





@MainActor
class NCPhotosPickerCameraViewController: UIViewController,
                                         AVCapturePhotoCaptureDelegate,
                                         AVCaptureFileOutputRecordingDelegate {

    private var session: AVCaptureSession!
    private var photoOutput: AVCapturePhotoOutput!
    private var movieOutput: AVCaptureMovieFileOutput!
    private var previewLayer: AVCaptureVideoPreviewLayer!

    var controller: NCMainTabBarController!
    
    // MARK: - Init

    init(controller: NCMainTabBarController) {
        self.controller = controller
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }
    
    var onCapture: ((URL, Bool) -> Void)?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        session = AVCaptureSession()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            print("Camera setup failed")
            return
        }

        session.addInput(input)

        // Photo output
        photoOutput = AVCapturePhotoOutput()
        session.addOutput(photoOutput)

        // Video output
        movieOutput = AVCaptureMovieFileOutput()
        session.addOutput(movieOutput)

        // Preview
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds

        view.layer.addSublayer(previewLayer)

        session.startRunning()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session?.stopRunning()
    }

    // MARK: - UI

    private func setupUI() {

        // CLOSE BUTTON
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.frame = CGRect(x: 20, y: 60, width: 40, height: 40)
        closeButton.addTarget(self, action: #selector(closeCamera), for: .touchUpInside)
        view.addSubview(closeButton)

        // PHOTO BUTTON
        let photoButton = UIButton(type: .system)
        photoButton.backgroundColor = .white
        photoButton.layer.cornerRadius = 35
        photoButton.frame = CGRect(x: (view.bounds.width / 2) - 35,
                                   y: view.bounds.height - 140,
                                   width: 70,
                                   height: 70)
        photoButton.addTarget(self, action: #selector(takePhoto), for: .touchUpInside)
        view.addSubview(photoButton)

        // VIDEO BUTTON
        let videoButton = UIButton(type: .system)
        videoButton.setTitle("REC", for: .normal)
        videoButton.tintColor = .red
        videoButton.frame = CGRect(x: view.bounds.width - 80,
                                   y: view.bounds.height - 120,
                                   width: 60,
                                   height: 40)
        videoButton.addTarget(self, action: #selector(toggleVideo), for: .touchUpInside)
        view.addSubview(videoButton)

        // FLIP CAMERA
        let flipButton = UIButton(type: .system)
        flipButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        flipButton.tintColor = .white
        flipButton.frame = CGRect(x: view.bounds.width - 60, y: 60, width: 40, height: 40)
        flipButton.addTarget(self, action: #selector(flipCamera), for: .touchUpInside)
        view.addSubview(flipButton)
    }

    // MARK: - Actions

    @objc private func closeCamera() {
        dismiss(animated: true)
    }

    @objc private func takePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func toggleVideo() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        } else {
            let fileName = UUID().uuidString + ".mov"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)

            movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    @objc private func flipCamera() {
        session.beginConfiguration()

        if let currentInput = session.inputs.first {
            session.removeInput(currentInput)
        }

        let position: AVCaptureDevice.Position = .front

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: position),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        session.commitConfiguration()
    }

    // MARK: - Delegates

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {

        guard let data = photo.fileDataRepresentation() else { return }

        let fileName = UUID().uuidString + ".jpg"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        try? data.write(to: url)

        //dismiss(animated: true) {
            //self.upload(url: url, isVideo: false)
            self.onCapture?(url, false)
            //dismiss(animated: true)
            print("🔥 onCapture triggered with url:", url)
        //}
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {

        guard error == nil else { return }

        //dismiss(animated: true) {
            //self.upload(url: outputFileURL, isVideo: true)
            self.onCapture?(outputFileURL, true)
            //dismiss(animated: true)
        //}
    }

    // MARK: - Upload

    private func upload(url: URL, isVideo: Bool) {
        let model = NCUploadAssetsModel(
            tempAssets: [url],
            serverUrl: controller.currentServerUrl(),
            controller: controller
        )

        let view = NCUploadAssetsView(model: model)
        let vc = UIHostingController(rootView: view)

        controller.present(vc, animated: true)
    }
}



    
    
    // MARK: - Document Picker
    
    class NCDocumentPickerViewController: NSObject, UIDocumentPickerDelegate {
        
        let controller: NCMainTabBarController
        var viewController: UIViewController?
        var isViewerMedia: Bool
        
        init(controller: NCMainTabBarController, isViewerMedia: Bool, allowsMultipleSelection: Bool, viewController: UIViewController? = nil) {
            self.controller = controller
            self.isViewerMedia = isViewerMedia
            self.viewController = viewController
            super.init()
            
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
            documentPicker.modalPresentationStyle = .formSheet
            documentPicker.allowsMultipleSelection = allowsMultipleSelection
            documentPicker.delegate = self
            documentPicker.popoverPresentationController?.sourceView = controller.tabBar
            documentPicker.popoverPresentationController?.sourceRect = controller.tabBar.bounds
            
            controller.present(documentPicker, animated: true)
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            Task { @MainActor in
                // Her kan du implementere logikken til at gemme/copy filerne
                // f.eks. til NCUploadAssetsModel med fileUrls
            }
        }
        
        func copySecurityScopedResource(url: URL, urlOut: URL) -> URL? {
            try? FileManager.default.removeItem(at: urlOut)
            if url.startAccessingSecurityScopedResource() {
                do {
                    try FileManager.default.copyItem(at: url, to: urlOut)
                    url.stopAccessingSecurityScopedResource()
                    return urlOut
                } catch {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return nil
        }
    }



// MARK: - TLPhotosPicker Delegate
//extension NCPhotosPickerViewController: TLPhotosPickerViewControllerDelegate {
    // Denne metode er den mest pålidelige i TLPhotoPicker til at overtage kameratrykket
    //func handleNoCameraPermissions(picker: TLPhotosPickerViewController) {
        // Lad den stå tom eller vis en fejl
    //}

   // func selectedCameraCell(picker: TLPhotosPickerViewController) {
        // Tving dit view frem med det samme
      //  let cameraVC = NCPhotosPickerCameraViewController(controller: self.controller)
    //    picker.present(cameraVC, animated: true)
  //  }
//}



