import 'package:flutter_code_crafter/code_crafter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/an-old-hope.dart';
import 'package:highlight/languages/typescript.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final CodeCrafterController controller;
  late final Models model;

  @override
  void initState() {
    controller = CodeCrafterController();
    controller.language = typescript;
    controller.text = """
enum Status {
  Draft,
  Published,
  Archived
}

type UserPermissions = ["read", "write"];

function loggable(target: any, key: string) {
  let value = target[key];
  Object.defineProperty(target, key, {
    get: () => {
      console.log(`Getting \${key}:`, value);
      return value;
    },
    set: (newVal: any) => {
      console.log(`Setting \${key} to`, newVal);
      value = newVal;
    }
  });
}

class Container<T> {
  private data: T;

  constructor(value: T) {
    this.data = value;
  }

  get(): T {
    return this.data;
  }

  set(newValue: T): void {
    this.data = newValue;
  }
}

type ExtractStringKeys<T> = {
  [K in keyof T]: T[K] extends string ? K : never;
}[keyof T];

type AnimalType = "dog" | "cat";
type Animal = {
  name: string;
} & ({ type: "dog"; bark: boolean } | { type: "cat"; meow: boolean });

type MakeOptional<T> = {
  [K in keyof T]?: T[K];
};

async function fetchUser(): Promise<{ id: number; name: string }> {
  return new Promise((resolve) =>
    setTimeout(() => resolve({ id: 1, name: "Alice" }), 500)
  );
}

class Book {
  @loggable
  title!: string;
  
  constructor(public author: string, private status: Status = Status.Draft) {}

  getStatus(): string {
    return Status[this.status];
  }
}

namespace Library {
  export class Collection<T> {
    items: T[] = [];

    add(item: T): void {
      this.items.push(item);
    }

    list(): T[] {
      return [...this.items];
    }
  }
}

function getLength(input: string): number;
function getLength<T>(input: T[]): number;
function getLength(input: any): number {
  return input.length;
}

async function main() {
  const book = new Book("J.K. Rowling");
  book.title = "Harry Potter";

  console.log("Book Title:", book.title);
  console.log("Status:", book.getStatus());

  const userContainer = new Container<{ name: string }>({ name: "John" });
  console.log("User Name from container:", userContainer.get().name);

  const dog1: Animal = {
    name: "Buddy",
    type: "dog",
    bark: true
  };

  const libCollection = new Library.Collection<Animal>();
  libCollection.add(dog1);
  console.log("Library Collection Items:", libCollection.list());

  const user = await fetchUser();
  console.log("Fetched User:", JSON.stringify(user, null, 2));

  // Type inference and utility types
  type PartialBook = MakeOptional<Book>;
  const partialBook: PartialBook = {};
}

main();
""";
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: CodeCrafter(
              editorTheme: anOldHopeTheme,
              controller: controller,
            ),
          )),
    );
  }
}
