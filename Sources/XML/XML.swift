public struct xml {
    public var key: String?
    public var value: String?
    public var attributes: [String: String] = [:]
    
    public init(key: String? = nil, value: String? = nil, attributes: [String: String] = [:]) {
        self.key = key
        self.value = value
        self.attributes = attributes
    }
    
    var output:[Token] = []
    mutating func reset() { self.output = [] }
}

extension xml: xmls {
    public mutating func handle_data(data: [Unicode.Scalar]) {
        output.append(.data(String(data.map(Character.init))))
    }
    
    public mutating func handle_tag_start(name: String, attributes: [String : String]) {
        output.append(.open(name: name, is_sc: false, attrs: attributes))
    }
    
    public mutating func handle_tag_empty(name: String, attributes: [String : String]) {
        output.append(.open(name: name, is_sc: true, attrs: attributes))
    }
    
    public mutating func handle_tag_end(name: String) {
        output.append(.close(name: name))
    }
    
    public mutating func handle_processing_instruction(target: String, data: [Unicode.Scalar]) {
        output.append(.pi(target, String(data.map(Character.init))))
    }
    
    public mutating func handle_error(_ message: String, line: Int, column: Int) {
        output.append(.error(message, line, column))
    }
}

public enum Token: Equatable {
    case open(name: String, is_sc: Bool, attrs: [String: String])
    case close(name: String), error(String, Int, Int), data(String), pi(String, String)

    public static func == (lhs:Token, rhs:Token) -> Bool {
        switch (lhs, rhs) {
        case (let .open(name1, sc1, attrs1), let .open(name2, sc2, attrs2)):
            return name1 == name2 && sc1 == sc2 && attrs1 == attrs2
        case (.close(let name1), .close(let name2)):
            return name1 == name2
        case (let .error(message1, l1, k1), let .error(message2, l2, k2)):
            return message1 == message2 && (l1, k1) == (l2, k2)
        case (.data(let v1), .data(let v2)):
            return v1 == v2
        case (let .pi(target1, data1), let .pi(target2, data2)):
            return target1 == target2 && data1 == data2
        default:
            return false
        }
    }

//    public var description: String {
//        switch self {
//        case let .open(name, sc, attrs):
//            return "\(sc ? "empty" : "start") tag: \(name), attributes: \(_print_attributes(attrs))"
//        case .close(let name):
//            return "end tag: \(name)"
//        case let .error(message, l, k):
//            return "\u{001B}[0;33m(\(l + 1):\(k + 1)) Warning: \(message)\u{1B}[0m"
//        case let .pi(target, data):
//            return "processing instruction [\(target)]: '\(data)'"
//        case .data(let v):
//            return v
//        }
//    }
}

func _print_attributes(_ attributes:[String: String]) -> String {
    let internal_str = Array(attributes).sorted(by: {$0.0 < $1.0})
    .map{"'\($0.0)': '\($0.1)'"}.joined(separator: ", ")
    return "{\(internal_str)}"
}

func print_tokens(_ tokens:[Token]) -> String {
    tokens.map{String(describing: $0)}.joined(separator: "\n")
}





extension Unicode.Scalar {
    var is_xml_name_start: Bool {
        "a" ... "z" ~= self || "A" ... "Z" ~= self || self == ":" || self == "_"
        || "\u{C0}"   ... "\u{D6}"   ~= self || "\u{D8}"   ... "\u{F6}"   ~= self
        || "\u{F8}"   ... "\u{2FF}"  ~= self || "\u{370}"  ... "\u{37D}"  ~= self
        || "\u{37F}"  ... "\u{1FFF}" ~= self || "\u{200C}" ... "\u{200D}" ~= self
        || "\u{2070}" ... "\u{218F}" ~= self || "\u{2C00}" ... "\u{2FEF}" ~= self
        || "\u{3001}" ... "\u{D7FF}" ~= self || "\u{F900}" ... "\u{FDCF}" ~= self
        || "\u{FDF0}" ... "\u{FFFD}" ~= self || "\u{10000}" ... "\u{EFFFF}" ~= self
    }
    
