---
name: SOLID Principles
version: 1.0
applies_to: "**/*"
priority: high
---

# SOLID Prensipleri

## S - Single Responsibility Principle (SRP)

Bir sınıf sadece bir nedenden dolayı değişmeli.

### Bad Example
```typescript
class User {
  constructor(public name: string, public email: string) {}

  // User data responsibility
  save(): void {
    // Save to database
  }

  // Email responsibility
  sendEmail(message: string): void {
    // Send email
  }

  // Report responsibility
  generateReport(): string {
    // Generate user report
  }
}
```

### Good Example
```typescript
class User {
  constructor(public name: string, public email: string) {}
}

class UserRepository {
  save(user: User): void {
    // Save to database
  }
}

class EmailService {
  sendEmail(to: string, message: string): void {
    // Send email
  }
}

class UserReportGenerator {
  generate(user: User): string {
    // Generate report
  }
}
```

## O - Open/Closed Principle (OCP)

Genişlemeye açık, değişikliğe kapalı.

### Bad Example
```typescript
class PaymentProcessor {
  process(payment: Payment): void {
    if (payment.type === 'credit_card') {
      // Process credit card
    } else if (payment.type === 'paypal') {
      // Process PayPal
    } else if (payment.type === 'crypto') {
      // Process crypto - Yeni eklendi, mevcut kod değişti!
    }
  }
}
```

### Good Example
```typescript
interface PaymentMethod {
  process(amount: number): Promise<PaymentResult>;
}

class CreditCardPayment implements PaymentMethod {
  async process(amount: number): Promise<PaymentResult> {
    // Process credit card
  }
}

class PayPalPayment implements PaymentMethod {
  async process(amount: number): Promise<PaymentResult> {
    // Process PayPal
  }
}

// Yeni ödeme yöntemi - mevcut kod değişmedi!
class CryptoPayment implements PaymentMethod {
  async process(amount: number): Promise<PaymentResult> {
    // Process crypto
  }
}

class PaymentProcessor {
  async process(method: PaymentMethod, amount: number): Promise<PaymentResult> {
    return method.process(amount);
  }
}
```

## L - Liskov Substitution Principle (LSP)

Alt sınıflar, üst sınıfların yerine kullanılabilmeli.

### Bad Example
```typescript
class Rectangle {
  constructor(protected width: number, protected height: number) {}

  setWidth(width: number): void { this.width = width; }
  setHeight(height: number): void { this.height = height; }
  getArea(): number { return this.width * this.height; }
}

class Square extends Rectangle {
  setWidth(width: number): void {
    this.width = width;
    this.height = width; // LSP violation!
  }

  setHeight(height: number): void {
    this.height = height;
    this.width = height; // LSP violation!
  }
}

// Bu kod Rectangle için çalışır ama Square için beklenmedik sonuç verir
function testRectangle(rect: Rectangle): void {
  rect.setWidth(5);
  rect.setHeight(4);
  assert(rect.getArea() === 20); // Square için FAIL!
}
```

### Good Example
```typescript
interface Shape {
  getArea(): number;
}

class Rectangle implements Shape {
  constructor(private width: number, private height: number) {}
  getArea(): number { return this.width * this.height; }
}

class Square implements Shape {
  constructor(private side: number) {}
  getArea(): number { return this.side * this.side; }
}
```

## I - Interface Segregation Principle (ISP)

Küçük, spesifik interface'ler büyük, genel interface'lerden iyidir.

### Bad Example
```typescript
interface Worker {
  work(): void;
  eat(): void;
  sleep(): void;
  attendMeeting(): void;
  writeReport(): void;
}

class Robot implements Worker {
  work(): void { /* OK */ }
  eat(): void { throw new Error('Robots do not eat'); } // ISP violation!
  sleep(): void { throw new Error('Robots do not sleep'); } // ISP violation!
  attendMeeting(): void { /* OK */ }
  writeReport(): void { /* OK */ }
}
```

### Good Example
```typescript
interface Workable {
  work(): void;
}

interface Eatable {
  eat(): void;
}

interface Sleepable {
  sleep(): void;
}

interface MeetingAttendable {
  attendMeeting(): void;
}

class Human implements Workable, Eatable, Sleepable, MeetingAttendable {
  work(): void { /* ... */ }
  eat(): void { /* ... */ }
  sleep(): void { /* ... */ }
  attendMeeting(): void { /* ... */ }
}

class Robot implements Workable, MeetingAttendable {
  work(): void { /* ... */ }
  attendMeeting(): void { /* ... */ }
}
```

## D - Dependency Inversion Principle (DIP)

Yüksek seviye modüller düşük seviye modüllere bağımlı olmamalı. İkisi de soyutlamalara bağımlı olmalı.

### Bad Example
```typescript
class MySQLDatabase {
  save(data: any): void {
    // Save to MySQL
  }
}

class UserService {
  private database: MySQLDatabase;

  constructor() {
    this.database = new MySQLDatabase(); // Tight coupling!
  }

  createUser(user: User): void {
    this.database.save(user);
  }
}
```

### Good Example
```typescript
interface IDatabase {
  save(data: any): void;
}

class MySQLDatabase implements IDatabase {
  save(data: any): void {
    // Save to MySQL
  }
}

class PostgreSQLDatabase implements IDatabase {
  save(data: any): void {
    // Save to PostgreSQL
  }
}

class UserService {
  constructor(private database: IDatabase) {} // Dependency injection

  createUser(user: User): void {
    this.database.save(user);
  }
}

// Usage
const mysqlDb = new MySQLDatabase();
const userService = new UserService(mysqlDb);

// Easy to switch
const postgresDb = new PostgreSQLDatabase();
const userService2 = new UserService(postgresDb);
```

## Quick Reference

| Principle | Kural | Fayda |
|-----------|-------|-------|
| SRP | Bir sınıf, bir sorumluluk | Maintainability |
| OCP | Extend et, değiştirme | Extensibility |
| LSP | Alt tip = üst tip | Reliability |
| ISP | Küçük interface'ler | Flexibility |
| DIP | Abstraction'a bağlan | Testability |
