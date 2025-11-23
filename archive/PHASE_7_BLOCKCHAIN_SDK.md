# Phase 7: Production Readiness & Blockchain SDK Foundation

## Vision

Build a complete ecosystem for blockchain interaction via ZigScript + Nexus:
- **xrpl-zs**: XRP Ledger SDK (like xrpl-js)
- **eth-zs**: Ethereum/EVM chains
- **solana-zs**: Solana SDK
- **btc-zs**: Bitcoin integration
- **Generic crypto primitives**: ED25519, SHA256, ECDSA, etc.

## Prerequisites for Blockchain SDKs

### 1. Module System (Critical Path) 🔴

**Why needed**: SDKs are multi-file projects requiring imports/exports

**Implementation**:
```zs
// xrpl/client.zs
import { http } from "std/http";
import { json } from "std/json";
import { Wallet } from "./wallet";

export struct Client {
    url: string,

    fn new(url: string) -> Client {
        return Client { url: url };
    }

    async fn request(method: string, params: json.Value) -> Result<json.Value, Error> {
        let body = json.stringify({
            "method": method,
            "params": params
        });

        let response = await http.post(self.url, body)?;
        return json.parse(response.body);
    }
}

// user code
import { Client } from "xrpl/client";

async fn main() -> Result<void, Error> {
    let client = Client.new("https://s1.ripple.com:51234");
    let info = await client.request("server_info", [])?;
    return Ok(());
}
```

**Tasks**:
- [ ] `import` / `export` syntax parsing
- [ ] Module resolver (file path mapping)
- [ ] Symbol table per module
- [ ] Cross-module type checking
- [ ] WASM module linking or single compilation unit

**Priority**: 🔴 **CRITICAL** - Blocks all SDK work

---

### 2. Crypto Primitives (Nexus Integration) 🔴

**Why needed**: Blockchain operations require cryptography

**Required Operations**:
```zs
// std/crypto/hash.zs
extern fn sha256(data: bytes) -> bytes;
extern fn sha512(data: bytes) -> bytes;
extern fn ripemd160(data: bytes) -> bytes;
extern fn blake2b(data: bytes, size: i32) -> bytes;

// std/crypto/sign.zs
extern fn ed25519_keypair(seed: bytes) -> struct { public_key: bytes, private_key: bytes };
extern fn ed25519_sign(message: bytes, private_key: bytes) -> bytes;
extern fn ed25519_verify(message: bytes, signature: bytes, public_key: bytes) -> bool;

extern fn ecdsa_secp256k1_sign(message: bytes, private_key: bytes) -> bytes;
extern fn ecdsa_secp256k1_verify(message: bytes, signature: bytes, public_key: bytes) -> bool;

// std/crypto/encoding.zs
extern fn hex_encode(data: bytes) -> string;
extern fn hex_decode(hex: string) -> bytes;
extern fn base58_encode(data: bytes) -> string;
extern fn base58_decode(b58: string) -> bytes;
extern fn base64_encode(data: bytes) -> string;
extern fn base64_decode(b64: string) -> bytes;
```

**Nexus Side** (Zig implementation):
```zig
// nexus/src/crypto.zig
pub fn sha256(data: []const u8) ![32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(data);
    var result: [32]u8 = undefined;
    hasher.final(&result);
    return result;
}

pub fn ed25519_sign(message: []const u8, private_key: [64]u8) ![64]u8 {
    const key_pair = try std.crypto.sign.Ed25519.KeyPair.fromSecretKey(private_key[0..32].*);
    return try key_pair.sign(message, null);
}
```

**Tasks**:
- [ ] Add crypto module to Nexus runtime
- [ ] Expose crypto functions as WASM imports
- [ ] Create ZigScript `std/crypto` module
- [ ] Test vectors for all operations

**Priority**: 🔴 **CRITICAL** - Required for signing transactions

---

### 3. Bytes Type (Language Enhancement) 🟡

**Why needed**: Blockchain data is binary (hashes, signatures, addresses)

**Current Issue**: ZigScript has `string` but no `bytes` type

**Proposal**:
```zs
// Add bytes primitive type
let hash: bytes = sha256("hello");
let signature: bytes = ed25519_sign(message, private_key);

// Bytes literal syntax
let data: bytes = b"0x1234abcd";  // hex
let raw: bytes = b[0x01, 0x02, 0x03];  // array notation

// Bytes operations
fn concat(a: bytes, b: bytes) -> bytes;
fn slice(data: bytes, start: i32, end: i32) -> bytes;
fn len(data: bytes) -> i32;
```

