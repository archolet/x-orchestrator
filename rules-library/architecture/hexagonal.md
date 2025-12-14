---
name: Hexagonal Architecture
version: 1.0
applies_to: "**/*"
priority: high
---

# Hexagonal Architecture (Ports & Adapters)

## Temel Konsept

Uygulamayı dış dünyadan izole et. Portlar (interfaces) ve Adaptörler (implementations) ile bağlan.

```
                    ┌─────────────────────────────────────┐
                    │         Driving Adapters            │
                    │   (Primary/Input)                   │
                    │   REST API, CLI, GUI, Tests         │
                    └───────────────┬─────────────────────┘
                                    │
                                    ▼
                    ┌─────────────────────────────────────┐
                    │         Driving Ports               │
                    │   (Input Interfaces)                │
                    │   IOrderService, IUserService       │
                    └───────────────┬─────────────────────┘
                                    │
                    ┌───────────────▼─────────────────────┐
                    │                                     │
                    │      APPLICATION CORE               │
                    │                                     │
                    │   ┌─────────────────────────────┐   │
                    │   │      Domain Model           │   │
                    │   │   Entities, Value Objects   │   │
                    │   │   Domain Services           │   │
                    │   └─────────────────────────────┘   │
                    │                                     │
                    │   ┌─────────────────────────────┐   │
                    │   │   Application Services      │   │
                    │   │   Use Cases, Orchestration  │   │
                    │   └─────────────────────────────┘   │
                    │                                     │
                    └───────────────┬─────────────────────┘
                                    │
                    ┌───────────────▼─────────────────────┐
                    │         Driven Ports                │
                    │   (Output Interfaces)               │
                    │   IUserRepository, IEmailService    │
                    └───────────────┬─────────────────────┘
                                    │
                                    ▼
                    ┌─────────────────────────────────────┐
                    │         Driven Adapters             │
                    │   (Secondary/Output)                │
                    │   PostgreSQL, SendGrid, S3          │
                    └─────────────────────────────────────┘
```

## Folder Structure

```
src/
├── Core/                           # Hexagon içi
│   ├── Domain/                     # İş mantığı
│   │   ├── Entities/
│   │   ├── ValueObjects/
│   │   ├── Events/
│   │   └── Services/
│   ├── Application/                # Use cases
│   │   ├── Services/
│   │   ├── DTOs/
│   │   └── Ports/                  # Interface tanımları
│   │       ├── Driving/            # Input ports
│   │       └── Driven/             # Output ports
│   └── Shared/                     # Ortak tipler
├── Adapters/                       # Hexagon dışı
│   ├── Driving/                    # Input adapters
│   │   ├── Api/
│   │   │   └── Controllers/
│   │   ├── Cli/
│   │   └── GraphQL/
│   └── Driven/                     # Output adapters
│       ├── Persistence/
│       │   ├── Repositories/
│       │   └── Mappers/
│       ├── Messaging/
│       └── ExternalServices/
└── Configuration/                  # DI, Startup
```

## Port Definitions

### Driving Ports (Input)

```typescript
// Core/Application/Ports/Driving/IOrderService.ts
export interface IOrderService {
  createOrder(request: CreateOrderRequest): Promise<CreateOrderResponse>;
  cancelOrder(orderId: string): Promise<void>;
  getOrderStatus(orderId: string): Promise<OrderStatusResponse>;
}

// Core/Application/Ports/Driving/IUserService.ts
export interface IUserService {
  register(request: RegisterUserRequest): Promise<RegisterUserResponse>;
  authenticate(request: AuthRequest): Promise<AuthResponse>;
  updateProfile(userId: string, request: UpdateProfileRequest): Promise<void>;
}
```

### Driven Ports (Output)

```typescript
// Core/Application/Ports/Driven/IUserRepository.ts
export interface IUserRepository {
  findById(id: UserId): Promise<User | null>;
  findByEmail(email: Email): Promise<User | null>;
  save(user: User): Promise<void>;
  delete(id: UserId): Promise<void>;
}

// Core/Application/Ports/Driven/IEmailService.ts
export interface IEmailService {
  sendWelcomeEmail(to: Email, userName: string): Promise<void>;
  sendPasswordReset(to: Email, resetToken: string): Promise<void>;
  sendOrderConfirmation(to: Email, order: OrderSummary): Promise<void>;
}

// Core/Application/Ports/Driven/IPaymentGateway.ts
export interface IPaymentGateway {
  charge(amount: Money, paymentMethod: PaymentMethodToken): Promise<PaymentResult>;
  refund(transactionId: string, amount: Money): Promise<RefundResult>;
}
```

