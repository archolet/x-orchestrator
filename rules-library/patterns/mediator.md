---
name: Mediator Pattern
version: 1.0
applies_to: "**/*"
priority: medium
---

# Mediator Pattern

## Amaç

Nesneler arası doğrudan iletişimi ortadan kaldır. Tüm iletişim mediator üzerinden geçsin. Loose coupling sağlar.

## Temel Yapı

```
Without Mediator:                    With Mediator:

    ┌───┐   ┌───┐                       ┌───┐   ┌───┐
    │ A │◄─►│ B │                       │ A │   │ B │
    └─┬─┘   └─┬─┘                       └─┬─┘   └─┬─┘
      │       │                           │       │
      │  ┌───┐│                           ▼       ▼
      └─►│ C │◄┘                     ┌───────────────┐
         └─┬─┘                       │   Mediator    │
           │                         └───────────────┘
           ▼                              ▲       ▲
         ┌───┐                         ┌──┘       └──┐
         │ D │                       ┌─┴─┐       ┌─┴─┐
         └───┘                       │ C │       │ D │
                                     └───┘       └───┘
    N*(N-1) connections              N connections
```

## MediatR Style Implementation

### Request/Response Pattern

```typescript
// Base interfaces
export interface IRequest<TResponse> {
  readonly _responseType?: TResponse; // Phantom type for inference
}

export interface IRequestHandler<TRequest extends IRequest<TResponse>, TResponse> {
  handle(request: TRequest): Promise<TResponse>;
}

export interface IMediator {
  send<TResponse>(request: IRequest<TResponse>): Promise<TResponse>;
}
```

### Command Example

```typescript
// Command (Request with no meaningful response)
export class CreateUserCommand implements IRequest<string> {
  constructor(
    public readonly email: string,
    public readonly name: string,
    public readonly password: string
  ) {}
}

// Handler
export class CreateUserHandler implements IRequestHandler<CreateUserCommand, string> {
  constructor(
    private userRepository: IUserRepository,
    private passwordHasher: IPasswordHasher
  ) {}

  async handle(command: CreateUserCommand): Promise<string> {
    // Validate
    const email = Email.create(command.email);
    if (email.isFailure) {
      throw new ValidationException(email.error);
    }

    // Check uniqueness
    const existing = await this.userRepository.findByEmail(email.value);
    if (existing) {
      throw new DuplicateEmailException(command.email);
    }

    // Create user
    const user = User.create(
      email.value,
      UserName.create(command.name).value,
      await this.passwordHasher.hash(command.password)
    );

    await this.userRepository.save(user);
    return user.id.value;
  }
}
```

### Query Example

```typescript
// Query
export class GetUserByIdQuery implements IRequest<UserDto | null> {
  constructor(public readonly userId: string) {}
}

// Handler
export class GetUserByIdHandler implements IRequestHandler<GetUserByIdQuery, UserDto | null> {
  constructor(private userRepository: IUserRepository) {}

  async handle(query: GetUserByIdQuery): Promise<UserDto | null> {
    const user = await this.userRepository.findById(UserId.create(query.userId));
    return user ? UserDto.from(user) : null;
  }
}
```

## Mediator Implementation

```typescript
type HandlerConstructor = new (...args: any[]) => IRequestHandler<any, any>;

export class Mediator implements IMediator {
  private handlers: Map<string, IRequestHandler<any, any>> = new Map();

  constructor(private container: Container) {}

  register<TRequest extends IRequest<TResponse>, TResponse>(
    requestType: new (...args: any[]) => TRequest,
    handlerType: new (...args: any[]) => IRequestHandler<TRequest, TResponse>
  ): void {
    const handler = this.container.resolve(handlerType);
    this.handlers.set(requestType.name, handler);
  }

  async send<TResponse>(request: IRequest<TResponse>): Promise<TResponse> {
    const requestName = request.constructor.name;
    const handler = this.handlers.get(requestName);

    if (!handler) {
      throw new HandlerNotFoundException(requestName);
    }

    return handler.handle(request);
  }
}
```

## Notification Pattern

```typescript
// Notification - multiple handlers
export interface INotification {}

export interface INotificationHandler<TNotification extends INotification> {
  handle(notification: TNotification): Promise<void>;
}

// Notification example
export class UserCreatedNotification implements INotification {
  constructor(
    public readonly userId: string,
    public readonly email: string,
    public readonly name: string
  ) {}
}

// Multiple handlers for same notification
export class SendWelcomeEmailHandler implements INotificationHandler<UserCreatedNotification> {
  constructor(private emailService: IEmailService) {}

  async handle(notification: UserCreatedNotification): Promise<void> {
    await this.emailService.sendWelcome(notification.email, notification.name);
  }
}

export class CreateUserProfileHandler implements INotificationHandler<UserCreatedNotification> {
  constructor(private profileRepository: IProfileRepository) {}

  async handle(notification: UserCreatedNotification): Promise<void> {
    const profile = Profile.createDefault(notification.userId);
    await this.profileRepository.save(profile);
  }
}

export class TrackUserCreationHandler implements INotificationHandler<UserCreatedNotification> {
  constructor(private analytics: IAnalyticsService) {}

  async handle(notification: UserCreatedNotification): Promise<void> {
    await this.analytics.track('user_created', {
      userId: notification.userId,
      timestamp: new Date()
    });
  }
}

// Mediator with publish
export interface IMediator {
  send<TResponse>(request: IRequest<TResponse>): Promise<TResponse>;
  publish(notification: INotification): Promise<void>;
}

export class Mediator implements IMediator {
  private notificationHandlers: Map<string, INotificationHandler<any>[]> = new Map();

  async publish(notification: INotification): Promise<void> {
    const notificationName = notification.constructor.name;
    const handlers = this.notificationHandlers.get(notificationName) || [];

    // Run all handlers (can be parallel or sequential)
    await Promise.all(
      handlers.map(handler => handler.handle(notification))
    );
  }
}
```

