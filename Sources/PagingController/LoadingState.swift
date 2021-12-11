enum LoadingState<T> {
    case initial
    case loading
    case loaded(T)
    case error(Error)
}

extension LoadingState {

    func map<U>(_ transform:((T) -> U)) -> LoadingState<U> {
        switch self {
        case .initial:
            return .initial
        case .loading:
            return .loading
        case .loaded(let value):
            return .loaded(transform(value))
        case .error(let error):
            return .error(error)
        }
    }
}
