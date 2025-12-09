public protocol SliceUnsealing {
    func unsealSlice(_ slice: Slice, reason: String) -> Effect
}