    var is_xml_name: Bool {
        "a" ... "z" ~= self || "A" ... "Z" ~= self || "0" ... ":" ~= self
        || self == "_" || self == "-" || self == "." || self == "\u{B7}"
        || "\u{0300}" ... "\u{036F}" ~= self || "\u{203F}" ... "\u{2040}" ~= self
        || "\u{C0}"   ... "\u{D6}"   ~= self || "\u{D8}"   ... "\u{F6}"   ~= self
        || "\u{F8}"   ... "\u{2FF}"  ~= self || "\u{370}"  ... "\u{37D}"  ~= self
        || "\u{37F}"  ... "\u{1FFF}" ~= self || "\u{200C}" ... "\u{200D}" ~= self
        || "\u{2070}" ... "\u{218F}" ~= self || "\u{2C00}" ... "\u{2FEF}" ~= self
        || "\u{3001}" ... "\u{D7FF}" ~= self || "\u{F900}" ... "\u{FDCF}" ~= self
        || "\u{FDF0}" ... "\u{FFFD}" ~= self || "\u{10000}" ... "\u{EFFFF}" ~= self
    }
    
    var is_xml_whitespace: Bool {
        self == " " || self == "\u{9}" || self == "\u{D}" || self == "\u{A}"
    }
}

extension String {
    init<C>(_ buffer:C) where C:Collection, C.Element == Unicode.Scalar {
        self.init(buffer.map(Character.init))
    }
}

enum State {
    case data(Unicode.Scalar?), begin_markup, slash1, name(Unicode.Scalar), attributes, no_attributes, label(Unicode.Scalar), space1, equals, space2, attribute_value, slash2, end_markup, exclam, hyphen1, comment, hyphen2, hyphen3, question1, pi_space, pi_data(Unicode.Scalar), question2
}

enum Markup {
    case none, start, empty, end, comment, processing
}

struct Position {
    var line: Int = 0
    var column: Int = 0
    
    mutating func advance(_ u: Unicode.Scalar) {
        if u == "\n" {
            self.line   += 1
            self.column  = 0
        } else {
            self.column += 1
        }
    }
}

