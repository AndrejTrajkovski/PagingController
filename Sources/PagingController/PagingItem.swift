protocol PagingItem { }

struct AnyPagingItem {
    let value: Any
    init<T>(pagingItem: T) where T: PagingItem {
        self.value = pagingItem
    }
}

func unwrap<T: PagingItem>(_ pagingItems: [LoadingState<AnyPagingItem>]) -> [LoadingState<T>] {
    return pagingItems.map { ls in ls.map { $0.value as! T } }
}

func wrap<T: PagingItem>(_ pagingItems: [LoadingState<T>]) -> [LoadingState<AnyPagingItem>] {
    return pagingItems.map { ls in ls.map(AnyPagingItem.init(pagingItem:)) }
}
