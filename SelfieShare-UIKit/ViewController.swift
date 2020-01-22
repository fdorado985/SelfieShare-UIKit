//
//  ViewController.swift
//  SelfieShare-UIKit
//
//  Created by Juan Francisco Dorado Torres on 17/01/20.
//  Copyright © 2020 Juan Francisco Dorado Torres. All rights reserved.
//

import UIKit
import MultipeerConnectivity

enum AlertType {
  case info
  case connection
}

class ViewController: UICollectionViewController {

  // MARK: - Properties

  var images = [UIImage]()
  var peerID = MCPeerID(displayName: UIDevice.current.name)
  var mcSession: MCSession?
  var mcAdvertiserAssistant: MCNearbyServiceAdvertiser?

  // MARK: - View lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    title = "Selfie Share"
    navigationItem.rightBarButtonItems = [
      UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(importPicture)),
      UIBarButtonItem(image: UIImage(systemName: "bubble.left"), style: .plain, target: self, action: #selector(sendMessage))
    ]
    navigationItem.leftBarButtonItems = [
      UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showConnectionPrompt)),
      UIBarButtonItem(image: UIImage(systemName: "antenna.radiowaves.left.and.right"), style: .plain, target: self, action: #selector(showConnectedUsers))
    ]

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
    showAlert(title: "Connect to others", message: nil, for: .connection)
  }

  @objc func showConnectedUsers() {
    guard let mcSession = mcSession else { return }
    if mcSession.connectedPeers.count == 0 {
      showAlert(title: "Connections", message: "There are any users connected", for: .info)
    } else {
      let users = mcSession.connectedPeers.map { $0.displayName }.joined(separator: ", ")
      showAlert(title: "Connections", message: users, for: .info)
    }
  }

  @objc func sendMessage() {
    let alertController = UIAlertController(title: "Send a message", message: nil, preferredStyle: .alert)
    alertController.addTextField()
    alertController.addAction(
      UIAlertAction(
        title: "Send",
        style: .default,
        handler: { [weak self] _ in
          guard let self = self else { return }
          guard let message = alertController.textFields?.first?.text else { return }

          // send image data to peers
          guard let mcSession = self.mcSession else { return }
          if mcSession.connectedPeers.count > 0 {
            let stringData = Data(message.utf8)
            do {
              try mcSession.send(stringData, toPeers: mcSession.connectedPeers, with: .reliable)
            } catch {
              self.showAlert(title: "Send error!", message: error.localizedDescription, for: .info)
            }
          }
        }
      )
    )
    present(alertController, animated: true)
  }

  func showAlert(title: String, message: String?, for type: AlertType) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let alertController = UIAlertController(title: title, message: message, preferredStyle: type == .info ? .alert : .actionSheet)
      if type == .connection {
        alertController.addAction(UIAlertAction(title: "Host a session", style: .default, handler: self.startHosting))
        alertController.addAction(UIAlertAction(title: "Join a session", style: .default, handler: self.joinSession))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
      } else {
        alertController.addAction(UIAlertAction(title: "Ok", style: .default))
      }
      self.present(alertController, animated: true)
    }
  }

  func startHosting(action: UIAlertAction) {
    mcAdvertiserAssistant = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: "jd-selfieshare")
    mcAdvertiserAssistant?.delegate = self
    mcAdvertiserAssistant?.startAdvertisingPeer()
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
          showAlert(title: "Send error!", message: error.localizedDescription, for: .info)
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
      showAlert(title: "Disconnected", message: "\(peerID.displayName) has disconnected", for: .info)
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
      } else {
        let stringMessage = String(decoding: data, as: UTF8.self)
        self.showAlert(title: "\(peerID.displayName) message", message: stringMessage, for: .info)
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

// MARK: - MCNearbyServiceAdvertiser delegate

extension ViewController: MCNearbyServiceAdvertiserDelegate {

  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    invitationHandler(true, mcSession)
  }
}
