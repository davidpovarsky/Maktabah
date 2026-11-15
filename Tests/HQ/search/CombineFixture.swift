// Minimal observer dependency for portable state-machine tests only.
// This is not validation of Apple's Combine scheduling or SwiftUI rendering.
public final class AnyCancellable { public init() {} }
public final class FixturePublisher<Value> {
    private var value: Value
    private var observers: [(Value) -> Void] = []
    public init(_ value: Value) { self.value = value }
    public func send(_ value: Value) { self.value = value; observers.forEach { $0(value) } }
    public func sink(_ receive: @escaping (Value) -> Void) -> AnyCancellable {
        observers.append(receive); receive(value); return AnyCancellable()
    }
    public func dropFirst() -> FixtureDropFirst<Value> { FixtureDropFirst(self) }
}
public struct FixtureDropFirst<Value> {
    let source: FixturePublisher<Value>
    init(_ source: FixturePublisher<Value>) { self.source = source }
    public func sink(_ receive: @escaping (Value) -> Void) -> AnyCancellable {
        var first = true
        return source.sink { value in
            if first { first = false } else { receive(value) }
        }
    }
}
@propertyWrapper public struct Published<Value> {
    private let publisher: FixturePublisher<Value>
    private var value: Value
    public init(wrappedValue: Value) { value = wrappedValue; publisher = FixturePublisher(wrappedValue) }
    public var wrappedValue: Value {
        get { value }
        set { value = newValue; publisher.send(newValue) }
    }
    public var projectedValue: FixturePublisher<Value> { publisher }
}
public protocol ObservableObject {}
public extension ObservableObject {
    var objectWillChange: FixtureVoidPublisher { FixtureVoidPublisher() }
}
public struct FixtureVoidPublisher {
    public init() {}
    public func send() {}
    public func sink(_ receive: @escaping (()) -> Void) -> AnyCancellable { AnyCancellable() }
}
