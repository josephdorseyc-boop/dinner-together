// Linux-only stand-in module named `SwiftUI`, used by Package.swift so that
// SessionStore.swift's `import SwiftUI` resolves where SwiftUI/Combine don't
// exist. It provides only the two things the store uses from that import:
// the ObservableObject marker protocol and the @Published property wrapper.
// No observation happens; the harness tests read state directly.
//
// Never compiled on macOS or iOS (Package.swift adds this target only on
// Linux), so it cannot shadow the real framework there.

public protocol ObservableObject: AnyObject {}

@propertyWrapper
public struct Published<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(initialValue: Value) { self.wrappedValue = initialValue }
}
