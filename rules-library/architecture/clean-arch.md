---
name: Clean Architecture
version: 1.0
applies_to: "**/*"
priority: high
---

# Clean Architecture Rules

## Temel Prensipler

### 1. Dependency Rule
Bağımlılıklar her zaman içeri doğru akmalı:
- Outer layers depend on inner layers
- Inner layers don't know about outer layers

```
┌─────────────────────────────────────────────────────────┐
│                    Frameworks & Drivers                  │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Interface Adapters                   │   │
│  │  ┌─────────────────────────────────────────┐    │   │
│  │  │           Application Layer             │    │   │
│  │  │  ┌─────────────────────────────────┐   │    │   │
│  │  │  │         Domain Layer            │   │    │   │
│  │  │  │       (Entities)               │   │    │   │
│  │  │  └─────────────────────────────────┘   │    │   │
│  │  └─────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### 2. Layer Responsibilities

#### Domain Layer (Entities)
- Enterprise business rules
- Entity definitions
- Value objects
- Domain events
- **NO framework dependencies**

#### Application Layer (Use Cases)
- Application-specific business rules
- Orchestrates entities
- Defines interfaces for outer layers
- Contains DTOs
- **NO framework dependencies**

#### Interface Adapters
- Controllers, Presenters, Gateways
- Converts data between layers
- Implements application interfaces

#### Frameworks & Drivers
- Web frameworks
- Databases
- External services
- UI components

## Folder Structure

```
src/
├── Core/                    # Domain + Application
│   ├── Domain/
│   │   ├── Entities/
│   │   ├── ValueObjects/
│   │   ├── Events/
│   │   └── Exceptions/
│   └── Application/
│       ├── UseCases/
│       ├── Interfaces/
│       ├── DTOs/
│       └── Services/
├── Infrastructure/          # Interface Adapters + Drivers
│   ├── Persistence/
│   ├── ExternalServices/
│   └── Messaging/
└── Presentation/           # UI/API Layer
    ├── Api/
    │   └── Controllers/
    └── Web/
        └── Pages/
```

## Use Case Implementation

```typescript
// Application Layer
export interface ICreateUserUseCase {
  execute(request: CreateUserRequest): Promise<CreateUserResponse>;
}

export class CreateUserUseCase implements ICreateUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private emailService: IEmailService
  ) {}

  async execute(request: CreateUserRequest): Promise<CreateUserResponse> {
    // 1. Validate
    const email = Email.create(request.email);
    if (email.isFailure) {
      return CreateUserResponse.fail(email.error);
    }

    // 2. Check business rules
    const existingUser = await this.userRepository.findByEmail(email.value);
    if (existingUser) {
      return CreateUserResponse.fail('Email already exists');
    }

    // 3. Create entity
    const user = User.create(email.value, request.name);

    // 4. Persist
    await this.userRepository.save(user);

    // 5. Side effects
    await this.emailService.sendWelcome(user.email);

    // 6. Return
    return CreateUserResponse.success(UserDTO.fromEntity(user));
  }
}
```

## Interface Definitions

```typescript
// Application Layer: Interface
export interface IUserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: Email): Promise<User | null>;
  save(user: User): Promise<void>;
}

// Infrastructure Layer: Implementation
export class PostgresUserRepository implements IUserRepository {
  constructor(private db: PrismaClient) {}

  async findById(id: string): Promise<User | null> {
    const data = await this.db.user.findUnique({ where: { id } });
    return data ? UserMapper.toDomain(data) : null;
  }
}
```

## Controller Implementation

```typescript
// Presentation Layer
@Controller('users')
export class UserController {
  constructor(private createUserUseCase: ICreateUserUseCase) {}

  @Post()
  async create(@Body() dto: CreateUserDto): Promise<UserResponseDto> {
    const request = new CreateUserRequest(dto.email, dto.name);
    const result = await this.createUserUseCase.execute(request);

    if (result.isFailure) {
      throw new BadRequestException(result.error);
    }

    return result.value;
  }
}
```

## Dependency Injection

```typescript
// DI Container Configuration
container.register<IUserRepository>('UserRepository', PostgresUserRepository);
container.register<IEmailService>('EmailService', SendGridEmailService);
container.register<ICreateUserUseCase>('CreateUserUseCase', CreateUserUseCase);
```

## Testing

```typescript
// Use Case Test (Unit)
describe('CreateUserUseCase', () => {
  let useCase: CreateUserUseCase;
  let mockUserRepo: jest.Mocked<IUserRepository>;
  let mockEmailService: jest.Mocked<IEmailService>;

  beforeEach(() => {
    mockUserRepo = createMock<IUserRepository>();
    mockEmailService = createMock<IEmailService>();
    useCase = new CreateUserUseCase(mockUserRepo, mockEmailService);
  });

  it('should create user successfully', async () => {
    mockUserRepo.findByEmail.mockResolvedValue(null);

    const result = await useCase.execute({
      email: 'test@example.com',
      name: 'Test User'
    });

    expect(result.isSuccess).toBe(true);
    expect(mockUserRepo.save).toHaveBeenCalled();
  });
});
```
