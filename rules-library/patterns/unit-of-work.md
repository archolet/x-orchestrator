---
name: Unit of Work Pattern
version: 1.0
applies_to: "**/Repositories/**/*"
priority: medium
---

# Unit of Work Pattern

## Amaç

Birden fazla repository işlemini tek bir transaction içinde yönet. Tüm değişiklikler ya commit edilir ya da rollback yapılır.

## Temel Yapı

```
┌─────────────────────────────────────────────────────────────────┐
│                        Unit of Work                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Transaction                           │   │
│  │  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐  │   │
│  │  │ UserRepo      │ │ OrderRepo     │ │ ProductRepo   │  │   │
│  │  │ • save()      │ │ • save()      │ │ • update()    │  │   │
│  │  │ • delete()    │ │ • delete()    │ │ • delete()    │  │   │
│  │  └───────────────┘ └───────────────┘ └───────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  commit() ─────────────▶ All changes persisted                  │
│  rollback() ───────────▶ All changes reverted                   │
└─────────────────────────────────────────────────────────────────┘
```

## Interface Tanımı

```typescript
// Application Layer
export interface IUnitOfWork {
  // Repositories
  readonly users: IUserRepository;
  readonly orders: IOrderRepository;
  readonly products: IProductRepository;
  readonly payments: IPaymentRepository;

  // Transaction control
  begin(): Promise<void>;
  commit(): Promise<void>;
  rollback(): Promise<void>;

  // Helper for auto-commit/rollback
  executeInTransaction<T>(work: () => Promise<T>): Promise<T>;
}
```

## Implementation

### Base Implementation

```typescript
// Infrastructure Layer
export class UnitOfWork implements IUnitOfWork {
  private _users: IUserRepository | null = null;
  private _orders: IOrderRepository | null = null;
  private _products: IProductRepository | null = null;
  private _payments: IPaymentRepository | null = null;

  private transaction: Transaction | null = null;
  private isCommitted = false;

  constructor(private db: PrismaClient) {}

  // Lazy loading repositories
  get users(): IUserRepository {
    if (!this._users) {
      this._users = new UserRepository(this.getClient());
    }
    return this._users;
  }

  get orders(): IOrderRepository {
    if (!this._orders) {
      this._orders = new OrderRepository(this.getClient());
    }
    return this._orders;
  }

  get products(): IProductRepository {
    if (!this._products) {
      this._products = new ProductRepository(this.getClient());
    }
    return this._products;
  }

  get payments(): IPaymentRepository {
    if (!this._payments) {
      this._payments = new PaymentRepository(this.getClient());
    }
    return this._payments;
  }

  private getClient(): PrismaClient | Transaction {
    return this.transaction || this.db;
  }

  async begin(): Promise<void> {
    if (this.transaction) {
      throw new Error('Transaction already started');
    }
    this.transaction = await this.db.$begin();
    this.isCommitted = false;
  }

  async commit(): Promise<void> {
    if (!this.transaction) {
      throw new Error('No transaction to commit');
    }
    await this.transaction.$commit();
    this.transaction = null;
    this.isCommitted = true;
  }

  async rollback(): Promise<void> {
    if (!this.transaction) {
      throw new Error('No transaction to rollback');
    }
    await this.transaction.$rollback();
    this.transaction = null;
    this.isCommitted = false;
  }

  async executeInTransaction<T>(work: () => Promise<T>): Promise<T> {
    await this.begin();
    try {
      const result = await work();
      await this.commit();
      return result;
    } catch (error) {
      await this.rollback();
      throw error;
    }
  }
}
```

### Prisma Implementation

