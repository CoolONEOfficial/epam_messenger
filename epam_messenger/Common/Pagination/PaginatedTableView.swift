//
//  PaginatedTableView.swift
//  epam_messenger
//
//  Created by Nickolay Truhin on 08.04.2020.
//

import UIKit
import FirebaseFirestore

protocol PaginatedTableViewDelegate: UITableViewDelegate {
    func didUpdateElements()
}

extension PaginatedTableViewDelegate {
    func didUpdateElements() {}
}

private let queryCount = 40
private let paginationQueryCount = 30
private let paginationTriggerAreaHeight: CGFloat = 250
private let paginationCellsOffset = 5

enum InitialPosition {
    case top
    case bottom
}

class PaginatedTableView<ElementT: Equatable>: UITableView, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Vars
    
    var dataAtStart = false
    var dataAtEnd = false
    
    var flattenData: [ElementT] = []
    
    weak var paginatedDelegate: PaginatedTableViewDelegate?
    
    var baseQuery: FireQuery!
    var initialPosition: InitialPosition!
    var cellForRowAt: ((IndexPath) -> UITableViewCell)!
    var querySideTransform: ((ElementT) -> Any)!
    var fromSnapshot: ((_ snapshot: DocumentSnapshot) -> ElementT?)!
    
    var paginationLock = false
    var lastContentOffset: CGFloat = 0
    
    var listener: ListenerRegistration! {
        didSet {
            oldValue?.remove()
        }
    }
    
    // MARK: - Init
    
    init(
        baseQuery: FireQuery,
        initialPosition: InitialPosition,
        cellForRowAt: @escaping ((IndexPath) -> UITableViewCell),
        querySideTransform: @escaping ((ElementT) -> Any),
        fromSnapshot: @escaping ((_ snapshot: DocumentSnapshot) -> ElementT?)
    ) {
        super.init(frame: .init(), style: .plain)
        self.baseQuery = baseQuery
        self.initialPosition = initialPosition
        self.cellForRowAt = cellForRowAt
        self.querySideTransform = querySideTransform
        self.fromSnapshot = fromSnapshot
        
        commonInit()
        
        switch initialPosition {
        case .top:
            loadAtStart { self.updateElements(
                $0,
                unlockPagination: $0?.count == queryCount
            ) }
        case .bottom:
            paginationLock = true
            loadAtEnd {
                self.updateElements(
                    $0,
                    unlockPagination: $0?.count == queryCount
                )
                self.scrollToBottom(animated: true)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        delegate = self
        dataSource = self
    }
    
    // MARK: - UITableViewDelegate
        
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        paginatedDelegate?.scrollViewDidScroll?(scrollView)
        
        didScroll(scrollView)
    }
    
    private func didScroll(
        _ scrollView: UIScrollView,
        afterUnlock: Bool = false
    ) {
        if let visiblePathList = indexPathsForVisibleRows,
            !paginationLock {
            if !dataAtStart,
                scrollView.contentOffset.y + safeAreaInsets.top < paginationTriggerAreaHeight,
                lastContentOffset >= scrollView.contentOffset.y,
                let lastVisiblePath = visiblePathList.last {
                paginationLock = true

                let flattened = flattenData

                if let visibleIndex = flattened.firstIndex(where: { $0 == elementAt(lastVisiblePath) }) {
                    dataAtStart = false
                    dataAtEnd = false

                    let endMessageIndex: Int
                    let visibleCellCount: Int = visiblePathList.count
                    if visibleIndex + paginationCellsOffset < flattened.count {
                        endMessageIndex = visibleIndex + paginationCellsOffset
                    } else {
                        endMessageIndex = flattened.count - 1
                    }
                    listener = baseQuery
                        .end(at: [querySideTransform(flattened[endMessageIndex])])
                        .limit(toLast: paginationQueryCount + visibleCellCount)
                        .addSnapshotListener(snapshotListener { elements in
                            if elements?.count == paginationQueryCount + visibleCellCount {
                                self.updateElements(
                                    elements,
                                    scrollView: afterUnlock ? nil : scrollView
                                )
                            } else {
                                self.loadAtStart()
                            }
                        })
                }
            } else if !dataAtEnd,
                scrollView.contentSize.height
                    - scrollView.contentOffset.y
                    - scrollView.bounds.height
                    + scrollView.contentInset.bottom
                    + safeAreaInsets.bottom < paginationTriggerAreaHeight,
                lastContentOffset <= scrollView.contentOffset.y,
                let firstVisiblePath = visiblePathList.first {
                paginationLock = true

                let flattened = flattenData

                if let visibleIndex = flattened.firstIndex(where: { $0 == elementAt(firstVisiblePath) }) {
                    dataAtStart = false
                    dataAtEnd = false

                    let startMessageIndex: Int
                    let visibleCellCount: Int = visiblePathList.count
                    if visibleIndex - paginationCellsOffset >= 0 {
                        startMessageIndex = visibleIndex - paginationCellsOffset
                    } else {
                        startMessageIndex = 0
                    }
                    listener = baseQuery
                        .start(at: [querySideTransform(flattened[startMessageIndex])])
                        .limit(to: paginationQueryCount + visibleCellCount)
                        .addSnapshotListener(snapshotListener { elements in
                            if elements?.count == paginationQueryCount + visibleCellCount {
                                self.updateElements(
                                    elements,
                                    scrollView: afterUnlock ? nil : scrollView
                                )
                            } else {
                                self.loadAtEnd()
                            }
                        })
                }
            }
            
            lastContentOffset = scrollView.contentOffset.y
        }
    }
    
    private func snapshotListener(
        completion: (([ElementT]?) -> Void)? = nil
    ) -> ((QuerySnapshot?, Error?) -> Void) {
        { snapshot, err in
            guard err == nil else {
                debugPrint("Error while get snapshot")
                return
            }
            
            let completion = completion ?? self.updateElements
            if let snapshot = snapshot {
                completion(snapshot.documents.map { self.fromSnapshot($0)! })
            } else {
                completion(nil)
            }
        }
    }
    
    func updateElements(elements: [ElementT]?) {
        updateElements(elements)
    }
    
    func updateData(_ elements: [ElementT]) -> Any {
        let oldData = self.flattenData
        self.flattenData = elements
        return oldData
    }
    
    func animateChanges(_ oldData: Any) {
        animateRowChanges(
            oldData: oldData as! [ElementT],
            newData: self.flattenData,
            deletionAnimation: .fade,
            insertionAnimation: .fade
        )
    }
    
    func updateElements(
        _ elements: [ElementT]?,
        animate: Bool = true,
        scrollView: UIScrollView? = nil,
        unlockPagination: Bool = true
    ) {
        if let elements = elements {
            let oldData = updateData(elements)

            if animate {
                CATransaction.begin()
                CATransaction.setCompletionBlock {
                    if unlockPagination {
                        self.unlockPagination(scrollView)
                    }
                }
                animateChanges(oldData)
                CATransaction.commit()
            } else {
                reloadData()
                if unlockPagination {
                    self.unlockPagination(scrollView)
                }
            }
            
            paginatedDelegate?.didUpdateElements()
        }
    }
    
    func loadAtStart(completion: (([ElementT]?) -> Void)? = nil) {
        dataAtStart = true
        dataAtEnd = false
        
        listener = baseQuery.limit(to: queryCount)
            .addSnapshotListener(
                snapshotListener(
                    completion: completion ?? updateElements
            ))
    }
    
    func loadAtEnd(completion: (([ElementT]?) -> Void)? = nil) {
        dataAtStart = false
        dataAtEnd = true
        
        listener = baseQuery.limit(toLast: queryCount)
            .addSnapshotListener(
                snapshotListener(
                    completion: completion ?? updateElements
            ))
    }
    
    func unlockPagination(_ scrollView: UIScrollView? = nil) {
        paginationLock = false
        
        if let scrollView = scrollView {
            didScroll(scrollView, afterUnlock: true)
        }
    }
    
    // MARK: - UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        flattenData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        cellForRowAt(indexPath)
    }
    
    // MARK: - Helpers
    
    func scrollToBottom(animated: Bool) {
        guard !flattenData.isEmpty else {
            return
        }
        
        let lastIndex = flattenData.count - 1
        scrollToRow(
            at: IndexPath(
                row: lastIndex,
                section: 0
            ),
            at: .none,
            animated: animated
        )
    }
    
    public func elementAt(_ indexPath: IndexPath) -> ElementT {
        return elementAt(indexPath.row)
    }
    
    public func elementAt(_ index: Int) -> ElementT {
        return flattenData[index]
    }
    
    // MARK: - PaginatedDelegate
        
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        paginatedDelegate?.scrollViewWillBeginDragging?(scrollView)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        paginatedDelegate?.tableView?(tableView, didSelectRowAt: indexPath)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        paginatedDelegate?.tableView?(tableView, didDeselectRowAt: indexPath)
    }
    
    func tableView(_ tableView: UITableView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        paginatedDelegate?.tableView?(tableView, shouldBeginMultipleSelectionInteractionAt: indexPath) ?? false
    }
    
    func tableView(_ tableView: UITableView, didBeginMultipleSelectionInteractionAt indexPath: IndexPath) {
        paginatedDelegate?.tableView?(tableView, didBeginMultipleSelectionInteractionAt: indexPath)
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        paginatedDelegate?.tableView?(tableView, contextMenuConfigurationForRowAt: indexPath, point: point)
    }
    
    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        paginatedDelegate?.tableView?(tableView, willPerformPreviewActionForMenuWith: configuration, animator: animator)
    }
}
