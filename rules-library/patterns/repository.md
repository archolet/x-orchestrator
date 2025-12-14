---
name: Repository Pattern
version: 1.0
applies_to: "**/Repositories/**/*"
priority: medium
---

# Repository Pattern

## Amaç

Data access logic'i business logic'ten ayırır. Domain layer'ın persistence detaylarını bilmesini önler.

## Temel Yapı

```
┌─────────────────────────────────────────────────────────────┐
│                     Domain Layer                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                   IRepository                        │   │
│  │  (Interface - sadece Domain'de tanımlı)             │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ implements
┌─────────────────────────────────────────────────────────────┐
│                 Infrastructure Layer                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              ConcreteRepository                      │   │
│  │  (Implementation - DB, API, File, etc.)             │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Generic Repository Interface

```typescript
// Domain Layer
export interface IRepository<T, TId> {
  findById(id: TId): Promise<T | null>;
  findAll(): Promise<T[]>;
  save(entity: T): Promise<void>;
  delete(id: TId): Promise<void>;
  exists(id: TId): Promise<boolean>;
}
```

## Specific Repository Interface

```typescript
// Domain Layer
export interface IUserRepository extends IRepository<User, UserId> {
  findByEmail(email: Email): Promise<User | null>;
  findByRole(role: UserRole): Promise<User[]>;
  findActiveUsers(): Promise<User[]>;
}

export interface IOrderRepository extends IRepository<Order, OrderId> {
  findByCustomer(customerId: CustomerId): Promise<Order[]>;
  findByStatus(status: OrderStatus): Promise<Order[]>;
  findByDateRange(start: Date, end: Date): Promise<Order[]>;
}
```

## Implementation

```typescript
// Infrastructure Layer
export class UserRepository implements IUserRepository {
  constructor(private db: PrismaClient) {}

  async findById(id: UserId): Promise<User | null> {
    const data = await this.db.user.findUnique({
      where: { id: id.value }
    });
    return data ? UserMapper.toDomain(data) : null;
  }

  async findByEmail(email: Email): Promise<User | null> {
    const data = await this.db.user.findUnique({
      where: { email: email.value }
    });
    return data ? UserMapper.toDomain(data) : null;
  }

  async save(user: User): Promise<void> {
    const data = UserMapper.toPersistence(user);
    await this.db.user.upsert({
      where: { id: data.id },
      create: data,
      update: data
    });
  }

  async delete(id: UserId): Promise<void> {
    await this.db.user.delete({
      where: { id: id.value }
    });
  }

  async exists(id: UserId): Promise<boolean> {
    const count = await this.db.user.count({
      where: { id: id.value }
    });
    return count > 0;
  }

  async findAll(): Promise<User[]> {
    const data = await this.db.user.findMany();
    return data.map(UserMapper.toDomain);
  }

  async findByRole(role: UserRole): Promise<User[]> {
    const data = await this.db.user.findMany({
      where: { role: role.value }
    });
    return data.map(UserMapper.toDomain);
  }

  async findActiveUsers(): Promise<User[]> {
    const data = await this.db.user.findMany({
      where: { isActive: true }
    });
    return data.map(UserMapper.toDomain);
  }
}
```

## Mapper Pattern

```typescript
export class UserMapper {
  static toDomain(data: UserDbModel): User {
    return User.reconstitute(
      UserId.create(data.id),
      Email.create(data.email).value,
      UserName.create(data.name).value,
      data.createdAt
    );
  }

  static toPersistence(user: User): UserDbModel {
    return {
      id: user.id.value,
      email: user.email.value,
      name: user.name.value,
      createdAt: user.createdAt
    };
  }
}
```

## Unit of Work Integration

```typescript
export interface IUnitOfWork {
  users: IUserRepository;
  orders: IOrderRepository;
  commit(): Promise<void>;
  rollback(): Promise<void>;
}

export class UnitOfWork implements IUnitOfWork {
  users: IUserRepository;
  orders: IOrderRepository;
  private transaction: Transaction;

  constructor(private db: PrismaClient) {
    this.users = new UserRepository(db);
    this.orders = new OrderRepository(db);
  }

  async commit(): Promise<void> {
    await this.transaction?.commit();
  }

  async rollback(): Promise<void> {
    await this.transaction?.rollback();
  }
}
```

## Test Double

```typescript
// Test Implementation
export class InMemoryUserRepository implements IUserRepository {
  private users: Map<string, User> = new Map();

  async findById(id: UserId): Promise<User | null> {
    return this.users.get(id.value) || null;
  }

  async save(user: User): Promise<void> {
    this.users.set(user.id.value, user);
  }

  async delete(id: UserId): Promise<void> {
    this.users.delete(id.value);
  }

  // ... other methods
}

// Usage in tests
describe('UserService', () => {
  let repository: IUserRepository;
  let service: UserService;

  beforeEach(() => {
    repository = new InMemoryUserRepository();
    service = new UserService(repository);
  });

  it('should create user', async () => {
    await service.createUser({ email: 'test@test.com', name: 'Test' });
    const user = await repository.findByEmail(Email.create('test@test.com').value);
    expect(user).not.toBeNull();
  });
});
```

## Best Practices

1. **Interface'i Domain'de, Implementation'ı Infrastructure'da tanımla**
2. **Generic repository'yi YAGNI prensibiyle kullan** - Sadece gereken metodları implement et
3. **Query complexity'yi repository'de sakla** - Service'ler karmaşık query bilmemeli
4. **Mapper pattern kullan** - Domain ve persistence model'leri ayır
5. **Aggregate root başına bir repository** - Alt entity'ler için ayrı repository yapma
