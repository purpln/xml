#if os(Linux)
import FoundationXML
#else
import Foundation
#endif

public class Parser: NSObject {
#if os(Linux)
    typealias FoundationXMLParser = FoundationXML.XMLParser
#else
    typealias FoundationXMLParser = Foundation.XMLParser
#endif
    
    private let xmlParser: FoundationXMLParser
    
    private var openned: [String] = []
    private var level: Int { openned.count }
    private var previous: Int = 0
    private var count: [Int:[ElementProtocol]] = [:]
    private var attributes: [Int:[String: String]] = [:]
    
    public var document: [ElementProtocol] {
        guard xmlParser.parse() else { return [] }
        guard let document = count[0] else { return [] }
        return document
    }
    
    public init(data: Data) {
        xmlParser = FoundationXMLParser(data: data)
        super.init()
        xmlParser.delegate = self
    }
}

extension Parser: XMLParserDelegate {
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        openned.append(elementName)
        attributes[level] = attributeDict
        if count[level] == nil {
            count[level] = []
            previous = level
        }
    }
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        openned.removeLast()
        guard level < previous, let array = count[previous] else { return }
        if previous != 1 {
            count[previous] = nil
        }
        let element = Element(tag: elementName, attributes: attributes[previous] ?? [:], elements: array)
        count[level]?.append(element)
        previous = level
        guard previous == 0, let elements = count[1] else { return }
        count[0] = [Element(tag: elementName, attributes: attributes[1] ?? [:], elements: elements)]
    }
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        append(string)
    }
    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let string = String(data: CDATABlock, encoding: .utf8) else { return }
        append(string)
    }
    public func parser(_ parser: XMLParser, foundComment comment: String) {
        let element = Comment(value: comment)
        count[level]?.append(element)
    }
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        
    }
    private func append(_ string: String) {
        switch string.replacingOccurrences(of: " ", with: "") {
        case "\n", "\n\n", "\n\n\n": break
        default: count[level]?.append(string)
        }
    }
}
