extension String: ElementProtocol {
    public var string: String { self }
    public var transform: String { self }
}
/*
extension String {
    var escaped: String {
        let dictionary: [String: String] = ["\"": "&quot;", "'": "&#39;", "&": "&amp;", "<": "&lt;", ">": "&gt;"]
        var value = self
        dictionary.forEach { item in
            value = value.replacingOccurrences(of: item.key, with: item.value)
        }
        return value
    }
}
*/
