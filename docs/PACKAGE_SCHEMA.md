# ZigScript Package Schema (package.zson)

## Overview

ZigScript uses `package.zson` for package management, using **ZSON** (ZigScript Object Notation) - a developer-friendly JSON superset with unquoted keys, trailing commas, and comments.

## Why ZSON?

- **Unquoted keys**: `name: "my-package"` instead of `"name": "my-package"`
- **Trailing commas**: No more comma errors when adding fields
- **Comments**: Document your package configuration
- **Single quotes**: Use either `'` or `"` for strings

## Schema

```zson
{
  // Package metadata
  name: "my-package",
  version: "1.0.0",
  description: "A ZigScript package",
  author: "Your Name <you@example.com>",
  license: "MIT",

  // Compatibility
  zigscript: "0.1.0",
  zig: "0.16.0",

  // Entry points
  main: "src/main.zs",
  exports: {
    ".": "./src/main.zs",
    "./utils": "./src/utils.zs",
  },

  // ZigScript dependencies
  dependencies: {
    "http-server": "^2.1.0",
    postgres: "^1.0.0",  // Unquoted keys work too!
  },

  devDependencies: {
    "test-framework": "^0.5.0",
  },

  // Native Zig dependencies (for host functions)
  zig_dependencies: {
    "zig-network": {
      url: "https://github.com/user/zig-network/archive/v0.14.0.tar.gz",
      hash: "1220...",
    },
  },

  // Build scripts
  scripts: {
    build: "zs build src/main.zs",
    test: "zs test",
    dev: "nexus-zs run src/main.zs --watch",
  },

  // Repository
  repository: {
    type: "git",
    url: "https://github.com/user/my-package.git",
  },
}
```

## Fields

### Required Fields

- **name** (string): Package name (lowercase, hyphens allowed)
- **version** (string): Semantic version (e.g., "1.0.0")

### Metadata Fields

- **description** (string): Short package description
- **author** (string): Author name and email
- **license** (string): SPDX license identifier
- **repository** (object): Git repository information

### Compatibility

- **zigscript** (string): ZigScript version constraint (e.g., "^0.1.0")
- **zig** (string): Zig version constraint (e.g., "0.16.0")

### Entry Points

- **main** (string): Default entry point (e.g., "src/main.zs")
- **exports** (object): Named export paths for submodule imports

### Dependencies

- **dependencies** (object): Production ZigScript packages
  - Key: package name
  - Value: version constraint (e.g., "^2.1.0", "~1.0.0", ">=1.0.0 <2.0.0")

- **devDependencies** (object): Development-only ZigScript packages

- **zig_dependencies** (object): Native Zig packages (build.zig.zon format)
  - Used when ZigScript needs to call native Zig code via WASM host functions

### Scripts

- **scripts** (object): Command shortcuts
  - Key: script name (e.g., "build", "test")
  - Value: shell command to execute

## Version Constraints

ZigScript uses npm-style semver constraints:

- `^1.2.3`: Compatible with 1.x.x (>= 1.2.3, < 2.0.0)
- `~1.2.3`: Compatible with 1.2.x (>= 1.2.3, < 1.3.0)
- `1.2.3`: Exact version
- `>=1.2.0 <2.0.0`: Range constraint
- `*` or `latest`: Latest version

## Package Resolution

### Import Resolution Order

1. **Built-in modules**: `std/json`, `std/http`, etc.
2. **Relative imports**: `./foo.zs`, `../bar.zs`
3. **Package imports**: `http-server`, `postgres`

### Package Cache Location

Packages are cached in:
- **User cache**: `~/.cache/zim/zigscript/packages/<name>/<version>/`
- **Project local**: `./zig-cache/zigscript/packages/`

### Lock File

Dependencies are locked in `package.zson.lock`:

```json
{
  "version": "1",
  "packages": {
    "http-server": {
      "version": "2.1.0",
      "resolved": "https://github.com/user/http-server/archive/v2.1.0.tar.gz",
      "integrity": "sha512-...",
      "dependencies": {
        "tcp-lib": "^1.0.0"
      }
    },
    "tcp-lib": {
      "version": "1.0.5",
      "resolved": "https://github.com/user/tcp-lib/archive/v1.0.5.tar.gz",
      "integrity": "sha512-..."
    }
  }
}
```

## Integration with ZIM

ZigScript packages can depend on Zig packages via the `zig_dependencies` field:

```json
{
  "name": "my-package",
  "version": "1.0.0",
  "zig_dependencies": {
    "network": {
      "url": "https://github.com/user/zig-network/archive/main.tar.gz",
      "hash": "1220abcdef..."
    }
  }
}
```