```typescript
export class PrismaUnitOfWork implements IUnitOfWork {
  private _users: IUserRepository | null = null;
  private _orders: IOrderRepository | null = null;
  private ctx: Prisma.TransactionClient | null = null;

  constructor(private prisma: PrismaClient) {}

  get users(): IUserRepository {
    return this._users ??= new UserRepository(this.ctx ?? this.prisma);
  }

  get orders(): IOrderRepository {
    return this._orders ??= new OrderRepository(this.ctx ?? this.prisma);
  }

  async executeInTransaction<T>(work: () => Promise<T>): Promise<T> {
    return this.prisma.$transaction(async (tx) => {
      this.ctx = tx;
      this._users = null; // Reset to use transaction context
      this._orders = null;

      try {
        return await work();
      } finally {
        this.ctx = null;
      }
    });
  }

  // For manual control (if needed)
  async begin(): Promise<void> {
    throw new Error('Use executeInTransaction for Prisma');
  }

  async commit(): Promise<void> {
    throw new Error('Use executeInTransaction for Prisma');
  }

  async rollback(): Promise<void> {
    throw new Error('Use executeInTransaction for Prisma');
  }
}
```

## Use Case Kullanımı

### Sipariş Oluşturma

```typescript
export class CreateOrderUseCase {
  constructor(private uow: IUnitOfWork) {}

  async execute(request: CreateOrderRequest): Promise<CreateOrderResponse> {
    return this.uow.executeInTransaction(async () => {
      // 1. Get user
      const user = await this.uow.users.findById(request.userId);
      if (!user) {
        throw new UserNotFoundException(request.userId);
      }

      // 2. Check product stock and create order items
      const orderItems: OrderItem[] = [];
      for (const item of request.items) {
        const product = await this.uow.products.findById(item.productId);
        if (!product) {
          throw new ProductNotFoundException(item.productId);
        }
        if (product.stock < item.quantity) {
          throw new InsufficientStockException(product.id, product.stock, item.quantity);
        }

        // Decrease stock
        product.decreaseStock(item.quantity);
        await this.uow.products.save(product);

        orderItems.push(OrderItem.create(product.id, item.quantity, product.price));
      }

      // 3. Create order
      const order = Order.create(user.id, orderItems);
      await this.uow.orders.save(order);

      // 4. Create payment record
      const payment = Payment.create(order.id, order.totalAmount);
      await this.uow.payments.save(payment);

      // All or nothing - if any step fails, everything rolls back
      return CreateOrderResponse.success(order.id.value);
    });
  }
}
```

### Transfer İşlemi

```typescript
export class TransferMoneyUseCase {
  constructor(private uow: IUnitOfWork) {}

  async execute(request: TransferRequest): Promise<void> {
    await this.uow.executeInTransaction(async () => {
      // 1. Get source account
      const sourceAccount = await this.uow.accounts.findById(request.sourceAccountId);
      if (!sourceAccount) {
        throw new AccountNotFoundException(request.sourceAccountId);
      }

      // 2. Get target account
      const targetAccount = await this.uow.accounts.findById(request.targetAccountId);
      if (!targetAccount) {
        throw new AccountNotFoundException(request.targetAccountId);
      }

      // 3. Perform transfer (domain logic)
      sourceAccount.withdraw(request.amount);
      targetAccount.deposit(request.amount);

      // 4. Save both - atomic operation
      await this.uow.accounts.save(sourceAccount);
      await this.uow.accounts.save(targetAccount);

      // 5. Record transaction
      const transaction = Transaction.create(
        sourceAccount.id,
        targetAccount.id,
        request.amount
      );
      await this.uow.transactions.save(transaction);
    });
  }
}
```

## Factory Pattern ile UoW

```typescript
export interface IUnitOfWorkFactory {
  create(): IUnitOfWork;
}

export class UnitOfWorkFactory implements IUnitOfWorkFactory {
  constructor(private db: PrismaClient) {}

  create(): IUnitOfWork {
    return new UnitOfWork(this.db);
  }
}

// Usage in Service
export class OrderService {
  constructor(private uowFactory: IUnitOfWorkFactory) {}

  async createOrder(request: CreateOrderRequest): Promise<string> {
    const uow = this.uowFactory.create();

    return uow.executeInTransaction(async () => {
      // Use fresh UoW instance per request
      const order = Order.create(/* ... */);
      await uow.orders.save(order);
      return order.id.value;
    });
  }
}
```

