---
name: CQRS Pattern
version: 1.0
applies_to: "**/*"
priority: high
---

# CQRS (Command Query Responsibility Segregation)

## Temel Konsept

Okuma (Query) ve yazma (Command) işlemlerini ayır.

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client                                   │
└─────────────────────────────────────────────────────────────────┘
                    │                           │
                    ▼                           ▼
         ┌──────────────────┐        ┌──────────────────┐
         │     Commands     │        │     Queries      │
         │  (Write Model)   │        │  (Read Model)    │
         └──────────────────┘        └──────────────────┘
                    │                           │
                    ▼                           ▼
         ┌──────────────────┐        ┌──────────────────┐
         │  Command Handler │        │  Query Handler   │
         └──────────────────┘        └──────────────────┘
                    │                           │
                    ▼                           ▼
         ┌──────────────────┐        ┌──────────────────┐
         │   Write Store    │───────▶│   Read Store     │
         │   (Normalized)   │  Sync  │  (Denormalized)  │
         └──────────────────┘        └──────────────────┘
```

## Command (Write) Side

### Command Definition

```typescript
// Commands are intentions to change state
export interface Command {
  readonly type: string;
  readonly timestamp: Date;
  readonly correlationId: string;
}

export class CreateOrderCommand implements Command {
  readonly type = 'CreateOrder';
  readonly timestamp = new Date();

  constructor(
    public readonly correlationId: string,
    public readonly customerId: string,
    public readonly items: OrderItemDto[],
    public readonly shippingAddress: AddressDto
  ) {}
}

export class CancelOrderCommand implements Command {
  readonly type = 'CancelOrder';
  readonly timestamp = new Date();

  constructor(
    public readonly correlationId: string,
    public readonly orderId: string,
    public readonly reason: string
  ) {}
}
```

### Command Handler

```typescript
export interface ICommandHandler<TCommand extends Command, TResult = void> {
  handle(command: TCommand): Promise<TResult>;
}

export class CreateOrderHandler implements ICommandHandler<CreateOrderCommand, string> {
  constructor(
    private orderRepository: IOrderRepository,
    private eventBus: IEventBus
  ) {}

  async handle(command: CreateOrderCommand): Promise<string> {
    // 1. Validate
    const customer = await this.customerRepository.findById(command.customerId);
    if (!customer) {
      throw new CustomerNotFoundException(command.customerId);
    }

    // 2. Create aggregate
    const order = Order.create(
      customer.id,
      command.items.map(i => OrderItem.create(i.productId, i.quantity, i.price)),
      Address.create(command.shippingAddress)
    );

    // 3. Persist
    await this.orderRepository.save(order);

    // 4. Publish events
    for (const event of order.domainEvents) {
      await this.eventBus.publish(event);
    }

    return order.id.value;
  }
}
```

### Command Bus

```typescript
export interface ICommandBus {
  execute<TResult>(command: Command): Promise<TResult>;
}

export class CommandBus implements ICommandBus {
  private handlers: Map<string, ICommandHandler<any, any>> = new Map();

  register<T extends Command>(type: string, handler: ICommandHandler<T, any>): void {
    this.handlers.set(type, handler);
  }

  async execute<TResult>(command: Command): Promise<TResult> {
    const handler = this.handlers.get(command.type);
    if (!handler) {
      throw new HandlerNotFoundException(command.type);
    }
    return handler.handle(command);
  }
}
```

## Query (Read) Side

### Query Definition

```typescript
export interface Query {
  readonly type: string;
}

export class GetOrderByIdQuery implements Query {
  readonly type = 'GetOrderById';

  constructor(public readonly orderId: string) {}
}

export class GetOrdersByCustomerQuery implements Query {
  readonly type = 'GetOrdersByCustomer';

  constructor(
    public readonly customerId: string,
    public readonly page: number = 1,
    public readonly pageSize: number = 20
  ) {}
}
```

### Query Handler

```typescript
export interface IQueryHandler<TQuery extends Query, TResult> {
  handle(query: TQuery): Promise<TResult>;
}

export class GetOrderByIdHandler implements IQueryHandler<GetOrderByIdQuery, OrderReadModel | null> {
  constructor(private readDb: ReadDatabase) {}

  async handle(query: GetOrderByIdQuery): Promise<OrderReadModel | null> {
    // Direct database query - no domain logic
    return this.readDb.orders.findOne({ id: query.orderId });
  }
}

export class GetOrdersByCustomerHandler
  implements IQueryHandler<GetOrdersByCustomerQuery, PaginatedResult<OrderSummaryReadModel>> {

  constructor(private readDb: ReadDatabase) {}

  async handle(query: GetOrdersByCustomerQuery): Promise<PaginatedResult<OrderSummaryReadModel>> {
    const { customerId, page, pageSize } = query;

    const [items, total] = await Promise.all([
      this.readDb.orderSummaries
        .find({ customerId })
        .skip((page - 1) * pageSize)
        .limit(pageSize)
        .toArray(),
      this.readDb.orderSummaries.countDocuments({ customerId })
    ]);

    return {
      items,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize)
    };
  }
}
```

### Query Bus

```typescript
export interface IQueryBus {
  execute<TResult>(query: Query): Promise<TResult>;
}