When building, ZigScript generates a `build.zig.zon` file that ZIM can process:

```zig
.{
    .name = "my-package",
    .version = "1.0.0",
    .dependencies = .{
        .network = .{
            .url = "https://github.com/user/zig-network/archive/main.tar.gz",
            .hash = "1220abcdef...",
        },
    },
}
```

## Example Packages

### CLI Tool Package

```json
{
  "name": "my-cli-tool",
  "version": "1.0.0",
  "description": "A command-line tool",
  "main": "src/main.zs",
  "zigscript": "^0.1.0",
  "dependencies": {
    "cli-framework": "^1.0.0",
    "colors": "^0.5.0"
  },
  "scripts": {
    "build": "zs build src/main.zs",
    "install": "zs build --release && cp zig-out/bin/my-cli ~/.local/bin/"
  }
}
```

### Library Package

```json
{
  "name": "json-schema",
  "version": "0.5.0",
  "description": "JSON Schema validation library",
  "main": "src/index.zs",
  "exports": {
    ".": "./src/index.zs",
    "./types": "./src/types.zs",
    "./validators": "./src/validators.zs"
  },
  "zigscript": "^0.1.0",
  "dependencies": {},
  "devDependencies": {
    "test-framework": "^0.5.0"
  },
  "scripts": {
    "test": "zs test tests/",
    "build": "zs build --lib"
  }
}
```

### Web Service Package

```json
{
  "name": "my-web-app",
  "version": "2.0.0",
  "description": "A web application",
  "main": "src/server.zs",
  "zigscript": "^0.1.0",
  "dependencies": {
    "http-server": "^2.1.0",
    "postgres": "^1.0.0",
    "jwt": "^0.3.0"
  },
  "zig_dependencies": {
    "pg": {
      "url": "https://github.com/karlseguin/pg.zig/archive/master.tar.gz",
      "hash": "..."
    }
  },
  "scripts": {
    "dev": "nexus-zs run src/server.zs",
    "build": "zs build --release src/server.zs",
    "start": "nexus-zs run zig-out/bin/server.wasm"
  }
}
```

## Commands

### `zs init`

Initialize a new ZigScript project:

```bash
$ zs init
✨ Creating new ZigScript project...
📝 Project name: my-app
📝 Version (1.0.0):
📝 Description: My awesome app
✅ Created package.zson
✅ Created src/main.zs
```

### `zs add <package>[@version]`

Add a dependency:

```bash
$ zs add http-server@^2.1.0
📦 Resolving http-server@^2.1.0...
✅ Found http-server@2.1.5
📥 Downloading...
✅ Installed http-server@2.1.5
📝 Updated package.zson
```

### `zs install`

Install all dependencies from package.zson:

```bash
$ zs install
📦 Reading package.zson...
📥 Resolving dependencies...
  http-server@^2.1.0 -> 2.1.5
  postgres@^1.0.0 -> 1.0.3
✅ Installed 2 packages
🔒 Wrote package.zson.lock
```

### `zs remove <package>`

Remove a dependency:

```bash
$ zs remove http-server
🗑️  Removed http-server from package.zson
✅ Updated lock file
```

## Publishing

### `zs publish`

Publish package to registry:

```bash
$ zs publish
📦 Publishing my-package@1.0.0...
✅ Package published successfully!
```

### Registry

Packages are published to the ZigScript registry (or GitHub releases):

- **Official registry**: `https://registry.zigscript.dev/`
- **GitHub**: `github:user/repo` shorthand

## Best Practices

1. **Semantic Versioning**: Follow semver strictly
2. **Lock File**: Always commit `package.zson.lock` for applications
3. **Version Constraints**: Use `^` for libraries, exact versions for apps
4. **Minimal Dependencies**: Keep dependency tree small
5. **Zig Integration**: Use `zig_dependencies` only when necessary
6. **Scripts**: Define common tasks (build, test, dev) in scripts
7. **Documentation**: Include README.md and examples/

## Migration from Node.js

| Node.js | ZigScript |
|---------|-----------|
| `package.json` | `package.zson` |
| `npm install` | `zs install` |
| `npm add express` | `zs add http-server` |
| `npm run build` | `zs run build` |
| `node index.js` | `nexus-zs run src/main.zs` |
| `require('./foo')` | `import { foo } from "./foo.zs";` |
| `node_modules/` | Cached in `~/.cache/zim/zigscript/` |

---

**Version**: 1.0
**Last Updated**: 2025-01-23
