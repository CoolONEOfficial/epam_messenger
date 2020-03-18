//
//  ChatTableView.swift
//  epam_messenger
//
//  Created by Nickolay Truhin on 15.03.2020.
//

import UIKit
import Firebase

class ChatTableView: UITableView {
    
    // MARK: - Vars
    
    public var chatDataSource: ChatTableViewDataSource {
        return dataSource as! ChatTableViewDataSource
    }
    
    internal var lastSectionsChange: (type: ChatTableViewDataSource.ChangeType, change: IndexSet)?
    
    // MARK: - Override TableView
    
    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        let transformedPaths = chatDataSource.transformIndexPathList(indexPaths)
        super.reloadRows(at: transformedPaths, with: animation)
    }
    
    override func insertRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        let transformedPaths = chatDataSource.transformIndexPathList(indexPaths)
        let singlePath = transformedPaths.count == 1
        let firstPath = transformedPaths.first!
        
        if let change = lastSectionsChange,
            change.type == .insert,
            !change.change.isEmpty {
            super.insertSections(change.change, with: .fade)
            lastSectionsChange = nil
        }
        
        super.insertRows(
            at: transformedPaths,
            with: singlePath
                ? .bottom
                : animation
        )
        
        if singlePath,
            firstPath.row > 0 {
            let prevPath = IndexPath(
                row: firstPath.row - 1,
                section: firstPath.section
            )
            
            let prevMessage = chatDataSource.messageAt(prevPath),
            currentMessage = chatDataSource.messageAt(firstPath)
            
            if MessageModel.checkMerge(left: prevMessage, right: currentMessage) {
                reloadRows(
                    at: [prevPath],
                    with: .fade
                )
            }
        }
    }
    
    override func deleteRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        let transformedPaths = chatDataSource.transformIndexPathList(indexPaths)
        
        if let change = lastSectionsChange,
            change.type == .delete,
            !change.change.isEmpty {
            super.deleteSections(change.change, with: .automatic)
            lastSectionsChange = nil
        }
        
        super.deleteRows(at: transformedPaths, with: .automatic)
    }
    
    override func moveRow(at indexPath: IndexPath, to newIndexPath: IndexPath) {
        fatalError() // messages doesnt move
    }
    
    // MARK: Custom bind
    
    func bind(toFirestoreQuery query: Query, populateCell: @escaping (UITableView, IndexPath) -> UITableViewCell) -> ChatTableViewDataSource {
        let dataSource = ChatTableViewDataSource(query: query) { tableView, indexPath, _ in
            return populateCell(tableView, indexPath)
        }
        dataSource.bind(to: self)
        return dataSource
    }
    
    // MARK: - Helpers
    
    func scrollToBottom() {
        guard !chatDataSource.messageItems.isEmpty else {
            return
        }
        
        let lastIndex = chatDataSource.messageItems.count - 1
        let lastItem = chatDataSource.messageItems[lastIndex]
        scrollToRow(at: IndexPath(row: lastItem.value.count - 1, section: lastIndex), at: .none, animated: true)
    }
}