**WASM Representation**:
- Memory layout: `[length: i32][data...]`
- Similar to array but u8 elements

**Tasks**:
- [ ] Add `bytes` primitive to AST
- [ ] Bytes literal parsing
- [ ] Type checker support
- [ ] WASM codegen for bytes operations
- [ ] Interop with `string` type

**Priority**: 🟡 **HIGH** - Needed for clean API design

---

### 4. JSON Schema / Serialization 🟡

**Why needed**: Blockchain RPC uses JSON, need type-safe parsing

**Current**: Basic JSON parser exists
**Needed**: Type-safe deserialization

```zs
// Type-safe JSON decoding
struct AccountInfo {
    account: string,
    balance: string,
    sequence: i32,
}

let response = await http.post(url, body)?;
let data = json.decode<AccountInfo>(response.body)?;  // Type-safe!

// Or manual
let obj = json.parse(response.body)?;
let balance = obj.get("result").get("account_data").get("Balance").as_string()?;
```

**Tasks**:
- [ ] Generic type parameters for `decode<T>()`
- [ ] Struct field mapping from JSON
- [ ] Error handling for missing/wrong type fields
- [ ] Nested struct support

**Priority**: 🟡 **HIGH** - Better than JS/TS without codegen!

---

### 5. BigInt Type 🟢

**Why needed**: Blockchain amounts exceed i64 (XRP drops are u64)

**Examples**:
- XRP: Values in "drops" (1 XRP = 1,000,000 drops) - needs u64
- Ethereum: Wei amounts need u256
- Bitcoin: Satoshis need u64

**Proposal**:
```zs
// BigInt primitive
let xrp_drops: u64 = 1000000;
let eth_wei: u256 = u256.parse("1000000000000000000");

// Operations
let sum = a + b;  // Emits WASM i64.add or custom bigint ops
let product = a * b;

// Conversion
let drops_str = xrp_drops.toString();
let drops = u64.parse("1000000");
```

**Tasks**:
- [ ] Add `u64`, `u256` types to AST
- [ ] WASM i64 operations
- [ ] BigInt library for u128/u256 (if needed)
- [ ] String conversion functions

**Priority**: 🟢 **MEDIUM** - Can use string initially, but proper types better

---

## Phase 7 Implementation Plan

### Sprint 1: Module System (Week 1-2) 🔴

**Goal**: Import/export working with multi-file compilation

```zs
// math/vector.zs
export struct Vector2 {
    x: f64,
    y: f64,
}

export fn dot(a: Vector2, b: Vector2) -> f64 {
    return a.x * b.x + a.y * b.y;
}

// main.zs
import { Vector2, dot } from "math/vector";

fn main() -> i32 {
    let v1 = Vector2 { x: 1.0, y: 2.0 };
    let v2 = Vector2 { x: 3.0, y: 4.0 };
    let result = dot(v1, v2);
    return 0;
}
```

**Tasks**:
1. Parse `import` / `export` syntax
2. Module dependency graph
3. Multi-file type checking
4. Symbol resolution across modules
5. WASM generation (single module or linking)

**Deliverable**: Multi-file compilation working

---

### Sprint 2: Crypto Primitives (Week 3) 🔴

**Goal**: Hash, sign, verify working via Nexus

**Nexus Integration**:
```zig
// nexus/src/wasm_host.zig
pub fn crypto_sha256(vm: *WasmVM, data_ptr: u32, data_len: u32, out_ptr: u32) void {
    const data = vm.memory[data_ptr..data_ptr + data_len];
    const hash = crypto.sha256(data);
    @memcpy(vm.memory[out_ptr..out_ptr + 32], &hash);
}

// Register host function
vm.registerHostFunction("crypto_sha256", crypto_sha256);
```

**ZigScript Side**:
```zs
// std/crypto/hash.zs
extern fn _crypto_sha256(data_ptr: i32, data_len: i32, out_ptr: i32) -> void;

fn sha256(data: bytes) -> bytes {
    let result: bytes = alloc(32);
    _crypto_sha256(data.ptr(), data.len(), result.ptr());
    return result;
}
```

**Tasks**:
1. Add crypto module to Nexus
2. Implement SHA256, SHA512, RIPEMD160
3. Implement ED25519 (sign, verify, keypair)
4. Implement ECDSA secp256k1
5. Test vectors (compare with known outputs)

**Deliverable**: Crypto functions callable from ZigScript

---

### Sprint 3: Bytes Type (Week 4) 🟡

**Goal**: Native bytes type with operations

