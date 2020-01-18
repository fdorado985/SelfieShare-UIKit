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

  // MARK: - View lifecycle apply_to_dictionaries: true

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
    let alertController = UIAlertController(title: "Connect to others", message: nil, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "Host a session", style: .default, handler: startHosting))
    alertController.addAction(UIAlertAction(title: "Join a session", style: .default, handler: joinSession))
    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alertController, animated: true)
  }

  func startHosting(action: UIAlertAction) {
    guard let mcSession = mcSession else { return }
    mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "dorado-selfieshare", discoveryInfo: nil, session: mcSession)
    mcAdvertiserAssistant?.start()
  }

  func joinSession(action: UIAlertAction) {
    guard let mcSession = mcSession else { return }
    let mcBrowser = MCBrowserViewController(serviceType: "dorado-selfieshare", session: mcSession)
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

  }

  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {

  }

  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {

  }

  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {

  }

  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {

  }
}

// MARK: - MCBrowserViewController delegate

extension ViewController: MCBrowserViewControllerDelegate {

  func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {

  }

  func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {

  }
}
