import UIKit

class PagingController: UIViewController, APIOffsetLoaderDelegate, APIOffsetLoaderDataSource {

    func numberOfItems(sectionIndex: Int) -> Int {
        itemsPerSection[sectionIndex]!.count
    }

    func isNotLoadingItems(sectionIndex: Int) -> Bool {
        itemsPerSection[sectionIndex]!.allSatisfy({
            switch $0 {
            case .loaded, .initial, .error:
                return true
            case .loading:
                return false
            }
        })
    }

    var itemsPerSection: [Int: [LoadingState<AnyPagingItem>]] = [:]
    var collectionView: UICollectionView!

    func getItems(sectionIndex: Int, offset: Int, completion: @escaping (Result<[AnyPagingItem], Error>) -> Void) {
        //override
    }

    func willLoadNewItems(in range: Range<Int>, sectionIndex: Int) {
        range.forEach { itemsPerSection[sectionIndex]!.insert(.loading, at: $0) }
        collectionView.performBatchUpdates {
            self.collectionView.insertItems(at: self.indexPaths(range, sectionIndex: sectionIndex))
        } completion: { _ in
            self.collectionView.reloadData()
        }
    }

    func willLoadItems(in range: Range<Int>, sectionIndex: Int) {
        range.forEach { itemsPerSection[sectionIndex]![$0] = .loading }
        collectionView.reloadSections(IndexSet.init(integer: sectionIndex))
    }

    func didGet(error: Error, in range: Range<Int>, sectionIndex: Int) {
        range.forEach { itemsPerSection[sectionIndex]![$0] = .error(error) }
        collectionView.reloadSections(IndexSet.init(integer: sectionIndex))
    }

    func didLoadNew(items: [AnyPagingItem], range: Range<Int>, sectionIndex: Int) {
        reloadAndDeleteCells(items, range, sectionIndex: sectionIndex)
    }

    func shouldHandleResult(sectionIndex: Int) -> Bool {
        return true
    }

    func shouldLoadNewItems(sectionIndex: Int) -> Bool {
        return isScrolledToBottom()
    }

    private func reloadAndDeleteCells(_ vids: ([AnyPagingItem]), _ range: Range<Int>, sectionIndex: Int) {
        let splitIndex = range.first! + vids.count
        let rangeToReload = range.first!..<splitIndex
        let rangeToDelete = splitIndex..<range.last! + 1
        setToLoaded(newVideos: vids, range: rangeToReload, sectionIndex: sectionIndex)
        //delete extra cells from last pagex
        if let last = rangeToDelete.last, itemsPerSection[sectionIndex]!.count > last {
            itemsPerSection[sectionIndex]!.removeSubrange(rangeToDelete)
        }
        if let last = rangeToDelete.last, itemsPerSection[sectionIndex]!.count > last {
            collectionView.performBatchUpdates {
                self.collectionView.deleteItems(at: self.indexPaths(rangeToDelete, sectionIndex: sectionIndex))
            } completion: { _ in
                self.collectionView.reloadData()
            }
        } else {
            self.collectionView.reloadData()
        }
    }

    private func setToLoaded(newVideos: [AnyPagingItem], range: Range<Int>, sectionIndex: Int) {
        if let last = range.last, itemsPerSection[sectionIndex]!.count > last {
            zip(range, newVideos).forEach {
                itemsPerSection[sectionIndex]![$0.0] = .loaded($0.1)
            }
        }
    }

    func indexPaths(_ range: Range<Int>, sectionIndex: Int) -> [IndexPath] {
        range.map { IndexPath.init(row: $0, section: sectionIndex) }
    }

    func isScrolledToBottom() -> Bool {
        let distanceFromBottom = collectionView.contentSize.height - collectionView.contentOffset.y
        return distanceFromBottom < collectionView.frame.size.height
    }

    @objc(numberOfSectionsInCollectionView:) func numberOfSections(in collectionView: UICollectionView) -> Int {
        return itemsPerSection.count
    }

    @objc func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numberOfItems(sectionIndex: section)
    }
}
