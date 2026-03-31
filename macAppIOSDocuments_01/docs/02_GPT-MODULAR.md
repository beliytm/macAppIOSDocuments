#GPT-MODULAR v3.6 HYBRID

##PURPOSE
defines: modular project structure, folder creation, module contracts, registry
NOT-defines: naming (see 00_GPT-RULES), logging (see 01_GPT-LOGGER)
PRIORITY: 00_GPT-RULES > 02_GPT-MODULAR

##PRINCIPLES (CRITICAL)
- each module = independent
- remove module = system still works
- modules communicate ONLY via core/registry
- NO direct module-to-module imports
- core = STABLE (rarely changes)
- modules = EXPENDABLE (replaceable)

##GPT-IGNORE (CRITICAL)
when-creating-project=ALWAYS-create-these-files

FILES-TO-CREATE:
1. .cursorignore (for Cursor IDE - auto-ignore)
2. .gptignore (universal marker for any GPT)
3. _ref/ folder (reference docs GPT should not read)

.CURSORIGNORE-CONTENT:
```
_ref/
node_modules/
dist/
target/
*.lock
*.png
*.jpg
*.ico
*.icns
logs/*.log
```

.GPTIGNORE-CONTENT:
```
# Files GPT should NOT read (saves tokens)
_ref/
node_modules/
dist/
*.lock
*.png
```

_REF-FOLDER:
purpose=docs that never change (setup, install, old-docs)
rule=GPT creates but does NOT read later
contains: setup.md, install.md, reference/
when-to-read=ONLY if user explicitly asks