extension String.UnicodeScalarView.Iterator {
    mutating func read_reference(position: inout Position) -> (after: Unicode.Scalar?, content: [Unicode.Scalar], error: String?) {
        enum ReferenceState {
            case initial, name, hashtag, x, decimal(UInt32), hex(UInt32)
        }
        
        let default_entities: [String: [Unicode.Scalar]] = ["amp": ["&"], "lt": ["<"], "gt": [">"], "apos": ["'"], "quot": ["\""]]
        
        var state: ReferenceState = .initial
        var content: [Unicode.Scalar] = ["&"]
        
        func _charref(_ u: Unicode.Scalar, scalar: UInt32) -> (after: Unicode.Scalar?, content: [Unicode.Scalar], error: String?) {
            guard scalar > 0 else {
                return (u, content, "cannot reference null character '\\0'")
            }
            
            guard scalar <= 0xD7FF || 0xE000 ... 0xFFFD ~= scalar || 0x10000 ... 0x10FFFF ~= scalar else {
                return (u, content, "cannot reference illegal character '\\u{\(scalar)}'")
            }
            
            position.advance(u)
            return (self.next(), [Unicode.Scalar(scalar)!], nil)
        }
        
        while let u:Unicode.Scalar = self.next() {
            switch state {
            case .initial:
                if u == "#" {
                    state = .hashtag
                } else if u.is_xml_name_start {
                    state = .name
                } else {
                    return (u, content, "unescaped ampersand '&'")
                }
                
            case .name:
                if u == ";" {
                    content = default_entities[String(content.dropFirst())] ?? content
                    position.advance(u)
                    return (self.next(), content, nil)
                } else {
                    guard u.is_xml_name else {
                        return (u, content, "unexpected '\(u)' in entity reference")
                    }
                }
                
            case .hashtag:
                if "0" ... "9" ~= u {
                    state = .decimal(u.value - Unicode.Scalar("0").value)
                } else if u == "x" {
                    state = .x
                } else {
                    return (u, content, "unexpected '\(u)' in character reference")
                }
                
            case .decimal(let scalar):
                if "0" ... "9" ~= u {
                    state = .decimal(u.value - Unicode.Scalar("0").value + 10 * scalar)
                } else if u == ";" {
                    return _charref(u, scalar: scalar)
                } else {
                    return (u, content, "unexpected '\(u)' in character reference")
                }
                
            case .x:
                if "0" ... "9" ~= u {
                    state = .hex(u.value - Unicode.Scalar("0").value)
                } else if "a" ... "f" ~= u {
                    state = .hex(10 + u.value - Unicode.Scalar("a").value)
                } else if "A" ... "F" ~= u {
                    state = .hex(10 + u.value - Unicode.Scalar("A").value)
                } else {
                    return (u, content, "unexpected '\(u)' in character reference")
                }
                
            case .hex(let scalar):
                if "0" ... "9" ~= u {
                    state = .hex(u.value - Unicode.Scalar("0").value + scalar << 4)
                } else if "a" ... "f" ~= u {
                    state = .hex(10 + u.value - Unicode.Scalar("a").value + scalar << 4)
                } else if "A" ... "F" ~= u {
                    state = .hex(10 + u.value - Unicode.Scalar("A").value + scalar << 4)
                } else if u == ";" {
                    return _charref(u, scalar: scalar)
                } else {
                    return (u, content, "unexpected '\(u)' in character reference")
                }
            }
            
            position.advance(u)
            content.append(u)
        }
        
        return (nil, content, "unexpected EOF inside reference")
    }
}

public protocol xmls {
    mutating func handle_data(data: [Unicode.Scalar])
    mutating func handle_tag_start(name: String, attributes: [String: String])
    mutating func handle_tag_empty(name: String, attributes: [String: String])
    mutating func handle_tag_end(name: String)
    mutating func handle_processing_instruction(target: String, data: [Unicode.Scalar])
    mutating func handle_error(_ message: String, line: Int, column: Int)
}

