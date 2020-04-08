// Generated using Sourcery 0.17.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable file_length
fileprivate func compareOptionals<T>(lhs: T?, rhs: T?, compare: (_ lhs: T, _ rhs: T) -> Bool) -> Bool {
    switch (lhs, rhs) {
    case let (lValue?, rValue?):
        return compare(lValue, rValue)
    case (nil, nil):
        return true
    default:
        return false
    }
}

fileprivate func compareArrays<T>(lhs: [T], rhs: [T], compare: (_ lhs: T, _ rhs: T) -> Bool) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (idx, lhsItem) in lhs.enumerated() {
        guard compare(lhsItem, rhs[idx]) else { return false }
    }

    return true
}


// MARK: - AutoEquatable for classes, protocols, structs

// MARK: - AutoEquatable for Enums
// MARK: - MessageModel.MessageKind AutoEquatable
extension MessageModel.MessageKind: Equatable {}
public func == (lhs: MessageModel.MessageKind, rhs: MessageModel.MessageKind) -> Bool {
    switch (lhs, rhs) {
    case (.text(let lhs), .text(let rhs)):
        return lhs == rhs
    case (.image(let lhs), .image(let rhs)):
        if lhs.path != rhs.path { return false }
        if lhs.size != rhs.size { return false }
        return true
    case (.audio(let lhs), .audio(let rhs)):
        return lhs == rhs
    case (.forward(let lhs), .forward(let rhs)):
        return lhs == rhs
    default: return false
    }
}