## Application Service (Use Case)

```typescript
// Core/Application/Services/OrderService.ts
export class OrderService implements IOrderService {
  constructor(
    private userRepository: IUserRepository,
    private orderRepository: IOrderRepository,
    private paymentGateway: IPaymentGateway,
    private emailService: IEmailService,
    private eventBus: IEventBus
  ) {}

  async createOrder(request: CreateOrderRequest): Promise<CreateOrderResponse> {
    // 1. Load user
    const user = await this.userRepository.findById(UserId.create(request.userId));
    if (!user) {
      throw new UserNotFoundException(request.userId);
    }

    // 2. Create order (domain logic)
    const order = Order.create(
      user.id,
      request.items.map(i => OrderItem.create(i.productId, i.quantity, i.price))
    );

    // 3. Process payment (through port)
    const paymentResult = await this.paymentGateway.charge(
      order.totalAmount,
      request.paymentMethodToken
    );

    if (!paymentResult.success) {
      throw new PaymentFailedException(paymentResult.error);
    }

    order.markAsPaid(paymentResult.transactionId);

    // 4. Persist
    await this.orderRepository.save(order);

    // 5. Side effects
    await this.emailService.sendOrderConfirmation(user.email, order.toSummary());
    await this.eventBus.publish(order.domainEvents);

    return CreateOrderResponse.success(order.id.value);
  }
}
```

## Adapter Implementations

### Driving Adapter (REST API)

```typescript
// Adapters/Driving/Api/Controllers/OrderController.ts
@Controller('orders')
export class OrderController {
  constructor(
    @Inject('IOrderService') private orderService: IOrderService
  ) {}

  @Post()
  @UseGuards(AuthGuard)
  async create(
    @Body() dto: CreateOrderDto,
    @User() user: AuthenticatedUser
  ): Promise<OrderResponseDto> {
    const request: CreateOrderRequest = {
      userId: user.id,
      items: dto.items,
      paymentMethodToken: dto.paymentToken
    };

    const response = await this.orderService.createOrder(request);
    return OrderResponseDto.from(response);
  }

  @Delete(':id')
  @UseGuards(AuthGuard)
  async cancel(@Param('id') id: string): Promise<void> {
    await this.orderService.cancelOrder(id);
  }
}
```

### Driving Adapter (CLI)

```typescript
// Adapters/Driving/Cli/OrderCommands.ts
export class OrderCommands {
  constructor(
    @Inject('IOrderService') private orderService: IOrderService
  ) {}

  @Command('order:create')
  async createOrder(
    @Option('user') userId: string,
    @Option('product') productId: string,
    @Option('quantity') quantity: number
  ): Promise<void> {
    const request: CreateOrderRequest = {
      userId,
      items: [{ productId, quantity, price: await this.getPrice(productId) }],
      paymentMethodToken: await this.promptForPayment()
    };

    const response = await this.orderService.createOrder(request);
    console.log(`Order created: ${response.orderId}`);
  }
}
```

### Driven Adapter (Database)

```typescript
// Adapters/Driven/Persistence/Repositories/PostgresUserRepository.ts
export class PostgresUserRepository implements IUserRepository {
  constructor(private db: PrismaClient) {}

  async findById(id: UserId): Promise<User | null> {
    const data = await this.db.user.findUnique({
      where: { id: id.value },
      include: { profile: true }
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
    await this.db.user.delete({ where: { id: id.value } });
  }
}
```

### Driven Adapter (External Service)

```typescript
// Adapters/Driven/ExternalServices/StripePaymentGateway.ts
export class StripePaymentGateway implements IPaymentGateway {
  private stripe: Stripe;

  constructor(apiKey: string) {
    this.stripe = new Stripe(apiKey);
  }

  async charge(amount: Money, paymentMethod: PaymentMethodToken): Promise<PaymentResult> {
    try {
      const paymentIntent = await this.stripe.paymentIntents.create({
        amount: amount.cents,
        currency: amount.currency.toLowerCase(),
        payment_method: paymentMethod.value,
        confirm: true
      });

      return {
        success: true,
        transactionId: paymentIntent.id
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  async refund(transactionId: string, amount: Money): Promise<RefundResult> {
    const refund = await this.stripe.refunds.create({
      payment_intent: transactionId,
      amount: amount.cents
    });

    return {
      success: refund.status === 'succeeded',
      refundId: refund.id
    };
  }
}

// Adapters/Driven/ExternalServices/SendGridEmailService.ts
export class SendGridEmailService implements IEmailService {
  constructor(private apiKey: string, private templates: EmailTemplates) {}

  async sendWelcomeEmail(to: Email, userName: string): Promise<void> {
    await sgMail.send({
      to: to.value,
      from: 'noreply@app.com',
      templateId: this.templates.welcome,
      dynamicTemplateData: { userName }
    });
  }

  async sendOrderConfirmation(to: Email, order: OrderSummary): Promise<void> {
    await sgMail.send({
      to: to.value,
      from: 'orders@app.com',
      templateId: this.templates.orderConfirmation,
      dynamicTemplateData: {
        orderId: order.id,
        items: order.items,
        total: order.total.formatted
      }
    });
  }
}
```