## Pipeline Behaviors

```typescript
// Behavior interface
export interface IPipelineBehavior<TRequest, TResponse> {
  handle(
    request: TRequest,
    next: () => Promise<TResponse>
  ): Promise<TResponse>;
}

// Logging behavior
export class LoggingBehavior<TRequest, TResponse>
  implements IPipelineBehavior<TRequest, TResponse> {

  constructor(private logger: ILogger) {}

  async handle(request: TRequest, next: () => Promise<TResponse>): Promise<TResponse> {
    const requestName = request.constructor.name;
    this.logger.info(`Handling ${requestName}`, { request });

    const start = Date.now();
    try {
      const response = await next();
      const duration = Date.now() - start;
      this.logger.info(`Handled ${requestName} in ${duration}ms`, { response });
      return response;
    } catch (error) {
      this.logger.error(`Error handling ${requestName}`, { error });
      throw error;
    }
  }
}

// Validation behavior
export class ValidationBehavior<TRequest, TResponse>
  implements IPipelineBehavior<TRequest, TResponse> {

  constructor(private validators: IValidator<TRequest>[]) {}

  async handle(request: TRequest, next: () => Promise<TResponse>): Promise<TResponse> {
    const errors: ValidationError[] = [];

    for (const validator of this.validators) {
      const result = await validator.validate(request);
      if (!result.isValid) {
        errors.push(...result.errors);
      }
    }

    if (errors.length > 0) {
      throw new ValidationException(errors);
    }

    return next();
  }
}

// Transaction behavior
export class TransactionBehavior<TRequest, TResponse>
  implements IPipelineBehavior<TRequest, TResponse> {

  constructor(private uow: IUnitOfWork) {}

  async handle(request: TRequest, next: () => Promise<TResponse>): Promise<TResponse> {
    return this.uow.executeInTransaction(async () => {
      return next();
    });
  }
}

// Mediator with pipeline
export class Mediator implements IMediator {
  private behaviors: IPipelineBehavior<any, any>[] = [];

  addBehavior(behavior: IPipelineBehavior<any, any>): void {
    this.behaviors.push(behavior);
  }

  async send<TResponse>(request: IRequest<TResponse>): Promise<TResponse> {
    const handler = this.getHandler(request);

    // Build pipeline
    let index = -1;
    const next = async (): Promise<TResponse> => {
      index++;
      if (index < this.behaviors.length) {
        return this.behaviors[index].handle(request, next);
      }
      return handler.handle(request);
    };

    return next();
  }
}
```

## Controller Integration

```typescript
@Controller('users')
export class UserController {
  constructor(private mediator: IMediator) {}

  @Post()
  async create(@Body() dto: CreateUserDto): Promise<{ id: string }> {
    const command = new CreateUserCommand(dto.email, dto.name, dto.password);
    const id = await this.mediator.send(command);
    return { id };
  }

  @Get(':id')
  async getById(@Param('id') id: string): Promise<UserDto> {
    const query = new GetUserByIdQuery(id);
    const user = await this.mediator.send(query);

    if (!user) {
      throw new NotFoundException(`User ${id} not found`);
    }

    return user;
  }

  @Delete(':id')
  async delete(@Param('id') id: string): Promise<void> {
    const command = new DeleteUserCommand(id);
    await this.mediator.send(command);
  }
}
```

## Registration with DI

```typescript
// Configuration
export function configureMediator(container: Container): IMediator {
  const mediator = new Mediator(container);

  // Register request handlers
  mediator.register(CreateUserCommand, CreateUserHandler);
  mediator.register(GetUserByIdQuery, GetUserByIdHandler);
  mediator.register(DeleteUserCommand, DeleteUserHandler);
  mediator.register(UpdateUserCommand, UpdateUserHandler);

  // Register notification handlers
  mediator.registerNotification(UserCreatedNotification, [
    SendWelcomeEmailHandler,
    CreateUserProfileHandler,
    TrackUserCreationHandler
  ]);

  // Register pipeline behaviors (order matters!)
  mediator.addBehavior(new LoggingBehavior(container.resolve(ILogger)));
  mediator.addBehavior(new ValidationBehavior(validators));
  mediator.addBehavior(new TransactionBehavior(container.resolve(IUnitOfWork)));

  return mediator;
}
```

## Benefits

| Benefit | Description |
|---------|-------------|
| Decoupling | Controllers don't know handlers |
| Single Responsibility | One handler per request |
| Cross-Cutting Concerns | Pipeline behaviors |
| Testability | Handlers are isolated |
| CQRS Ready | Natural separation |

## When to Use

- **Use**: Complex applications, CQRS architecture, many cross-cutting concerns
- **Avoid**: Simple CRUD, small teams, over-engineering risk

## Comparison with Direct Injection

```typescript
// Direct injection (simpler apps)
class UserController {
  constructor(
    private createUserUseCase: CreateUserUseCase,
    private getUserUseCase: GetUserUseCase,
    private deleteUserUseCase: DeleteUserUseCase
  ) {}
}

// Mediator (complex apps)
class UserController {
  constructor(private mediator: IMediator) {}
}
```
