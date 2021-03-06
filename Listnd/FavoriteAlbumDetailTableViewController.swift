//
//  FavoriteAlbumDetailTableViewController.swift
//  Listnd
//
//  Created by Ramiro H. Lopez on 10/19/16.
//  Copyright © 2016 Ramiro H. Lopez. All rights reserved.
//

import UIKit
import CoreData
import JSSAlertView
import SwipeCellKit

protocol AlbumListenedDelegate: class {
    func albumListenedChange()
}

class FavoriteAlbumDetailTableViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Properties
    var coreDataStack: CoreDataStack!
    var currentAlbum: Album!
    weak var albumListenedDelegate: AlbumListenedDelegate?
    var alertView: JSSAlertView!
    
    // MARK: - View life cycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        alertView = JSSAlertView()
        if let headerView = Bundle.main.loadNibNamed("HeaderView", owner: self, options: nil)?.first as? HeaderView {
            headerView.configureView(name: currentAlbum.name, imageData: currentAlbum.albumImage as? Data, hideButton: true)
            headerView.backButton.addTarget(self, action: #selector(backButtonPressed(sender:)), for: .touchUpInside)
            tableView.addSubview(headerView)
            fetchTracks()
        } else {
            alertView.danger(self, title: "Unable to load album detail", text: nil, buttonText: "Ok", cancelButtonText: nil, delay: nil, timeLeft: nil)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tracksListened()
        coreDataStack.saveContext()
    }
    
    // MARK: - NSFetchedResultsController
    lazy var fetchedResultsController: NSFetchedResultsController<Track> = {
        let fetchRequest: NSFetchRequest<Track> = Track.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Track.album.id), self.currentAlbum.id)
        let sortDescriptor = NSSortDescriptor(key: #keyPath(Track.trackNumber), ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        let fetchedResultsController = NSFetchedResultsController<Track>(fetchRequest: fetchRequest, managedObjectContext: self.coreDataStack.managedContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        return fetchedResultsController
    }()
}

// MARK: - Helper methods
extension FavoriteAlbumDetailTableViewController {
    func fetchTracks() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            alertView.danger(self, title: "Unable to retrieve track information", text: nil, buttonText: "Ok", cancelButtonText: nil, delay: nil, timeLeft: nil)
        }
    }
    
    func tracksListened() {
        var listenedCount = 0
        let tracks = fetchedResultsController.fetchedObjects!
        for track in tracks {
            if track.listened {
                listenedCount += 1
            }
        }
        currentAlbum.listenedCount = Int16(listenedCount)
        
        if listenedCount == fetchedResultsController.fetchedObjects?.count {
            if !currentAlbum.listened {
                currentAlbum.listened = true
                albumListenedDelegate?.albumListenedChange()
            }
        } else {
            if currentAlbum.listened {
                currentAlbum.listened = false
                albumListenedDelegate?.albumListenedChange()
            }
        }
    }
    
    func configureCell(cell: UITableViewCell, indexPath: IndexPath) {
        guard let cell = cell as? FavoriteAlbumDetailTableViewcCell else { return }
        
        cell.delegate = self
        
        let track = fetchedResultsController.object(at: indexPath)
        cell.trackNameLabel.text = track.name
        
        let trackNumberText = track.trackNumber < 10 ? " \(track.trackNumber)." : "\(track.trackNumber)."
        cell.trackNumber.text = trackNumberText
        if track.listened {
            cell.accessoryType = UITableViewCellAccessoryType.checkmark
        } else {
            cell.accessoryType = UITableViewCellAccessoryType.none
        }
    }
    
    func deleteAction(indexPath: IndexPath) {
        let trackToDelete = fetchedResultsController.object(at: indexPath)
        coreDataStack.managedContext.delete(trackToDelete)
        coreDataStack.saveContext()
    }
    
    func listenedAction(indexPath: IndexPath)  {
        let track = fetchedResultsController.object(at: indexPath)
        track.listened = !track.listened
        coreDataStack.saveContext()
    }
    
    func openSpotifyAction(indexPath: IndexPath) {
        let track = fetchedResultsController.object(at: indexPath)
        let uriString = URL(string: track.uri)!
        if UIApplication.shared.canOpenURL(uriString) {
            UIApplication.shared.open(uriString, options: [:], completionHandler: nil)
        } else {
            let alertController = UIAlertController(title: "Attention", message: "Spotify application was not found.\nWould you like to install it?", preferredStyle: .alert)
            let installAction = UIAlertAction(title: "Install", style: .default, handler: { (action) in
                if let url = URL(string: "https://itunes.apple.com/us/app/spotify-music/id324684580?mt=8") {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            })
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(installAction)
            alertController.addAction(cancelAction)
            present(alertController, animated: true, completion: nil)
        }
    }
    
    func backButtonPressed(sender: UIButton) {
        _ = navigationController?.popViewController(animated: true)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension FavoriteAlbumDetailTableViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - UITableViewDataSource
extension FavoriteAlbumDetailTableViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "trackCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        configureCell(cell: cell, indexPath: indexPath)
        return cell
    }
}

// MARK: - SwipeTableViewCellDelegate
extension FavoriteAlbumDetailTableViewController: SwipeTableViewCellDelegate {
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> [SwipeAction] {
        if orientation == .right {
            let deleteAction = SwipeAction(style: .destructive, title: "Delete") { (action, indexPath) in
                self.deleteAction(indexPath: indexPath)
            }
            
            let spotifyAction = SwipeAction(style: .default, title: "Spotify", handler: { (action, indexPath) in
                self.openSpotifyAction(indexPath: indexPath)
            })
            
            spotifyAction.backgroundColor = UIColor(red: 29/255, green: 185/255, blue: 84/255, alpha: 1)
            return [deleteAction, spotifyAction]
        } else {
            let listndAction = SwipeAction(style: .default, title: "Listnd!", handler: { (action, indexPath) in
               self.listenedAction(indexPath: indexPath)
            })
            
            listndAction.backgroundColor = UIColor(red: 0/255, green: 52/255, blue: 96/255, alpha: 1)
            
            return [listndAction]
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsOptionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeTableOptions {
        var options = SwipeTableOptions()
        options.expansionStyle = .selection
        options.transitionStyle = .border
        return options
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension FavoriteAlbumDetailTableViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .automatic)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .automatic)
        case .update:
            let cell = tableView.cellForRow(at: indexPath!) as! FavoriteAlbumDetailTableViewcCell
            configureCell(cell: cell, indexPath: indexPath!)
            break
        case .move:
            tableView.deleteRows(at: [indexPath!], with: .automatic)
            tableView.insertRows(at: [newIndexPath!], with: .automatic)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