ALWAYS-IGNORE (do not read):
- node_modules/, vendor/, target/ (dependencies)
- *.lock files (package-lock.json, Cargo.lock)
- *.png, *.jpg, *.ico, *.icns (binary images)
- _ref/ folder (static reference)
- dist/, build/ (compiled output)
- logs/*.log (log files)

GPT-BEHAVIOR:
- create .cursorignore, .gptignore, _ref/ with EVERY new project
- do NOT read _ref/ unless user explicitly asks
- do NOT read files listed in .gptignore
- saves ~40% tokens on large projects

##STRUCTURE
```
project/
├── .cursorignore        # Cursor auto-ignores these
├── .gptignore           # Universal GPT ignore marker
├── _ref/                # GPT does NOT read (reference only)
│   └── setup.md         # Install instructions etc
├── src/
│   ├── core/
│   │   ├── base.ts      # Module interface
│   │   ├── registry.ts  # Lifecycle manager
│   │   └── utils.ts     # Shared utilities
│   ├── modules/
│   │   └── [name]/
│   │       └── module.ts
│   ├── shared/
│   │   ├── config/
│   │   └── types/
│   └── main.ts
├── tests/
│   ├── unit/
│   └── integration/
├── docs/
├── logs/
└── package.json / Cargo.toml
```

##MODULE-CONTRACT (CRITICAL)
every module MUST implement:
```typescript
interface Module {
  getName(): string;              // unique identifier
  init(): Promise<void>;          // setup (NO business logic)
  execute(): Promise<Result>;     // main work
  cleanup(): void;                // teardown (idempotent)
  getDependencies(): string[];    // required modules (or [])
}
```

RULES:
- init() = only setup, NO business logic
- execute() = NO global state mutation
- cleanup() = safe to call multiple times
- getDependencies() = return [] if none

##MODULE-IMPLEMENTATION
```typescript
// src/modules/user/module.ts
import { BaseModule, Module, ModuleResult } from '../../core';
import { log } from '../../utils/logger';

export class UserModule extends BaseModule implements Module {
  getName(): string {
    return 'UserModule';
  }

  getDependencies(): string[] {
    return ['DatabaseModule']; // or [] if none
  }

  async init(): Promise<void> {
    // setup only - no business logic
    this.config = await this.loadConfig();
  }

  async execute(): Promise<ModuleResult> {
    try {
      const result = await this.processUsers();
      return { success: true, data: result };
    } catch (error) {
      log(error, 'await this.processUsers()', { module: this.getName() });
      return { success: false, error: error.message };
    }
  }

  cleanup(): void {
    this.config = null;
    this.cache.clear();
  }
}
```

##REGISTRY-IMPLEMENTATION
```typescript
// src/core/registry.ts
import { Module } from './base';

class ModuleRegistry {
  private modules: Map<string, Module> = new Map();
  private initialized: Set<string> = new Set();

  register(module: Module): void {
    const name = module.getName();
    if (this.modules.has(name)) {
      throw new Error(`Module ${name} already registered`);
    }
    this.detectCircularDeps(module);
    this.modules.set(name, module);
  }

  get(name: string): Module | undefined {
    return this.modules.get(name);
  }

  async initAll(): Promise<void> {
    const order = this.resolveDependencies();
    for (const name of order) {
      const module = this.modules.get(name)!;
      try {
        await module.init();
        this.initialized.add(name);
      } catch (error) {
        log(error, 'await module.init()', { module: name });
        // continue with other modules
      }
    }
  }

  async runAll(): Promise<Map<string, ModuleResult>> {
    const results = new Map();
    for (const [name, module] of this.modules) {
      if (this.initialized.has(name)) {
        results.set(name, await module.execute());
      }
    }
    return results;
  }

  cleanupAll(): void {
    // reverse order
    const order = [...this.modules.keys()].reverse();
    for (const name of order) {
      this.modules.get(name)?.cleanup();
    }
  }

  private resolveDependencies(): string[] {
    // topological sort
    const visited = new Set<string>();
    const order: string[] = [];
    
    const visit = (name: string) => {
      if (visited.has(name)) return;
      visited.add(name);
      const module = this.modules.get(name);
      if (module) {
        for (const dep of module.getDependencies()) {
          visit(dep);
        }
        order.push(name);
      }
    };
    
    for (const name of this.modules.keys()) {
      visit(name);
    }
    return order;
  }

  private detectCircularDeps(module: Module): void {
    // implement circular dependency detection
    const visited = new Set<string>();
    const check = (name: string, path: string[]): void => {
      if (path.includes(name)) {
        throw new Error(`Circular dependency: ${path.join(' -> ')} -> ${name}`);
      }
      if (visited.has(name)) return;
      visited.add(name);
      const mod = this.modules.get(name);
      if (mod) {
        for (const dep of mod.getDependencies()) {
          check(dep, [...path, name]);
        }
      }
    };
    check(module.getName(), []);
  }
}

export const registry = new ModuleRegistry();
```

##FAILURE-BOUNDARIES
registry:
  - duplicate name -> throw error
  - init failure -> log + skip module
  - circular dependency -> prevent registration

module:
  - invalid config -> fail fast
  - runtime error -> catch + log + return error result
  - missing dependency -> skip or wait

main:
  - bootstrap failure -> exit code 1
  - missing modules -> warn + continue

RULE: errors stay within boundary, never crash entire system

##STATES
INIT = structure creation only
STRUCTURE_LOCKED = core frozen
MODULE_EXPANSION = add modules, core untouched
REFACTOR = internal changes, contracts frozen

##FORBIDDEN
- direct module-to-module import
- modify core during MODULE_EXPANSION
- circular dependencies
- global state in modules
- business logic in init()
- skip cleanup()

##EDGE-CASES

Circular dependency:
```
ERROR: Circular dependency detected
ModuleA -> ModuleB -> ModuleC -> ModuleA

SOLUTIONS:
1. extract shared logic to shared/
2. use Event Bus pattern
3. reverse dependency direction
4. split module
```

Invalid module name:
```
ERROR: Invalid name "User-Module"
RULE: PascalCase, no hyphens
YES: UserModule, AuthModule, DataProcessorModule
NO: User-Module, userModule, user_module
```

##VALIDATION
before registering module:
1. check dependencies exist
2. verify no circular deps
3. determine init order
4. warn about missing deps

##GPT-ROLE
IS: architect, structure enforcer, validator
NOT: product designer, business logic author