## Test Doubles

```typescript
export class InMemoryUnitOfWork implements IUnitOfWork {
  readonly users = new InMemoryUserRepository();
  readonly orders = new InMemoryOrderRepository();
  readonly products = new InMemoryProductRepository();
  readonly payments = new InMemoryPaymentRepository();

  private snapshots: Map<string, any[]> = new Map();
  private inTransaction = false;

  async begin(): Promise<void> {
    this.inTransaction = true;
    // Snapshot current state
    this.snapshots.set('users', [...this.users.getAll()]);
    this.snapshots.set('orders', [...this.orders.getAll()]);
    this.snapshots.set('products', [...this.products.getAll()]);
    this.snapshots.set('payments', [...this.payments.getAll()]);
  }

  async commit(): Promise<void> {
    this.inTransaction = false;
    this.snapshots.clear();
  }

  async rollback(): Promise<void> {
    this.inTransaction = false;
    // Restore snapshots
    this.users.restore(this.snapshots.get('users') || []);
    this.orders.restore(this.snapshots.get('orders') || []);
    this.products.restore(this.snapshots.get('products') || []);
    this.payments.restore(this.snapshots.get('payments') || []);
    this.snapshots.clear();
  }

  async executeInTransaction<T>(work: () => Promise<T>): Promise<T> {
    await this.begin();
    try {
      const result = await work();
      await this.commit();
      return result;
    } catch (error) {
      await this.rollback();
      throw error;
    }
  }
}

// Test
describe('CreateOrderUseCase', () => {
  let uow: InMemoryUnitOfWork;
  let useCase: CreateOrderUseCase;

  beforeEach(() => {
    uow = new InMemoryUnitOfWork();
    useCase = new CreateOrderUseCase(uow);
  });

  it('should rollback on insufficient stock', async () => {
    // Arrange
    const product = Product.create('Test', Money.create(100), 5); // 5 in stock
    await uow.products.save(product);

    // Act & Assert
    await expect(useCase.execute({
      userId: 'user-1',
      items: [{ productId: product.id.value, quantity: 10 }] // Request 10
    })).rejects.toThrow(InsufficientStockException);

    // Stock should be unchanged (rolled back)
    const savedProduct = await uow.products.findById(product.id);
    expect(savedProduct?.stock).toBe(5);
  });

  it('should commit all changes on success', async () => {
    // Arrange
    const user = User.create(/* ... */);
    const product = Product.create('Test', Money.create(100), 10);
    await uow.users.save(user);
    await uow.products.save(product);

    // Act
    const response = await useCase.execute({
      userId: user.id.value,
      items: [{ productId: product.id.value, quantity: 3 }]
    });

    // Assert - all changes committed
    expect(response.success).toBe(true);

    const savedProduct = await uow.products.findById(product.id);
    expect(savedProduct?.stock).toBe(7); // Decreased

    const orders = await uow.orders.findByUser(user.id);
    expect(orders).toHaveLength(1);
  });
});
```

## Best Practices

1. **Her request için yeni UoW instance** - Thread safety
2. **Transaction scope'u dar tut** - Lock süresini minimize et
3. **Domain events'i commit sonrası publish et** - Consistency
4. **Nested transaction'dan kaçın** - Karmaşıklık
5. **Repository'ler UoW'dan context alsın** - Aynı transaction'ı paylaşsın

## Repository vs Unit of Work

| Aspect | Repository | Unit of Work |
|--------|------------|--------------|
| Scope | Single aggregate | Multiple aggregates |
| Transaction | Implicit | Explicit |
| Focus | Data access | Transaction management |
| Usage | CRUD operations | Cross-aggregate operations |