**AST Changes**:
```zig
// ast.zig
pub const Type = union(enum) {
    primitive: enum { i32, i64, f64, bool, string, bytes },  // Add bytes
    // ...
};
```

**Operations**:
```zs
let hash: bytes = sha256(b"hello");
let combined: bytes = hash + hash;  // Concat
let slice: bytes = hash[0:16];      // Slice
let len: i32 = hash.len();          // Length
```

**Tasks**:
1. Add bytes to type system
2. Bytes literal parsing
3. WASM memory layout
4. Bytes operations (concat, slice, indexing)
5. Conversion to/from string (hex encoding)

**Deliverable**: Bytes type working end-to-end

---

### Sprint 4: XRPL SDK Foundation (Week 5-6) 🚀

**Goal**: Basic XRPL client working

```zs
// xrpl/client.zs
import { http } from "std/http";
import { json } from "std/json";

export struct Client {
    url: string,
}

export fn new_client(url: string) -> Client {
    return Client { url: url };
}

export async fn account_info(client: Client, account: string) -> Result<json.Value, Error> {
    let body = json.stringify({
        "method": "account_info",
        "params": [{
            "account": account,
            "ledger_index": "current"
        }]
    });

    let response = await http.post(client.url, body)?;
    return json.parse(response.body);
}

// xrpl/wallet.zs
import { ed25519_keypair, ed25519_sign } from "std/crypto/sign";
import { sha256, ripemd160 } from "std/crypto/hash";
import { base58_encode } from "std/crypto/encoding";

export struct Wallet {
    public_key: bytes,
    private_key: bytes,
    address: string,
}

export fn from_seed(seed: string) -> Wallet {
    let seed_bytes = decode_seed(seed);
    let keypair = ed25519_keypair(seed_bytes);
    let address = derive_address(keypair.public_key);

    return Wallet {
        public_key: keypair.public_key,
        private_key: keypair.private_key,
        address: address,
    };
}

fn derive_address(public_key: bytes) -> string {
    let hash1 = sha256(public_key);
    let hash2 = ripemd160(hash1);
    return base58_encode(hash2);  // Simplified
}

export fn sign(wallet: Wallet, message: bytes) -> bytes {
    return ed25519_sign(message, wallet.private_key);
}

// main.zs
import { new_client, account_info } from "xrpl/client";
import { Wallet } from "xrpl/wallet";

async fn main() -> Result<void, Error> {
    let client = new_client("https://s1.ripple.com:51234");

    // Query account
    let info = await account_info(client, "rN7n7otQDd6FczFgLdlqtyMVrn3LNU8Ki4")?;
    print("Balance: " + info.get("result").get("account_data").get("Balance").as_string()?);

    // Create wallet
    let wallet = Wallet.from_seed("sEdV19vMq1AmkF9jqUCpgfGC5dqVVjF");
    print("Address: " + wallet.address);

    return Ok(());
}
```

**Tasks**:
1. XRPL client (account queries, ledger info)
2. Wallet creation from seed
3. Address derivation (SHA256 + RIPEMD160 + Base58Check)
4. Transaction signing
5. Transaction submission
6. Payment transaction construction

**Deliverable**: Working XRPL client + wallet

---

### Sprint 5: Transaction Builder (Week 7) 🚀

**Goal**: Type-safe transaction construction

```zs
// xrpl/transaction.zs
export struct Payment {
    account: string,
    destination: string,
    amount: string,  // XRP drops
    fee: string,
    sequence: i32,
}

export fn build_payment(from: string, to: string, drops: string) -> Payment {
    return Payment {
        account: from,
        destination: to,
        amount: drops,
        fee: "12",  // Default fee
        sequence: 0,  // To be filled
    };
}

export fn serialize(tx: Payment) -> bytes {
    // Binary serialization (XRPL canonical format)
    let buffer = ByteBuffer.new();
    buffer.write_u16(0x1200);  // TransactionType: Payment
    buffer.write_account(tx.account);
    buffer.write_account(tx.destination);
    buffer.write_amount(tx.amount);
    // ... etc
    return buffer.bytes();
}

export async fn sign_and_submit(
    client: Client,
    wallet: Wallet,
    tx: Payment
) -> Result<string, Error> {
    // Get sequence number
    let account_data = await account_info(client, wallet.address)?;
    tx.sequence = account_data.get("result").get("account_data").get("Sequence").as_i32()?;

    // Serialize and sign
    let tx_bytes = serialize(tx);
    let hash = sha512_half(tx_bytes);
    let signature = wallet.sign(hash);

    // Add signature to transaction
    let signed_tx = add_signature(tx_bytes, signature, wallet.public_key);

    // Submit
    let result = await client.request("submit", [{ "tx_blob": hex_encode(signed_tx) }])?;
    return result.get("result").get("hash").as_string();
}
```

