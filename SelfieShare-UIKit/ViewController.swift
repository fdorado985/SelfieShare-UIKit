//
//  ViewController.swift
//  SelfieShare-UIKit
//
//  Created by Juan Francisco Dorado Torres on 17/01/20.
//  Copyright © 2020 Juan Francisco Dorado Torres. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class ViewController: UICollectionViewController {

  // MARK: - Properties

  var images = [UIImage]()
  var peerID = MCPeerID(displayName: UIDevice.current.name)
  var mcSession: MCSession?
  var mcAdvertiserAssistant: MCAdvertiserAssistant?

  // MARK: - View lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    title = "Selfie Share"
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(importPicture))
    navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showConnectionPrompt))

    mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
    mcSession?.delegate = self
  }

  // MARK: - Methods

  @objc func importPicture() {
    let picker = UIImagePickerController()
    picker.allowsEditing = true
    picker.delegate = self
    present(picker, animated: true)
  }

  @objc func showConnectionPrompt() {
    let alertController = UIAlertController(title: "Connect to others", message: nil, preferredStyle: .actionSheet)
    alertController.addAction(UIAlertAction(title: "Host a session", style: .default, handler: startHosting))
    alertController.addAction(UIAlertAction(title: "Join a session", style: .default, handler: joinSession))
    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alertController, animated: true)
  }

  func startHosting(action: UIAlertAction) {
    guard let mcSession = mcSession else { return }
    mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "jd-selfieshare", discoveryInfo: nil, session: mcSession)
    mcAdvertiserAssistant?.start()
  }

  func joinSession(action: UIAlertAction) {
    guard let mcSession = mcSession else { return }
    let mcBrowser = MCBrowserViewController(serviceType: "jd-selfieshare", session: mcSession)
    mcBrowser.delegate = self
    present(mcBrowser, animated: true)
  }
}

// MARK: - UINavigationController & UIImagePickerController delegates

extension ViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    guard let image = info[.editedImage] as? UIImage else { return }

    dismiss(animated: true)

    images.insert(image, at: 0)
    collectionView.reloadData()

    // send image data to peers
    guard let mcSession = mcSession else { return }
    if mcSession.connectedPeers.count > 0 {
      if let imageData = image.pngData() {
        do {
          try mcSession.send(imageData, toPeers: mcSession.connectedPeers, with: .reliable)
        } catch {
          let alertController = UIAlertController(title: "Send error!", message: error.localizedDescription, preferredStyle: .alert)
          alertController.addAction(UIAlertAction(title: "Ok", style: .default))
          present(alertController, animated: true)
        }
      }
    }
  }
}

// MARK: - UICollectionView delegates

extension ViewController {

  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return images.count
  }

  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageView", for: indexPath)

    if let imageView = cell.viewWithTag(1000) as? UIImageView {
      imageView.image = images[indexPath.item]
    }

    return cell
  }
}

// MARK: - MCSession delegate

extension ViewController: MCSessionDelegate {

  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    switch state {
    case .connected:
      print("Connected: \(peerID.displayName)")
    case .connecting:
      print("Connecting: \(peerID.displayName)")
    case .notConnected:
      print("Not Connected: \(peerID.displayName)")
    @unknown default:
      print("Unknown state received: \(peerID.displayName)")
    }
  }

  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if let image = UIImage(data: data) {
        self.images.insert(image, at: 0)
        self.collectionView.reloadData()
      }
    }
  }

  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }

  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }

  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
}

// MARK: - MCBrowserViewController delegate

extension ViewController: MCBrowserViewControllerDelegate {

  func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
    dismiss(animated: true)
  }

  func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
    dismiss(animated: true)
  }
}
