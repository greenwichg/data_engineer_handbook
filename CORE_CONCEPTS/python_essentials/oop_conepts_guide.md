# Object-Oriented Programming (OOP) Concepts Guide

## Table of Contents
- [Classes and Instances](#classes-and-instances)
- [Understanding Instantiation](#understanding-instantiation)
- [Types of Variables](#types-of-variables)
- [Types of Methods](#types-of-methods)
- [Quick Reference Comparison](#quick-reference-comparison)
- [Common Use Cases](#common-use-cases)

---

## Classes and Instances

### What is a Class?

A **class** is a blueprint or template that defines the structure and behavior of objects. It contains:
- Method definitions (the actual code)
- Class variables (shared by all instances)
- Template for instance variables (defines what data each instance should have)

### What is an Instance?

An **instance** (also called an object) is a concrete realization created from a class. Each instance:
- Has its own memory space for data (instance variables)
- Has unique values for its attributes
- Shares methods with other instances (methods aren't copied, they're referenced)

### Key Relationship

- **Class** = Blueprint/Template (exists once)
- **Instance** = Individual object created from that blueprint (can have many)

---

## Understanding Instantiation

### What Happens When You Create an Instance?

```python
class Car:
    def __init__(self, brand, color):
        self.brand = brand
        self.color = color
    
    def drive(self):
        print(f"{self.brand} is driving")

# Creating instances
my_car = Car("Toyota", "Red")
```

**Step-by-step process:**

1. Python allocates **new memory** to store an object
2. Python calls the `__init__` method (constructor)
3. The new object gets its own data stored in that memory (`brand = "Toyota"`, `color = "Red"`)
4. The variable `my_car` points to this new object in memory

### Multiple Instances Example

```python
car1 = Car("Toyota", "Red")   # Creates object in memory location A
car2 = Car("Honda", "Blue")   # Creates object in memory location B

# Each instance has its own data
car1.brand  # "Toyota" - stored in location A
car2.brand  # "Honda"  - stored in location B

# But they share the same method code
car1.drive()  # Uses the drive() method from the Car class
car2.drive()  # Uses the same drive() method from the Car class
```

**Important:** Instantiation is NOT importing. It's creating a new object based on the class template.

---

## Types of Variables

### 1. Class Variables

Variables shared by **ALL instances** of the class.

```python
class Car:
    wheels = 4  # Class variable - shared by all Car instances
    total_cars = 0  # Another class variable
    
    def __init__(self, brand):
        self.brand = brand
        Car.total_cars += 1

car1 = Car("Toyota")
car2 = Car("Honda")

print(car1.wheels)      # 4 - references class variable
print(car2.wheels)      # 4 - same class variable
print(Car.total_cars)   # 2 - class variable tracks all instances
```

### 2. Instance Variables

Variables unique to **each instance**.

```python
class Car:
    def __init__(self, brand, color):
        self.brand = brand  # Instance variable
        self.color = color  # Instance variable

car1 = Car("Toyota", "Red")
car2 = Car("Honda", "Blue")

print(car1.brand)  # "Toyota" - car1's own data
print(car2.brand)  # "Honda"  - car2's own data
```

### Summary: Where Data Lives

| Variable Type | Where it lives | Shared or Unique? |
|---------------|----------------|-------------------|
| Class Variable | In the class | Shared by all instances |
| Instance Variable | In each instance | Unique to each instance |

---

## Types of Methods

### 1. Instance Method (Most Common)

Works with **specific object data** (instance variables).

```python
class Car:
    total_cars = 0
    
    def __init__(self, brand, color):
        self.brand = brand
        self.color = color
        Car.total_cars += 1
    
    # INSTANCE METHOD
    def drive(self):
        # Can access instance variables through 'self'
        print(f"{self.brand} car is driving")
        # Can also access class variables
        print(f"Total cars: {Car.total_cars}")
    
    def change_color(self, new_color):
        self.color = new_color

# Usage
car1 = Car("Toyota", "Red")
car1.drive()  # Must be called on an instance
car1.change_color("Blue")
```

**Characteristics:**
- First parameter: `self` (reference to the instance)
- Can access: Instance variables AND class variables
- Called on: An instance (`car1.drive()`)
- Use for: Operations on specific object data

---

### 2. Class Method

Works with **class-level data** and the class itself.

```python
class Car:
    total_cars = 0
    
    def __init__(self, brand):
        self.brand = brand
        Car.total_cars += 1
    
    # CLASS METHOD
    @classmethod
    def get_total_cars(cls):
        # Can access class variables through 'cls'
        return cls.total_cars
    
    @classmethod
    def create_toyota(cls):
        # Can create instances of the class (factory method)
        return cls("Toyota")

# Usage
car1 = Car("Honda")
print(Car.get_total_cars())  # 1 - called on the class

car2 = Car.create_toyota()   # Factory method
print(Car.get_total_cars())  # 2
```

**Characteristics:**
- Decorator: `@classmethod`
- First parameter: `cls` (reference to the class)
- Can access: Class variables and create instances
- Called on: The class itself (`Car.get_total_cars()`)
- Use for: Factory methods, alternative constructors, managing class state

---

### 3. Static Method

Utility functions that don't need access to class or instance data.

```python
class Car:
    def __init__(self, brand):
        self.brand = brand
    
    # STATIC METHOD
    @staticmethod
    def is_valid_brand(brand):
        # Just a utility function
        # No access to class or instance variables
        valid_brands = ["Toyota", "Honda", "Ford"]
        return brand in valid_brands
    
    @staticmethod
    def calculate_fuel_efficiency(distance, fuel):
        return distance / fuel

# Usage
print(Car.is_valid_brand("Toyota"))   # True - called on class
print(Car.is_valid_brand("Ferrari"))  # False

car1 = Car("Toyota")
print(car1.is_valid_brand("Honda"))   # True - can also call on instance
```

**Characteristics:**
- Decorator: `@staticmethod`
- First parameter: No special parameter
- Can access: Nothing - completely independent
- Called on: Class or instance
- Use for: Utility functions logically related to the class

---

## Quick Reference Comparison

### Method Types Comparison Table

| | **Instance Method** | **Class Method** | **Static Method** |
|---|---|---|---|
| **Decorator** | None | `@classmethod` | `@staticmethod` |
| **First parameter** | `self` | `cls` | None |
| **Can access instance variables** | ✅ Yes | ❌ No | ❌ No |
| **Can access class variables** | ✅ Yes | ✅ Yes | ❌ No |
| **Can modify instance state** | ✅ Yes | ❌ No | ❌ No |
| **Can modify class state** | ✅ Yes | ✅ Yes | ❌ No |
| **Called on** | Instance | Class or Instance | Class or Instance |
| **Most common use** | Working with object data | Factory methods, class state | Utility functions |

### Complete Example with All Method Types

```python
class Car:
    # Class variable
    total_cars = 0
    valid_brands = ["Toyota", "Honda", "Ford"]
    
    def __init__(self, brand, color):
        # Instance variables
        self.brand = brand
        self.color = color
        Car.total_cars += 1
    
    # INSTANCE METHOD
    def drive(self):
        print(f"{self.brand} ({self.color}) is driving")
    
    def change_color(self, new_color):
        self.color = new_color
    
    # CLASS METHOD
    @classmethod
    def get_total_cars(cls):
        return cls.total_cars
    
    @classmethod
    def create_toyota(cls):
        return cls("Toyota", "White")
    
    # STATIC METHOD
    @staticmethod
    def is_valid_brand(brand):
        return brand in Car.valid_brands
    
    @staticmethod
    def calculate_fuel_efficiency(distance, fuel):
        return distance / fuel


# Usage examples
car1 = Car("Honda", "Red")
car1.drive()  # Instance method
car1.change_color("Blue")  # Instance method

print(Car.get_total_cars())  # Class method: 1

car2 = Car.create_toyota()  # Class method (factory)
print(Car.get_total_cars())  # Class method: 2

print(Car.is_valid_brand("Toyota"))  # Static method: True
print(Car.calculate_fuel_efficiency(100, 5))  # Static method: 20.0
```

---

## Common Use Cases

### When to Use Instance Methods
- Modifying object state (changing instance variables)
- Operations specific to an object
- Most common type of method in OOP
- Examples: `car.drive()`, `car.change_color()`, `account.deposit()`

### When to Use Class Methods
- Factory methods (creating instances in specific ways)
- Alternative constructors
- Accessing or modifying class variables
- Managing class-level state
- Examples: `Car.create_toyota()`, `Date.from_string()`, `Counter.get_count()`

### When to Use Static Methods
- Utility functions related to the class
- Functions that don't need access to class or instance data
- Logical grouping with the class
- Examples: `Math.is_prime()`, `Validator.is_email()`, `Car.is_valid_brand()`

---

## Key Takeaways

1. **Class** = Blueprint that holds method definitions and class variables
2. **Instance** = Individual object with its own data created from the class
3. **Instance Method** = Works with specific object data (`self`)
4. **Class Method** = Works with class-level data (`cls`)
5. **Static Method** = Utility function that doesn't need class or instance access
6. Each instance has its **own copy of instance variables**
7. All instances **share** class variables and methods
8. Choose the right method type based on what data you need to access

---

## Additional Notes

- **Instance variables** are created in `__init__` using `self.variable_name`
- **Class variables** are defined directly in the class body
- **Methods** are functions defined inside a class
- Use `self` to access instance variables and methods
- Use `cls` or `ClassName` to access class variables in class methods
- Static methods are essentially regular functions that live in the class namespace

---

*This guide covers the fundamental concepts of OOP in Python. Practice creating classes with different types of variables and methods to solidify your understanding!*
