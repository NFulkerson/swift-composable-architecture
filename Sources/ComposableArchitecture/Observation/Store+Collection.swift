import Foundation
import OrderedCollections

public protocol CollectionAction<Elements> {
  associatedtype Elements: Collection
  associatedtype ID: Hashable = Elements.Index
  associatedtype ElementAction

  static func element(id: ID, action: ElementAction) -> Self
  static func id(at index: Elements.Index, elements: Elements) -> ID
  static func index(at id: ID, elements: Elements) -> Elements.Index?

  var element: (id: ID, action: ElementAction)? { get }
}

public protocol RangeReplaceableCollectionAction<Elements>: CollectionAction {
  static func setElements(_ elements: Elements) -> Self
}

extension CollectionAction where ID == Elements.Index {
  public static func id(at index: Elements.Index, elements _: Elements) -> Elements.Index {
    index
  }

  public static func index(at id: Elements.Index, elements: Elements) -> Elements.Index? {
    elements.indices.contains(id) ? id : nil
  }
}

public enum IndexedAction<Elements: Collection, ElementAction>: CollectionAction
where Elements.Index: Hashable {
  case element(id: Elements.Index, action: ElementAction)

  public var element: (id: Elements.Index, action: ElementAction)? {
    switch self {
    case let .element(id, action):
      return (id, action)
    }
  }
}

extension IndexedAction: CasePathable {
  public static var allCasePaths: AllCasePaths {
    AllCasePaths()
  }

  public struct AllCasePaths {
    public var element: AnyCasePath<IndexedAction, (id: Elements.Index, action: ElementAction)> {
      AnyCasePath(
        embed: IndexedAction.element,
        extract: {
          guard case let .element(id, action) = $0 else { return nil }
          return (id, action)
        }
      )
    }

    public subscript(position: Elements.Index) -> AnyCasePath<IndexedAction, ElementAction> {
      AnyCasePath(
        embed: { .element(id: position, action: $0) },
        extract: {
          guard case .element(position, let action) = $0 else { return nil }
          return action
        }
      )
    }
  }
}

extension IndexedAction: Equatable where ElementAction: Equatable {}
extension IndexedAction: Hashable where ElementAction: Hashable {}
extension IndexedAction: Sendable where Elements.Index: Sendable, ElementAction: Sendable {}

public typealias ArrayAction<Element: Reducer> = IndexedAction<[Element.State], Element.Action>

extension Store: MutableCollection, Collection, Sequence
where
  State: MutableCollection,
  State.Index: Hashable,
  Action: CollectionAction,
  Action.Elements == State
{
  public var startIndex: State.Index { self.stateSubject.value.startIndex }
  public var endIndex: State.Index { self.stateSubject.value.endIndex }
  public func index(after i: State.Index) -> State.Index { self.stateSubject.value.index(after: i) }

  public subscript(position: State.Index) -> Store<State.Element, Action.ElementAction>
  where State.Index: Sendable {
    get {
      self.scope(
        state: { $0[Action.index(at: Action.id(at: position, elements: $0), elements: $0)!] },
        id: { Action.id(at: position, elements: $0) },
        action: { .element(id: Action.id(at: position, elements: $0), action: $1) },
        isInvalid: {
          !($0.indices.contains(position)
            && Action.index(at: Action.id(at: position, elements: $0), elements: $0) != nil)
        },
        removeDuplicates: nil
      )
    }
    set { /* self.children[id] = newValue */  }
  }
}

extension Store: BidirectionalCollection
where
  State: BidirectionalCollection & MutableCollection,
  State.Index: Hashable,
  Action: CollectionAction,
  Action.Elements == State
{
  public func index(before i: State.Index) -> State.Index {
    self.stateSubject.value.index(before: i)
  }
}

extension Store: RandomAccessCollection
where
  State: RandomAccessCollection & MutableCollection,
  State.Index: Hashable,
  Action: CollectionAction,
  Action.Elements == State
{}