export class QueryBus implements IQueryBus {
  private handlers: Map<string, IQueryHandler<any, any>> = new Map();

  register<T extends Query, R>(type: string, handler: IQueryHandler<T, R>): void {
    this.handlers.set(type, handler);
  }

  async execute<TResult>(query: Query): Promise<TResult> {
    const handler = this.handlers.get(query.type);
    if (!handler) {
      throw new HandlerNotFoundException(query.type);
    }
    return handler.handle(query);
  }
}
```

## Read Model Projection

```typescript
// Event handler that updates read models
export class OrderProjection {
  constructor(private readDb: ReadDatabase) {}

  @EventHandler(OrderCreatedEvent)
  async onOrderCreated(event: OrderCreatedEvent): Promise<void> {
    const readModel: OrderReadModel = {
      id: event.orderId,
      customerId: event.customerId,
      customerName: event.customerName, // Denormalized!
      items: event.items,
      totalAmount: event.totalAmount,
      status: 'Created',
      createdAt: event.occurredOn
    };

    await this.readDb.orders.insertOne(readModel);

    // Also update summary collection
    await this.readDb.orderSummaries.insertOne({
      id: event.orderId,
      customerId: event.customerId,
      totalAmount: event.totalAmount,
      status: 'Created',
      createdAt: event.occurredOn
    });
  }

  @EventHandler(OrderStatusChangedEvent)
  async onOrderStatusChanged(event: OrderStatusChangedEvent): Promise<void> {
    await Promise.all([
      this.readDb.orders.updateOne(
        { id: event.orderId },
        { $set: { status: event.newStatus, updatedAt: event.occurredOn } }
      ),
      this.readDb.orderSummaries.updateOne(
        { id: event.orderId },
        { $set: { status: event.newStatus } }
      )
    ]);
  }
}
```

## Controller Integration

```typescript
@Controller('orders')
export class OrderController {
  constructor(
    private commandBus: ICommandBus,
    private queryBus: IQueryBus
  ) {}

  @Post()
  async create(@Body() dto: CreateOrderDto): Promise<{ orderId: string }> {
    const command = new CreateOrderCommand(
      generateCorrelationId(),
      dto.customerId,
      dto.items,
      dto.shippingAddress
    );

    const orderId = await this.commandBus.execute<string>(command);
    return { orderId };
  }

  @Get(':id')
  async getById(@Param('id') id: string): Promise<OrderReadModel> {
    const query = new GetOrderByIdQuery(id);
    const order = await this.queryBus.execute<OrderReadModel | null>(query);

    if (!order) {
      throw new NotFoundException(`Order ${id} not found`);
    }

    return order;
  }

  @Get('customer/:customerId')
  async getByCustomer(
    @Param('customerId') customerId: string,
    @Query('page') page: number = 1,
    @Query('pageSize') pageSize: number = 20
  ): Promise<PaginatedResult<OrderSummaryReadModel>> {
    const query = new GetOrdersByCustomerQuery(customerId, page, pageSize);
    return this.queryBus.execute(query);
  }
}
```

## Sync Strategies

### 1. Synchronous (Simple)
```typescript
// In command handler
await this.orderRepository.save(order);
await this.projectionService.project(order.domainEvents);
```

### 2. Asynchronous (Event-Driven)
```typescript
// Command handler publishes events
await this.eventBus.publish(order.domainEvents);

// Separate projection service subscribes
eventBus.subscribe(OrderCreatedEvent, projection.onOrderCreated);
```

### 3. Event Sourcing
```typescript
// Events are the source of truth
await this.eventStore.append(order.id, order.domainEvents);

// Read models built from event stream
const events = await this.eventStore.getEvents(orderId);
const readModel = this.buildReadModel(events);
```

## Best Practices

1. **Commands**
   - Tek bir işlem yap
   - Void veya sadece ID dön
   - İsim olarak fiil kullan (Create, Update, Delete)

2. **Queries**
   - Sadece veri oku, değiştirme
   - Optimized read models kullan
   - Caching uygula

3. **Read Models**
   - Denormalize et (join'den kaçın)
   - Query ihtiyaçlarına göre şekillendir
   - Eventual consistency kabul et

4. **Genel**
   - Basit senaryolarda CQRS kullanma (over-engineering)
   - Event Sourcing zorunlu değil
   - Read/Write oranına göre karar ver

## When to Use CQRS

| Senaryo | CQRS Gerekli mi? |
|---------|------------------|
| Read >> Write | Evet |
| Complex queries | Evet |
| Different scaling needs | Evet |
| Simple CRUD | Hayır |
| Small team | Hayır (karmaşıklık) |
