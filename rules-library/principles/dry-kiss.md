---
name: DRY & KISS Principles
version: 1.0
applies_to: "**/*"
priority: high
---

# DRY & KISS Principles

## DRY - Don't Repeat Yourself

Her bilgi parçası sistemde tek ve kesin bir temsile sahip olmalı.

### Bad Example - Code Duplication

```typescript
// Bad: Aynı validation logic 3 yerde
class UserController {
  createUser(dto: CreateUserDto) {
    if (!dto.email || !dto.email.includes('@')) {
      throw new Error('Invalid email');
    }
    if (!dto.password || dto.password.length < 8) {
      throw new Error('Password too short');
    }
    // ...
  }
}

class AdminController {
  createAdmin(dto: CreateAdminDto) {
    if (!dto.email || !dto.email.includes('@')) {  // Duplicate!
      throw new Error('Invalid email');
    }
    if (!dto.password || dto.password.length < 8) {  // Duplicate!
      throw new Error('Password too short');
    }
    // ...
  }
}

class AuthService {
  register(dto: RegisterDto) {
    if (!dto.email || !dto.email.includes('@')) {  // Duplicate!
      throw new Error('Invalid email');
    }
    if (!dto.password || dto.password.length < 8) {  // Duplicate!
      throw new Error('Password too short');
    }
    // ...
  }
}
```

### Good Example - Extract Common Logic

```typescript
// Good: Single source of truth
class Email extends ValueObject<string> {
  private static readonly PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  private constructor(value: string) {
    super(value);
  }

  static create(value: string): Result<Email> {
    if (!value || !this.PATTERN.test(value)) {
      return Result.fail('Invalid email format');
    }
    return Result.ok(new Email(value));
  }
}

class Password extends ValueObject<string> {
  private static readonly MIN_LENGTH = 8;

  static create(value: string): Result<Password> {
    if (!value || value.length < this.MIN_LENGTH) {
      return Result.fail(`Password must be at least ${this.MIN_LENGTH} characters`);
    }
    return Result.ok(new Password(value));
  }
}

// Now all controllers use same validation
class UserController {
  createUser(dto: CreateUserDto) {
    const email = Email.create(dto.email);
    const password = Password.create(dto.password);

    if (email.isFailure) throw new ValidationError(email.error);
    if (password.isFailure) throw new ValidationError(password.error);
    // ...
  }
}
```

### DRY Uygulama Alanları

#### 1. Business Logic

```typescript
// Bad: Tax calculation scattered
class OrderService {
  calculateTotal(order: Order): Money {
    const tax = order.subtotal.amount * 0.18; // Magic number!
    return order.subtotal.add(Money.create(tax));
  }
}

class InvoiceService {
  generateInvoice(order: Order): Invoice {
    const tax = order.subtotal.amount * 0.18; // Duplicate!
    // ...
  }
}

// Good: Centralized tax calculation
class TaxCalculator {
  private static readonly TAX_RATE = 0.18;

  static calculate(amount: Money): Money {
    return Money.create(amount.amount * this.TAX_RATE);
  }
}
```

#### 2. Configuration

```typescript
// Bad: Hardcoded values
const API_URL = 'https://api.example.com';  // In file1.ts
const apiUrl = 'https://api.example.com';   // In file2.ts

// Good: Single config source
// config.ts
export const config = {
  api: {
    baseUrl: process.env.API_URL || 'https://api.example.com',
    timeout: 5000
  }
};

// Usage everywhere
import { config } from './config';
fetch(config.api.baseUrl + '/users');
```

#### 3. Database Queries

```typescript
// Bad: Same query in multiple places
class UserService {
  async getActiveUsers(): Promise<User[]> {
    return this.db.query(`
      SELECT * FROM users
      WHERE status = 'active'
      AND deleted_at IS NULL
      ORDER BY created_at DESC
    `);
  }
}

class ReportService {
  async getActiveUserCount(): Promise<number> {
    const result = await this.db.query(`
      SELECT COUNT(*) FROM users
      WHERE status = 'active'
      AND deleted_at IS NULL  -- Duplicate condition!
    `);
    return result[0].count;
  }
}

// Good: Query builder or repository
class UserRepository {
  private activeUsersQuery() {
    return this.db.users
      .where('status', 'active')
      .whereNull('deleted_at');
  }

  async getActiveUsers(): Promise<User[]> {
    return this.activeUsersQuery()
      .orderBy('created_at', 'desc')
      .get();
  }

  async getActiveUserCount(): Promise<number> {
    return this.activeUsersQuery().count();
  }
}
```

---

## KISS - Keep It Simple, Stupid

En basit çözüm genellikle en iyi çözümdür.

### Bad Example - Over-Engineering

```typescript
// Bad: Unnecessary abstraction for simple task
interface IStringProcessor {
  process(input: string): string;
}

abstract class BaseStringProcessor implements IStringProcessor {
  protected abstract doProcess(input: string): string;

  process(input: string): string {
    this.validateInput(input);
    const result = this.doProcess(input);
    this.logResult(result);
    return result;
  }

  private validateInput(input: string): void {
    if (typeof input !== 'string') throw new Error('Invalid input');
  }

  private logResult(result: string): void {
    console.log(`Processed: ${result}`);
  }
}

class UpperCaseProcessor extends BaseStringProcessor {
  protected doProcess(input: string): string {
    return input.toUpperCase();
  }
}

class StringProcessorFactory {
  static create(type: 'upper' | 'lower'): IStringProcessor {
    switch (type) {
      case 'upper': return new UpperCaseProcessor();
      case 'lower': return new LowerCaseProcessor();
      default: throw new Error('Unknown type');
    }
  }
}

// Usage
const processor = StringProcessorFactory.create('upper');
const result = processor.process('hello');
```

