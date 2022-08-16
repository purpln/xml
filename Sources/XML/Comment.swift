public struct Comment {
    public var value: String
    
    public init(value: String) {
        self.value = value
    }
}

extension Comment: ElementProtocol {
    public var string: String { value }
    public var transform: String { "<!--\(value)-->" }
}
