protocol APIOffsetLoaderDelegate: AnyObject {
    func willLoadNewItems(in range: Range<Int>, sectionIndex: Int)
    func willLoadItems(in range: Range<Int>, sectionIndex: Int)
    func didGet(error: Error, in range: Range<Int>, sectionIndex: Int)
    func didLoadNew(items: [AnyPagingItem], range: Range<Int>, sectionIndex: Int)
    func shouldHandleResult(sectionIndex: Int) -> Bool
    func shouldLoadNewItems(sectionIndex: Int) -> Bool
    func getItems(sectionIndex: Int, offset: Int, completion: @escaping (Result<[AnyPagingItem], Error>) -> Void)
}

protocol APIOffsetLoaderDataSource: AnyObject {
    func numberOfItems(sectionIndex: Int) -> Int
    func isNotLoadingItems(sectionIndex: Int) -> Bool
}

class APIOffsetLoader<T: PagingItem> {

    var offset: Int = 0
    let queryLimit: Int

    init(sectionIndex: Int, queryLimit: Int) {
        self.sectionIndex = sectionIndex
        self.queryLimit = queryLimit
    }

    var sectionIndex: Int
    private var shouldLoadNewPage = true
    weak var delegate: APIOffsetLoaderDelegate?
    weak var dataSource: APIOffsetLoaderDataSource?

    func reset() {
        shouldLoadNewPage = true
        offset = 0
    }

    func fetchNextPage() {

        guard let dataSource = dataSource,
              dataSource.isNotLoadingItems(sectionIndex: sectionIndex),
              shouldLoadNewPage else { return }

        let numberOfVideos = dataSource.numberOfItems(sectionIndex: sectionIndex)
        let lastElementIndex = numberOfVideos + queryLimit
        let range = (numberOfVideos..<lastElementIndex)
        if numberOfVideos <= lastElementIndex {
            delegate?.willLoadNewItems(in: range, sectionIndex: sectionIndex)
        } else {
            delegate?.willLoadItems(in: range, sectionIndex: sectionIndex)
        }
        delegate?.getItems(sectionIndex: sectionIndex,
                           offset: offset,
                           completion: { self.handle(result: $0, range: range) })
        offset = offset + lastElementIndex
    }

    private func handle(result: Result<[AnyPagingItem], Error>, range: Range<Int>) {
        guard let delegate = delegate,
              delegate.shouldHandleResult(sectionIndex: sectionIndex) else { return }
        switch result {
        case .success(let items):
            delegate.didLoadNew(items: items, range: range, sectionIndex: sectionIndex)
            if items.count < queryLimit {
                shouldLoadNewPage = false
            } else if delegate.shouldLoadNewItems(sectionIndex: sectionIndex) {
                fetchNextPage()
            }
        case .failure(let error):
            delegate.didGet(error: error, in: range, sectionIndex: sectionIndex)
            fetchNextPage()
        }
    }
}
