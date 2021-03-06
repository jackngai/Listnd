//
//  SearchViewController.swift
//  Listnd
//
//  Created by Ramiro H. Lopez on 10/2/16.
//  Copyright © 2016 Ramiro H. Lopez. All rights reserved.
//

import UIKit
import CoreData
import SVProgressHUD
import JSSAlertView

// MARK: - Notification key
let artistImageDownloadNotification = "com.RhL.artistImageNotificationKey"

class SearchViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Properties
    var coreDataStack: CoreDataStack!
    var artists = [Artist]()
    var tap: UITapGestureRecognizer!
    var isSearching: Bool?
    var hasSearched = false
    var selectedRow: IndexPath?
    var alertView: JSSAlertView!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Change searchBar Cancel button font color to white
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes([NSForegroundColorAttributeName: UIColor.white], for: .normal)
        tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        searchBar.delegate = self
        alertView = JSSAlertView()
    }
}

// MARK: - Helper methods
extension SearchViewController {
    func configureCell(cell: UITableViewCell, indexPath: IndexPath) {
        guard let cell = cell as? SearchTableViewCell else { return }
        
        cell.searchImageVIew.image = UIImage(named: "thumbnailPlaceHolder")
        let artist = artists[indexPath.row]
        cell.searchLabel.text = artist.name
        
        if let data = artist.artistImage {
            let image = UIImage(data: data as Data)
            cell.searchImageVIew?.image = image
        } else {
            getAlbumImage(url: artist.imageURL, completetionHandlerForAlbumImage: { (data) in
                artist.artistImage = NSData(data: data as Data)
                DispatchQueue.main.async {
                    let image = UIImage(data: data as Data)
                    UIView.transition(with: cell.searchImageVIew, duration: 1, options: .transitionCrossDissolve, animations: { cell.searchImageVIew.image = image }, completion: nil)
                    // Post notification if cell was selected before image was downloaded
                    if self.selectedRow == indexPath {
                        NotificationCenter.default.post(name: Notification.Name(rawValue: artistImageDownloadNotification), object: self)
                    }
                }
            })
        }
    }
    
    func getAlbumImage(url: String?, completetionHandlerForAlbumImage: @escaping (_ imageData: NSData) -> Void) {
        if let urlString = url {
            SpotifyAPI.sharedInstance.getImage(urlString, completionHandlerForImage: { (result) in
                if let data = result {
                    completetionHandlerForAlbumImage(data as NSData)
                }
            })
        } else {
            let image = UIImage(named: "headerPlaceHolder")
            let data = UIImagePNGRepresentation(image!)!
            completetionHandlerForAlbumImage(data as NSData)
        }
    }
    
    // Enable UISearchBar cancel button after calling resignFirstResponder
    // from stackoverflow post http://stackoverflow.com/questions/27020452/enable-cancel-button-with-uisearchbar-in-ios8
    func enableCancelButton(searchBar: UISearchBar) {
        for view1 in searchBar.subviews {
            for view2 in view1.subviews {
                if view2.isKind(of: UIButton.self) {
                    let button = view2 as! UIButton
                    button.isEnabled = true
                    button.isUserInteractionEnabled = true
                }
            }
        }
    }
    
    func deleteObjects() {
        artists.removeAll()
        hasSearched = false
        tableView.reloadData()
    }
    
    func dismissKeyboard() {
        searchBar.endEditing(true)
        searchBar.resignFirstResponder()
    }
}

// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if hasSearched {
            deleteObjects()
        }
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if Reachability.sharedInstance.isConnectedToNetwork() == true {
            searchBar.resignFirstResponder()
            enableCancelButton(searchBar: searchBar)
            isSearching = true
            hasSearched = true
            SVProgressHUD.setDefaultStyle(.dark)
            SVProgressHUD.show(withStatus: "Loading...")
            SpotifyAPI.sharedInstance.searchArtist(searchBar.text!) { (success, results, errorMessage) in
                DispatchQueue.main.async {
                    self.isSearching = false
                    SVProgressHUD.dismiss()
                    if success {
                        if let searchResults = results {
                            self.artists = searchResults
                            self.tableView.reloadData()
                        } else {
                            self.alertView.danger(self, title: "Invalid result were returned", text: nil, buttonText: "Ok", cancelButtonText: nil, delay: nil, timeLeft: nil)
                        }
                    } else {
                        self.alertView.danger(self, title: errorMessage, text: nil, buttonText: "Ok", cancelButtonText: nil, delay: nil, timeLeft: nil)
                    }
                }
            }
        } else {
            alertView.danger(self, title: "Unable to search.\nNo internet connection detected", text: nil, buttonText: "Ok", cancelButtonText: nil, delay: nil, timeLeft: nil)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        if isSearching == true {
            SpotifyAPI.sharedInstance.cancelRequest()
        }
        searchBar.text = nil
        searchBar.resignFirstResponder()
        deleteObjects()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText == "" {
            deleteObjects()
            searchBar.becomeFirstResponder()
        }
    }
    
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        view.addGestureRecognizer(tap)
        return true
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        searchBar.setShowsCancelButton(false, animated: true)
        view.removeGestureRecognizer(tap)
        return true
    }
    
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

// MARK: - UITableViewDataSource
extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !hasSearched {
            return 0
        } else if artists.isEmpty {
            return 1
        } else {
            return artists.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if artists.count == 0 {
            return tableView.dequeueReusableCell(withIdentifier: "noResultCell", for: indexPath)
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "searchCell", for: indexPath)
            configureCell(cell: cell, indexPath: indexPath)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate
extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let detailVC = storyboard?.instantiateViewController(withIdentifier: "ArtistDetailViewController") as! ArtistDetailViewController
        
        let artist = artists[indexPath.row]
        selectedRow = indexPath
        detailVC.coreDataStack = coreDataStack
        detailVC.currentArtist = artist
        navigationController?.pushViewController(detailVC, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if artists.count == 0 {
            return nil
        } else {
            return indexPath
        }
    }
}

// MARK: - SVProgressHUD
extension SVProgressHUD {
    // Adjust position of progess hud after keyboard is dismissed
    func visibleKeyboardHeight() -> CFloat {
        return 0.0
    }
}