**Tasks**:
1. Binary serialization (canonical XRPL format)
2. Field type encoding (account, amount, uint32, etc.)
3. Multi-signing support
4. Transaction types (Payment, OfferCreate, TrustSet, etc.)

**Deliverable**: Can construct, sign, and submit XRPL transactions

---

## Beyond XRPL: Multi-Chain Architecture

### Generic Blockchain SDK Pattern

```zs
// std/blockchain/client.zs
export trait BlockchainClient {
    async fn get_balance(address: string) -> Result<string, Error>;
    async fn get_transaction(hash: string) -> Result<Transaction, Error>;
    async fn submit_transaction(tx: bytes) -> Result<string, Error>;
}

// xrpl/client.zs
impl BlockchainClient for XRPLClient {
    async fn get_balance(address: string) -> Result<string, Error> {
        let info = await self.account_info(address)?;
        return info.get("result").get("account_data").get("Balance").as_string();
    }
    // ...
}

// eth/client.zs
impl BlockchainClient for EthereumClient {
    async fn get_balance(address: string) -> Result<string, Error> {
        let result = await self.rpc("eth_getBalance", [address, "latest"])?;
        return result.as_string();
    }
    // ...
}
```

### SDK Roadmap

1. **xrpl-zs** (Sprint 4-5) - XRP Ledger
   - Client queries
   - Wallet management
   - Payment transactions
   - DEX operations (OfferCreate, etc.)

2. **eth-zs** (Future) - Ethereum
   - JSON-RPC client
   - ECDSA secp256k1 signing
   - ABI encoding/decoding
   - ERC20/ERC721 helpers
   - Smart contract calls

3. **solana-zs** (Future) - Solana
   - RPC client
   - ED25519 signing
   - Transaction construction
   - Program interaction

4. **btc-zs** (Future) - Bitcoin
   - RPC client
   - ECDSA signing
   - UTXO management
   - Transaction building

## Success Metrics

### Phase 7 Complete When:
- ✅ Module system working (import/export)
- ✅ Crypto primitives in Nexus
- ✅ Bytes type operational
- ✅ XRPL SDK can:
  - Query account balances
  - Create wallets from seeds
  - Sign transactions
  - Submit payments
- ✅ Full example: Wallet → Query → Build TX → Sign → Submit

### Developer Experience Target

**Better than xrpl-js**:
```javascript
// xrpl-js (TypeScript)
const client = new Client('wss://s1.ripple.com');
await client.connect();
const wallet = Wallet.fromSeed('sEd...');
const payment = {
  TransactionType: 'Payment',
  Account: wallet.address,
  Destination: 'rN7n7...',
  Amount: '1000000'
};
const signed = wallet.sign(payment);
await client.submitAndWait(signed.tx_blob);
```

**ZigScript version** (cleaner, type-safe, compiled):
```zs
let client = xrpl.Client.new("https://s1.ripple.com:51234");
let wallet = xrpl.Wallet.from_seed("sEd...")?;

let payment = xrpl.Payment {
    from: wallet.address,
    to: "rN7n7...",
    drops: "1000000",
};

let tx_hash = await xrpl.sign_and_submit(client, wallet, payment)?;
print("Transaction: " + tx_hash);
```

**Advantages**:
- ✅ Type-safe at compile time
- ✅ No npm/node_modules bloat
- ✅ Compiles to WASM (runs anywhere)
- ✅ Native performance
- ✅ Zig-powered crypto (safer than Node.js)

## Timeline

**Phase 7 Duration**: 7 weeks

- **Week 1-2**: Module system
- **Week 3**: Crypto primitives
- **Week 4**: Bytes type
- **Week 5-6**: XRPL SDK core
- **Week 7**: Transaction builder + examples

**Total**: ~2 months to production-ready XRPL SDK

## Conclusion

Phase 7 transforms ZigScript from a language with stdlib into a **blockchain development platform**. The module system + crypto primitives unlock building SDKs that are:

1. **Type-safe** (compile-time verification)
2. **Fast** (WASM + Zig crypto)
3. **Portable** (runs in browsers, servers, edge)
4. **Clean** (better DX than JavaScript SDKs)

Once XRPL SDK is proven, the pattern extends to **all blockchains**: Ethereum, Solana, Bitcoin, Cosmos, etc.

**Next command**: `Do Phase 7 Sprint 1!` 🚀
