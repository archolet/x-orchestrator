---
name: Domain-Driven Design
version: 1.0
applies_to: "src/Domain/**/*"
priority: high
---

# Domain-Driven Design (DDD) Rules

## Temel Prensipler

### 1. Ubiquitous Language
- Domain terimleri kod içinde tutarlı kullanılmalı
- İş birimi (business) ile aynı dili konuş
- Entity, Value Object, Aggregate isimleri domain'den gelmeli

### 2. Bounded Context
- Her context kendi modelini tanımlar
- Context'ler arası anti-corruption layer kullan
- Shared kernel dikkatli yönetilmeli

### 3. Layer Architecture
```
src/
├── Domain/           # Pure business logic, no dependencies
│   ├── Entities/
│   ├── ValueObjects/
│   ├── Aggregates/
│   ├── Events/
│   └── Repositories/ # Interfaces only
├── Application/      # Use cases, orchestration
│   ├── Commands/
│   ├── Queries/
│   ├── Services/
│   └── DTOs/
├── Infrastructure/   # External concerns
│   ├── Persistence/
│   ├── Messaging/
│   └── External/
└── Presentation/     # UI, API
    ├── Controllers/
    └── ViewModels/
```

## Entity Rules

```typescript
// Good: Entity with identity
export class User extends Entity<UserId> {
  private _email: Email;
  private _name: UserName;

  private constructor(id: UserId, email: Email, name: UserName) {
    super(id);
    this._email = email;
    this._name = name;
  }

  static create(email: Email, name: UserName): User {
    return new User(UserId.generate(), email, name);
  }

  // Behavior, not just data
  changeEmail(newEmail: Email): void {
    this._email = newEmail;
    this.addDomainEvent(new UserEmailChangedEvent(this.id, newEmail));
  }
}
```

## Value Object Rules

```typescript
// Good: Immutable value object
export class Email extends ValueObject<{ value: string }> {
  private constructor(value: string) {
    super({ value });
  }

  static create(value: string): Result<Email> {
    if (!this.isValid(value)) {
      return Result.fail('Invalid email format');
    }
    return Result.ok(new Email(value));
  }

  private static isValid(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  get value(): string {
    return this.props.value;
  }
}
```

## Aggregate Rules

1. Aggregate root üzerinden erişim
2. Transaction boundary = Aggregate boundary
3. Aggregate'ler arası eventual consistency
4. Küçük aggregate'ler tercih et

```typescript
// Order aggregate root
export class Order extends AggregateRoot<OrderId> {
  private _items: OrderItem[];
  private _status: OrderStatus;

  addItem(product: ProductId, quantity: Quantity, price: Money): void {
    this.ensureNotCompleted();
    const item = OrderItem.create(product, quantity, price);
    this._items.push(item);
    this.addDomainEvent(new OrderItemAddedEvent(this.id, item));
  }

  private ensureNotCompleted(): void {
    if (this._status === OrderStatus.Completed) {
      throw new OrderAlreadyCompletedException(this.id);
    }
  }
}
```

## Repository Rules

```typescript
// Domain layer: Interface only
export interface IUserRepository {
  findById(id: UserId): Promise<User | null>;
  save(user: User): Promise<void>;
  delete(id: UserId): Promise<void>;
}

// Infrastructure layer: Implementation
export class UserRepository implements IUserRepository {
  constructor(private db: Database) {}

  async findById(id: UserId): Promise<User | null> {
    const data = await this.db.users.findUnique({ where: { id: id.value } });
    return data ? UserMapper.toDomain(data) : null;
  }
}
```

## Domain Event Rules

```typescript
export class UserCreatedEvent extends DomainEvent {
  constructor(
    public readonly userId: UserId,
    public readonly email: Email,
    public readonly occurredOn: Date = new Date()
  ) {
    super();
  }
}
```

## Dependency Rules

```
✅ Domain → (nothing)
✅ Application → Domain
✅ Infrastructure → Domain, Application
✅ Presentation → Application

❌ Domain → Application
❌ Domain → Infrastructure
❌ Application → Infrastructure (use interfaces)
```