public enum IdentifiedArrayAction<ID: Hashable, State, Action>: CollectionAction {
  case element(id: ID, action: Action)

  public static func id(at index: Int, elements: IdentifiedArray<ID, State>) -> ID {
    elements.ids[index]
  }

  public static func index(at id: ID, elements: IdentifiedArray<ID, State>) -> Int? {
    elements.index(id: id)
  }

  public var element: (id: ID, action: Action)? {
    switch self {
    case let .element(id, action):
      return (id, action)
    }
  }
}

extension IdentifiedArrayAction: CasePathable {
  public static var allCasePaths: AllCasePaths {
    AllCasePaths()
  }

  public struct AllCasePaths {
    public var element: AnyCasePath<IdentifiedArrayAction, (id: ID, action: Action)> {
      AnyCasePath(
        embed: IdentifiedArrayAction.element,
        extract: {
          guard case let .element(id, action) = $0 else { return nil }
          return (id, action)
        }
      )
    }

    public subscript(id id: ID) -> AnyCasePath<IdentifiedArrayAction, Action> {
      AnyCasePath(
        embed: { .element(id: id, action: $0) },
        extract: {
          guard case .element(id, let action) = $0 else { return nil }
          return action
        }
      )
    }
  }
}

extension IdentifiedArrayAction: Equatable where Action: Equatable {}
extension IdentifiedArrayAction: Hashable where Action: Hashable {}
extension IdentifiedArrayAction: Sendable where ID: Sendable, Action: Sendable {}

typealias IdentifiedArrayActionOf<R: Reducer> = IdentifiedArrayAction<
  R.State.ID, R.State, R.Action
> where R.State: Identifiable

extension Reducer {
  public func forEach<
    ElementsState: MutableCollection,
    ElementsAction: CollectionAction<ElementsState>
  >(
    _ stateKeyPath: WritableKeyPath<State, ElementsState>,
    action actionCasePath: CaseKeyPath<Action, ElementsAction>,
    @ReducerBuilder<ElementsState.Element, ElementsAction.ElementAction> _ element:
      () -> some Reducer<ElementsState.Element, ElementsAction.ElementAction>
  ) -> some ReducerOf<Self>
  where
    Action: CasePathable,
    ElementsState.Element: ObservableState,
    ElementsState.Index: Hashable & Sendable
  {
    _ForEachCollectionReducer(
      base: self,
      stateKeyPath: stateKeyPath,
      actionCasePath: actionCasePath,
      element: element()
    )
  }
}

private struct _ForEachCollectionReducer<
  Base: Reducer,
  ElementsState: MutableCollection,
  ElementsAction: CollectionAction<ElementsState>,
  Element: Reducer<ElementsState.Element, ElementsAction.ElementAction>
>: Reducer
where
  Base.Action: CasePathable,
  ElementsState.Element: ObservableState,
  ElementsState.Index: Hashable & Sendable
{
  let base: Base
  let stateKeyPath: WritableKeyPath<Base.State, ElementsState>
  let actionCasePath: CaseKeyPath<Base.Action, ElementsAction>
  let element: Element

  func reduce(into state: inout Base.State, action: Base.Action) -> Effect<Base.Action> {
    var elementEffects: Effect<Base.Action> = .none
    element: if let elementAction = action[case: self.actionCasePath] {
      guard let element = elementAction.element
      else { break element }
      guard let index = ElementsAction.index(at: element.id, elements: state[keyPath: stateKeyPath])
      else {
        // TODO: runtimeWarn
        break element
      }
      elementEffects = self.element
        .reduce(
          into: &state[keyPath: self.stateKeyPath][index],
          action: element.action
        )
        .map { self.actionCasePath(.element(id: element.id, action: $0)) }
    }
    return .merge(
      elementEffects,
      self.base.reduce(into: &state, action: action)
    )
  }
}
