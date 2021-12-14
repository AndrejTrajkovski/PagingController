import UIKit
import PagingController

class SearchResultsViewController: PagingController, UICollectionViewDataSource, UICollectionViewDelegate, UISearchResultsUpdating {

    let queryLimit = 24

    enum Section: Int, CaseIterable {
        case video = 0
        case channel = 1
    }

    var searchBarText: String?
    var currentSearchText = ""

    var videos: [LoadingState<Video>] {
        get {
            unwrap(itemsPerSection[Section.video.rawValue]!)
        }
        set {
            itemsPerSection[Section.video.rawValue] = wrap(newValue)
        }
    }

    var channels: [LoadingState<Channel>] {
        get {
            unwrap(itemsPerSection[Section.channel.rawValue]!)
        }
        set {
            itemsPerSection[Section.channel.rawValue] = wrap(newValue)
        }
    }

    var videoLoader: APIOffsetLoader<Video>!
    var channelLoader: APIOffsetLoader<Channel>!

    private var searchVideosProvider: SearchVideosProviding {
        return APISession()
    }

    //MARK: - Setup
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        collectionView = UICollectionView.init(frame: .zero, collectionViewLayout: createLayout())
        collectionView.register(UINib.init(nibName: HomeCollectionViewCell.nibName, bundle: nil), forCellWithReuseIdentifier: HomeCollectionViewCell.cellId)
        collectionView.register(UINib.init(nibName: ChannelCollectionViewCell.nibName, bundle: nil), forCellWithReuseIdentifier: ChannelCollectionViewCell.id)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.clipsToBounds = false
        collectionView.remembersLastFocusedIndexPath = true
        videoLoader = APIOffsetLoader.init(sectionIndex: Section.video.rawValue,
                                           queryLimit: queryLimit)
        channelLoader = APIOffsetLoader.init(sectionIndex: Section.channel.rawValue,
                                             queryLimit: queryLimit)
        videos = []
        channels = []
        videoLoader.delegate = self
        videoLoader.dataSource = self
        channelLoader.delegate = self
        channelLoader.dataSource = self
    }

    override func loadView() {
        let myView = UIView()
        myView.addSubview(collectionView)
        myView.backgroundColor = .clear
        self.view = myView
    }

    override func viewWillLayoutSubviews() {
        collectionView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height)
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize = HomeCollectionViewCell.mySize
    }

    // MARK: UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section) {
        case .video:
            let videoCell = collectionView.dequeueReusableCell(withReuseIdentifier: HomeCollectionViewCell.cellId, for: indexPath) as! HomeCollectionViewCell
            videoCell.loadingState = videos[indexPath.row]
            if indexPath.row == videos.count - 1 {
                videoLoader.fetchNextPage()
            }
            return videoCell
        case .channel:
            let channelCell = collectionView.dequeueReusableCell(withReuseIdentifier: ChannelCollectionViewCell.id, for: indexPath) as! ChannelCollectionViewCell
            channelCell.loadingState = channels[indexPath.row]
            if indexPath.row == channels.count - 1 {
                channelLoader.fetchNextPage()
            }
            return channelCell
        case .none:
            fatalError()
        }

    }

    // MARK: UISearchResultsUpdating

    func updateSearchResults(for searchController: UISearchController) {
        searchBarText = searchController.searchBar.text
        guard let text = searchController.searchBar.text, text.count > 2 else {
            videos = []
            channels = []
            videoLoader.reset()
            channelLoader.reset()
            currentSearchText = ""
            collectionView.reloadData()
            return
        }
        guard currentSearchText != text else { return }
        Debounce.input(text, delay: 0.5, current: searchController.searchBar.text ?? "") { [weak self] in
            self?.trySearch(text: $0)
        }
    }

    func trySearch(text: String) {
        currentSearchText = text
        videos = []
        channels = []
        videoLoader.reset()
        channelLoader.reset()
        collectionView.reloadData()
        videoLoader.fetchNextPage()
        channelLoader.fetchNextPage()
    }

    override func getItems(sectionIndex: Int, offset: Int, completion: @escaping (Result<[AnyPagingItem], Error>) -> Void) {
        switch Section.init(rawValue: sectionIndex) {
        case .none:
            break
        case .channel:
            searchVideosProvider.searchChannels(query: currentSearchText,
                                                offset: offset,
                                                completion: { result in
                completion(result.map { channels in
                    channels.map(AnyPagingItem.init(pagingItem:)) })}
            )
        case .video:
            searchVideosProvider.searchVideos(query: currentSearchText,
                                              offset: offset,
                                              completion: { result in
                completion(result.map { videos in
                    videos.map(AnyPagingItem.init(pagingItem:)) })}
            )
        }
    }

    override func shouldHandleResult(sectionIndex: Int) -> Bool {
        currentSearchText == searchBarText
    }

    override func shouldLoadNewItems(sectionIndex: Int) -> Bool {
        return isScrolledToTrailingEdge()
    }

    func isScrolledToTrailingEdge() -> Bool {
        let distanceFromTrailing = collectionView.contentSize.width - collectionView.contentOffset.x
        return distanceFromTrailing < collectionView.frame.size.width
    }
}

// MARK: - UICollectionViewDelegateFlowLayout methods
extension SearchResultsViewController: UICollectionViewDelegateFlowLayout {

}

// MARK: - Layout
extension SearchResultsViewController {
    func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { (sectionIndex: Int,
            layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            guard let section = Section.init(rawValue: sectionIndex) else { return nil }
            let sectionLayout = NSCollectionLayoutSection(group: self.createGroupLayout(section))
            sectionLayout.orthogonalScrollingBehavior = .continuous
            sectionLayout.interGroupSpacing = 32
            sectionLayout.boundarySupplementaryItems = [self.titleHeaderSupplementary()]
            return sectionLayout
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 0

        let layout = UICollectionViewCompositionalLayout(sectionProvider: sectionProvider, configuration: config)
        return layout
    }

    func createGroupLayout(_ section: Section) -> NSCollectionLayoutGroup {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                             heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize: NSCollectionLayoutSize
        let cellSize = cellSize(section)
        groupSize = NSCollectionLayoutSize(widthDimension: .absolute(cellSize.width),
                                           heightDimension: .absolute(cellSize.height))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        return group
    }

    func titleHeaderSupplementary() -> NSCollectionLayoutBoundarySupplementaryItem {
        let titleSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(90))
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: titleSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top)
    }

    func cellSize(_ section: Section) -> CGSize {
        switch section {
        case .video:
             return HomeCollectionViewCell.mySize
        case .channel:
            return ChannelCollectionViewCell.mySize
        }
    }
}