### Good Example - Simple Solution

```typescript
// Good: Just do what's needed
const toUpperCase = (str: string): string => str.toUpperCase();
const toLowerCase = (str: string): string => str.toLowerCase();

// Usage
const result = toUpperCase('hello');
```

### KISS Anti-Patterns

#### 1. Premature Abstraction

```typescript
// Bad: Generic repository for one entity
interface IRepository<T, TId> {
  findById(id: TId): Promise<T | null>;
  findAll(): Promise<T[]>;
  findBySpec(spec: ISpecification<T>): Promise<T[]>;
  save(entity: T): Promise<void>;
  delete(id: TId): Promise<void>;
  count(): Promise<number>;
  exists(id: TId): Promise<boolean>;
  // ... 10 more methods
}

class UserRepository implements IRepository<User, UserId> {
  // Implements all methods even if only findById is used
}

// Good: Start simple, extract when needed
class UserRepository {
  async findById(id: string): Promise<User | null> {
    return this.db.users.findUnique({ where: { id } });
  }

  async save(user: User): Promise<void> {
    await this.db.users.upsert({
      where: { id: user.id },
      create: user,
      update: user
    });
  }
}
```

#### 2. Over-Configurable Systems

```typescript
// Bad: Configuration for everything
interface ButtonConfig {
  text: string;
  color: string;
  hoverColor: string;
  activeColor: string;
  disabledColor: string;
  borderRadius: number;
  borderWidth: number;
  borderColor: string;
  fontSize: number;
  fontWeight: string;
  padding: { top: number; right: number; bottom: number; left: number };
  margin: { top: number; right: number; bottom: number; left: number };
  shadow: { x: number; y: number; blur: number; color: string };
  animation: { type: string; duration: number; easing: string };
  // ... 20 more options
}

// Good: Sensible defaults with variants
type ButtonVariant = 'primary' | 'secondary' | 'danger';
type ButtonSize = 'sm' | 'md' | 'lg';

interface ButtonProps {
  text: string;
  variant?: ButtonVariant;  // default: 'primary'
  size?: ButtonSize;        // default: 'md'
  disabled?: boolean;       // default: false
}
```

#### 3. Complex Conditionals

```typescript
// Bad: Nested nightmare
function getDiscount(user: User, order: Order): number {
  if (user.isPremium) {
    if (order.total > 1000) {
      if (order.items.length > 5) {
        if (isHoliday()) {
          return 0.25;
        } else {
          return 0.20;
        }
      } else {
        if (isHoliday()) {
          return 0.15;
        } else {
          return 0.10;
        }
      }
    } else {
      return 0.05;
    }
  } else {
    if (order.total > 500) {
      return 0.05;
    }
    return 0;
  }
}

// Good: Early returns and clear logic
function getDiscount(user: User, order: Order): number {
  const baseDiscount = user.isPremium ? 0.05 : 0;
  const volumeDiscount = order.total > 1000 ? 0.05 : 0;
  const bulkDiscount = order.items.length > 5 ? 0.05 : 0;
  const holidayBonus = isHoliday() ? 0.05 : 0;

  const totalDiscount = baseDiscount + volumeDiscount + bulkDiscount + holidayBonus;
  return Math.min(totalDiscount, 0.25); // Cap at 25%
}
```

---

## DRY vs KISS Balance

### When DRY Can Hurt

```typescript
// Over-DRY: Forced reuse
function formatEntity(entity: User | Product | Order, type: string): string {
  switch (type) {
    case 'user':
      return `${(entity as User).firstName} ${(entity as User).lastName}`;
    case 'product':
      return `${(entity as Product).name} - ${(entity as Product).price}`;
    case 'order':
      return `Order #${(entity as Order).id}`;
    default:
      throw new Error('Unknown type');
  }
}

// Better: Separate functions
const formatUser = (user: User): string =>
  `${user.firstName} ${user.lastName}`;

const formatProduct = (product: Product): string =>
  `${product.name} - ${product.price}`;

const formatOrder = (order: Order): string =>
  `Order #${order.id}`;
```

### Rule of Three

```
İlk kullanım: Yaz
İkinci kullanım: Dikkat et, henüz DRY'lama
Üçüncü kullanım: Şimdi refactor et
```

---

## Quick Reference

| Principle | Yapma | Yap |
|-----------|-------|-----|
| DRY | Copy-paste | Extract & Reuse |
| DRY | Magic numbers | Named constants |
| DRY | Scattered config | Centralized config |
| KISS | Premature abstraction | Start simple |
| KISS | Over-configuration | Sensible defaults |
| KISS | Deep nesting | Early returns |
| KISS | Generic everything | Specific when needed |
| Balance | Force reuse | Rule of Three |