public extension xmls {
    mutating func parse(_ str:String) {
        var state: State = .end_markup
        var markup_context:Markup = .none
        var iterator: String.UnicodeScalarView.Iterator = str.unicodeScalars.makeIterator()
        var iterator_checkpoint: String.UnicodeScalarView.Iterator = iterator
        
        var name_buffer: [Unicode.Scalar] = []
        var label_buffer: [Unicode.Scalar] = []
        var attributes: [String: String] = [:]
        var string_delimiter: Unicode.Scalar = "\0"

        var position:Position            = Position()
        var position_checkpoint:Position = position

        func _emit_tag() {
            switch markup_context {
            case .none: break
            case .start: handle_tag_start(name: String(name_buffer), attributes: attributes)
            case .empty: handle_tag_empty(name: String(name_buffer), attributes: attributes)
            case .end: handle_tag_end(name: String(name_buffer))
            case .comment: break
            case .processing:
                handle_processing_instruction(target: String(name_buffer), data: label_buffer)
                label_buffer = []
            }
        }
        
        func _error(_ message:String) {
            handle_error(message, line: position.line, column: position.column)
        }

        guard var u: Unicode.Scalar = iterator.next() else { return }

        var u_checkpoint: Unicode.Scalar = u

        while true {
            func _reset() {
                markup_context = .none

                name_buffer = []
                label_buffer = []
                attributes = [:]
                string_delimiter = "\0"

                iterator = iterator_checkpoint
                position = position_checkpoint
                u = u_checkpoint
                state = .data("<")
            }

            fsm: switch state {
            case .end_markup:
                _emit_tag()
                markup_context = .none

                name_buffer = []
                attributes = [:]

                if u == "<" {
                    state = .begin_markup
                } else {
                    state = .data(nil)
                    continue
                }

            case .data(let u_before):
                var u_current: Unicode.Scalar = u
                var data_buffer: [Unicode.Scalar]

                if let u_previous: Unicode.Scalar = u_before {
                    data_buffer = [u_previous]
                } else {
                    data_buffer = []
                }

                while u_current != "<" {
                    let u_next: Unicode.Scalar?
                    if u_current == "&" {
                        let content: [Unicode.Scalar]
                        let error: String?
                        (u_next, content, error) = iterator.read_reference(position: &position)
                        data_buffer.append(contentsOf: content)

                        position.advance(u_current)

                        if let error_message:String = error {
                            _error(error_message)
                        }
                    } else {
                        data_buffer.append(u_current)
                        u_next = iterator.next()
                        position.advance(u_current)
                    }

                    guard let u_after:Unicode.Scalar = u_next else {
                        handle_data(data: data_buffer)
                        state = .end_markup
                        break fsm
                    }
                    u_current = u_after
                }

                state = .begin_markup
                handle_data(data: data_buffer)

            case .begin_markup:
                iterator_checkpoint = iterator
                position_checkpoint = position
                u_checkpoint = u
                markup_context = .start
                if u.is_xml_name_start {
                    state = .name(u)
                } else if u == "/" {
                    state = .slash1
                } else if u == "!" {
                    state = .exclam
                } else if u == "?" {
                    state = .question1
                } else {
                    _error("unexpected '\(u)' after left angle bracket '<'")
                    _reset()
                    continue
                }

            case .slash1:
                markup_context = .end
                guard u.is_xml_name_start else {
                    _error("unexpected '\(u)' in end tag ''")
                    _reset()
                    continue
                }

                state = .name(u)

            case .name(let u_previous):
                name_buffer.append(u_previous)
                if u.is_xml_name {
                    state = .name(u)
                    break
                }

                if markup_context == .start {
                    if u.is_xml_whitespace {
                        state = .attributes
                    } else if u == "/" {
                        state = .slash2
                    } else if u == ">" {
                        state = .end_markup
                    } else {
                        _error("unexpected '\(u)' in start tag '\(String(name_buffer))'")
                        _reset()
                        continue
                    }
                } else if markup_context == .end {
                    if u.is_xml_whitespace {
                        state = .no_attributes
                    } else if u == ">" {
                        state = .end_markup
                    } else {
                        _error("unexpected '\(u)' in end tag '\(String(name_buffer))'")
                        _reset()
                        continue
                    }
                } else if markup_context == .processing {
                    if u.is_xml_whitespace {
                        state = .pi_space
                    } else if u == "?" {
                        state = .question2
                    } else {
                        _error("unexpected '\(u)' in processing instruction '\(String(name_buffer))'")
                        _reset()
                        continue
                    }
                }

            case .attributes:
                if u.is_xml_name_start {
                    state = .label(u)
                } else if u == "/" {
                    state = .slash2
                } else if u == ">" {
                    state = .end_markup
                } else {
                    guard u.is_xml_whitespace else {
                        _error("unexpected '\(u)' in start tag '\(String(name_buffer))'")
                        _reset()
                        continue
                    }
                }

            case .no_attributes:
                if u == ">" {
                    state = .end_markup
                } else {
                    guard u.is_xml_whitespace else {
                        if u.is_xml_name_start {
                            _error("end tag '\(String(name_buffer))' cannot contain attributes")
                        } else {
                            _error("unexpected '\(u)' in end tag '\(String(name_buffer))'")
                        }
                        _reset()
                        continue
                    }
                }

            case .label(let u_previous):
                label_buffer.append(u_previous)

                if u.is_xml_name {
                    state = .label(u)
                } else if u == "=" {
                    state = .equals
                } else {
                    guard u.is_xml_whitespace else {
                        _error("unexpected '\(u)' in start tag '\(String(name_buffer))'")
                        _reset()
                        continue
                    }

                    state = .space1
                }

            case .space1:
                if u == "=" {
                    state = .equals
                } else {
                    guard u.is_xml_whitespace else {
                        _error("unexpected '\(u)' in start tag '\(String(name_buffer))'")
                        _reset()
                        continue
                    }
                }

            case .equals:
                if u == "\"" || u == "'" {
                    string_delimiter = u
                    state = .attribute_value
                } else {
                    guard u.is_xml_whitespace else {
                        _error("unexpected '\(u)' in start tag '\(String(name_buffer))'")
                        _reset()
                        continue
                    }

                    state = .space2
                }

            case .space2:
                if u == "\"" || u == "'" {
                    string_delimiter = u
                    state = .attribute_value
                } else {
                    guard u.is_xml_whitespace else {
                        _error("unexpected '\(u)' in start tag '\(String(name_buffer))'")
                        _reset()
                        continue
                    }
                }

            case .attribute_value:
                var u_current: Unicode.Scalar = u
                var value_buffer: [Unicode.Scalar] = []

                while u_current != string_delimiter {
                    let u_next: Unicode.Scalar?
                    if u_current == "&" {
                        let content: [Unicode.Scalar]
                        let error: String?
                        (u_next, content, error) = iterator.read_reference(position: &position)
                        value_buffer.append(contentsOf: content)

                        position.advance(u_current)

                        if let error_message:String = error {
                            _error(error_message)
                        }
                    } else {
                        value_buffer.append(u_current)
                        u_next = iterator.next()
                        position.advance(u_current)
                    }

                    guard let u_after: Unicode.Scalar = u_next else {
                        break fsm
                    }
                    u_current = u_after
                }

                string_delimiter = "\0"
                let label_str: String = String(label_buffer)

                guard attributes[label_str] == nil else {
                    _error("redefinition of attribute '\(label_str)'")
                    _reset()
                    continue
                }

                attributes[label_str] = String(value_buffer)
                label_buffer = []
                value_buffer = []

                state = .attributes

            case .slash2:
                markup_context = .empty
                guard u == ">" else {
                    _error("unexpected '\(u)' in empty tag '\(String(name_buffer))'")
                    _reset()
                    continue
                }

                state = .end_markup

            case .exclam:
                if u == "-" {
                    state = .hyphen1
                } else {
                    _error("XML declarations are unsupported")
                    _reset()
                    continue
                }

            case .hyphen1:
                guard u == "-" else {
                    _error("unexpected '\(u)' after '<!-'")
                    _reset()
                    continue
                }

                state = .comment

            case .comment:
                markup_context = .comment
                if u == "-" {
                    state = .hyphen2
                }

            case .hyphen2:
                if u == "-" {
                    state = .hyphen3
                } else {
                    state = .comment
                }

            case .hyphen3:
                guard u == ">" else {
                    handle_error("unexpected double hyphen '--' inside comment body",
                                      line: position.line, column: position.column - 1)
                    _reset()
                    continue
                }

                state = .end_markup

            case .question1:
                markup_context = .processing
                guard u.is_xml_name_start else {
                    _error("unexpected '\(u)' after '<?'")
                    _reset()
                    continue
                }

                state = .name(u)

            case .pi_space:
                if u == "?" {
                    state = .question2
                } else if !u.is_xml_whitespace {
                    state = .pi_data(u)
                }

            case .pi_data(let u_previous):
                label_buffer.append(u_previous)
                if u == "?" {
                    state = .question2
                } else {
                    state = .pi_data(u)
                }

            case .question2:
                if u == ">" {
                    state = .end_markup
                } else {
                    label_buffer.append("?")
                    state = .pi_data(u)
                }
            }

            position.advance(u)
            guard let u_after:Unicode.Scalar = iterator.next() else {
                switch state {
                case .end_markup:
                    _emit_tag()
                default:
                    _error("unexpected end of stream inside markup structure")
                }
                return
            }
            u = u_after
        }
    }
}