## Dependency Injection Configuration

```typescript
// Configuration/DependencyInjection.ts
export function configureDependencies(container: Container): void {
  // Driven Adapters (Output)
  container.register<IUserRepository>(
    'IUserRepository',
    new PostgresUserRepository(prismaClient)
  );

  container.register<IOrderRepository>(
    'IOrderRepository',
    new PostgresOrderRepository(prismaClient)
  );

  container.register<IPaymentGateway>(
    'IPaymentGateway',
    new StripePaymentGateway(config.stripe.apiKey)
  );

  container.register<IEmailService>(
    'IEmailService',
    new SendGridEmailService(config.sendgrid.apiKey, emailTemplates)
  );

  // Application Services (Use Cases)
  container.register<IOrderService>(
    'IOrderService',
    new OrderService(
      container.resolve('IUserRepository'),
      container.resolve('IOrderRepository'),
      container.resolve('IPaymentGateway'),
      container.resolve('IEmailService'),
      container.resolve('IEventBus')
    )
  );
}
```

## Testing with Hexagonal

```typescript
// Test doubles for driven ports
class InMemoryUserRepository implements IUserRepository {
  private users: Map<string, User> = new Map();

  async findById(id: UserId): Promise<User | null> {
    return this.users.get(id.value) || null;
  }

  async save(user: User): Promise<void> {
    this.users.set(user.id.value, user);
  }

  // ... other methods
}

class MockPaymentGateway implements IPaymentGateway {
  shouldSucceed = true;
  lastCharge: { amount: Money; token: PaymentMethodToken } | null = null;

  async charge(amount: Money, token: PaymentMethodToken): Promise<PaymentResult> {
    this.lastCharge = { amount, token };
    return this.shouldSucceed
      ? { success: true, transactionId: 'test-tx-123' }
      : { success: false, error: 'Test failure' };
  }
}

// Unit test for application service
describe('OrderService', () => {
  let orderService: IOrderService;
  let userRepo: InMemoryUserRepository;
  let orderRepo: InMemoryOrderRepository;
  let paymentGateway: MockPaymentGateway;
  let emailService: MockEmailService;

  beforeEach(() => {
    userRepo = new InMemoryUserRepository();
    orderRepo = new InMemoryOrderRepository();
    paymentGateway = new MockPaymentGateway();
    emailService = new MockEmailService();

    orderService = new OrderService(
      userRepo,
      orderRepo,
      paymentGateway,
      emailService,
      new InMemoryEventBus()
    );
  });

  it('should create order when payment succeeds', async () => {
    // Arrange
    const user = User.create(Email.create('test@test.com').value, UserName.create('Test').value);
    await userRepo.save(user);
    paymentGateway.shouldSucceed = true;

    // Act
    const response = await orderService.createOrder({
      userId: user.id.value,
      items: [{ productId: 'prod-1', quantity: 2, price: 1000 }],
      paymentMethodToken: PaymentMethodToken.create('pm_test')
    });

    // Assert
    expect(response.success).toBe(true);
    expect(paymentGateway.lastCharge).not.toBeNull();
    expect(emailService.sentEmails).toHaveLength(1);
  });
});
```

## Key Benefits

1. **Testability** - Core'u mock'larla test et
2. **Flexibility** - Adapter'ları kolayca değiştir
3. **Independence** - Framework agnostic core
4. **Clarity** - Net bağımlılık yönü

## Hexagonal vs Clean vs Onion

| Özellik | Hexagonal | Clean | Onion |
|---------|-----------|-------|-------|
| Odak | Ports & Adapters | Use Cases | Domain |
| Layers | 2 (Inside/Outside) | 4 | 4 |
| Complexity | Medium | High | Medium |
| Best For | API services | Complex apps | DDD projects |
