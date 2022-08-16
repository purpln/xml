public struct Element {
    public var tag: String
    public var attributes: [String: String]
    public var elements: [ElementProtocol]
    
    public init(tag: String,  attributes: [String: String], elements: [ElementProtocol]) {
        self.tag = tag
        self.attributes = attributes
        self.elements = elements
    }
}

extension Element: ElementProtocol {
    public var string: String { elements.map(\.string).joined() }
    public var transform: String {
        "<\(tag)\(attributed)>\(elements.map(\.transform).joined())</\(tag)>"
    }
    private var attributed: String {
        guard !attributes.isEmpty else { return "" }
        return " " + attributes.map { item in
            "\(item.key)=\"\(item.value)\""
        }.joined(separator: " ")
    }
}
