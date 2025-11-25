/**
 * ZigScript WebAssembly Runtime
 * Provides host functions for JSON, HTTP, FS, and async operations
 */

class ZigScriptRuntime {
    constructor() {
        this.memory = new WebAssembly.Memory({ initial: 256 });
        this.textDecoder = new TextDecoder('utf-8');
        this.textEncoder = new TextEncoder();
        this.nextStringOffset = 8192; // Start after reserved memory
        this.promises = new Map(); // Track pending promises
        this.nextPromiseId = 1;
        this.timeouts = new Map();
        this.nextTimeoutId = 1;
    }

    /**
     * Read a string from WASM memory
     * String format: [length: i32][...bytes...]
     */
    readString(ptr) {
        const view = new DataView(this.memory.buffer);
        const length = view.getUint32(ptr, true);
        const bytes = new Uint8Array(this.memory.buffer, ptr + 4, length);
        return this.textDecoder.decode(bytes);
    }

    /**
     * Write a string to WASM memory
     * Returns pointer to string
     */
    writeString(str) {
        const bytes = this.textEncoder.encode(str);
        const ptr = this.nextStringOffset;
        const view = new DataView(this.memory.buffer);

        // Write length
        view.setUint32(ptr, bytes.length, true);

        // Write bytes
        const dest = new Uint8Array(this.memory.buffer, ptr + 4, bytes.length);
        dest.set(bytes);

        this.nextStringOffset += 4 + bytes.length + (4 - (bytes.length % 4)); // Align to 4 bytes
        return ptr;
    }

    /**
     * JSON decode: Convert JSON string to ZigScript value
     * @param {number} json_ptr - Pointer to JSON string in WASM memory
     * @param {number} type_ptr - Pointer to type name (for type checking)
     * @returns {number} Pointer to decoded value
     */
    json_decode(json_ptr, type_ptr) {
        try {
            const jsonStr = this.readString(json_ptr);
            const obj = JSON.parse(jsonStr);

            // For now, just return the JSON string ptr
            // Full implementation would create ZigScript struct in memory
            console.log('[JSON] Decoded:', obj);
            return json_ptr;
        } catch (e) {
            console.error('[JSON] Decode error:', e);
            return 0; // null pointer indicates error
        }
    }

    /**
     * JSON encode: Convert ZigScript value to JSON string
     * @param {number} value_ptr - Pointer to value in WASM memory
     * @returns {number} Pointer to JSON string
     */
    json_encode(value_ptr) {
        try {
            // For now, return empty object
            // Full implementation would read struct fields from memory
            const jsonStr = '{}';
            console.log('[JSON] Encoded:', jsonStr);
            return this.writeString(jsonStr);
        } catch (e) {
            console.error('[JSON] Encode error:', e);
            return 0;
        }
    }

    /**
     * HTTP GET request
     * @param {number} url_ptr - Pointer to URL string
     * @param {number} headers_ptr - Pointer to headers (optional)
     * @returns {number} Promise ID
     */
    http_get(url_ptr, headers_ptr) {
        const url = this.readString(url_ptr);
        const promiseId = this.nextPromiseId++;

        console.log(`[HTTP] GET ${url}`);

        const promise = fetch(url)
            .then(res => res.text())
            .then(body => {
                const ptr = this.writeString(body);
                this.promises.set(promiseId, { resolved: true, value: ptr });
                return ptr;
            })
            .catch(err => {
                console.error('[HTTP] GET error:', err);
                this.promises.set(promiseId, { resolved: false, error: err.message });
                return 0;
            });

        this.promises.set(promiseId, { resolved: false, promise });
        return promiseId;
    }

    /**
     * HTTP POST request
     * @param {number} url_ptr - Pointer to URL string
     * @param {number} headers_ptr - Pointer to headers
     * @param {number} body_ptr - Pointer to request body
     * @param {number} body_len - Length of body
     * @returns {number} Promise ID
     */
    http_post(url_ptr, headers_ptr, body_ptr, body_len) {
        const url = this.readString(url_ptr);
        const body = this.readString(body_ptr);
        const promiseId = this.nextPromiseId++;

        console.log(`[HTTP] POST ${url}`, body);

        const promise = fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: body
        })
            .then(res => res.text())
            .then(responseBody => {
                const ptr = this.writeString(responseBody);
                this.promises.set(promiseId, { resolved: true, value: ptr });
                return ptr;
            })
            .catch(err => {
                console.error('[HTTP] POST error:', err);
                this.promises.set(promiseId, { resolved: false, error: err.message });
                return 0;
            });

        this.promises.set(promiseId, { resolved: false, promise });
        return promiseId;
    }

    /**
     * Read file (simulated with localStorage in browser)
     * @param {number} path_ptr - Pointer to file path
     * @param {number} encoding_ptr - Pointer to encoding (utf8, etc.)
     * @returns {number} Promise ID
     */
    fs_read_file(path_ptr, encoding_ptr) {
        const path = this.readString(path_ptr);
        const promiseId = this.nextPromiseId++;

        console.log(`[FS] Reading file: ${path}`);

        // Simulate async file read
        setTimeout(() => {
            const content = localStorage.getItem(`file:${path}`) || '';
            const ptr = this.writeString(content);
            this.promises.set(promiseId, { resolved: true, value: ptr });
        }, 10);

        this.promises.set(promiseId, { resolved: false });
        return promiseId;
    }

    /**
     * Write file (simulated with localStorage)
     * @param {number} path_ptr - Pointer to file path
     * @param {number} content_ptr - Pointer to content
     * @param {number} encoding_ptr - Pointer to encoding
     * @param {number} flags - Write flags
     * @returns {number} Promise ID
     */
    fs_write_file(path_ptr, content_ptr, encoding_ptr, flags) {
        const path = this.readString(path_ptr);
        const content = this.readString(content_ptr);
        const promiseId = this.nextPromiseId++;

        console.log(`[FS] Writing file: ${path}`, content.substring(0, 100));

        // Simulate async file write
        setTimeout(() => {
            localStorage.setItem(`file:${path}`, content);
            this.promises.set(promiseId, { resolved: true, value: 1 });
        }, 10);

        this.promises.set(promiseId, { resolved: false });
        return promiseId;
    }

    /**
     * Set timeout
     * @param {number} callback_index - Function table index for callback
     * @param {number} delay - Delay in milliseconds
     * @returns {number} Timeout ID
     */
    set_timeout(callback_index, delay) {
        const timeoutId = this.nextTimeoutId++;

        const handle = setTimeout(() => {
            console.log(`[TIMER] Timeout ${timeoutId} fired`);
            // Call the callback from function table
            if (this.wasmInstance && this.wasmInstance.exports.__indirect_function_table) {
                const table = this.wasmInstance.exports.__indirect_function_table;
                const callback = table.get(callback_index);
                if (callback) {
                    callback();
                }
            }
            this.timeouts.delete(timeoutId);
        }, delay);

        this.timeouts.set(timeoutId, handle);
        console.log(`[TIMER] Set timeout ${timeoutId} for ${delay}ms`);
        return timeoutId;
    }

    /**
     * Clear timeout
     * @param {number} timeout_id - Timeout ID to clear
     */
    clear_timeout(timeout_id) {
        const handle = this.timeouts.get(timeout_id);
        if (handle) {
            clearTimeout(handle);
            this.timeouts.delete(timeout_id);
            console.log(`[TIMER] Cleared timeout ${timeout_id}`);
        }
    }

    /**
     * Await a promise
     * @param {number} promise_id - Promise ID to await
     * @returns {number} Result value (0 if not ready)
     */
    promise_await(promise_id) {
        const promiseData = this.promises.get(promise_id);
        if (!promiseData) {
            console.error(`[PROMISE] Promise ${promise_id} not found`);
            return 0;
        }

        if (promiseData.resolved) {
            console.log(`[PROMISE] Promise ${promise_id} resolved with value`);
            return promiseData.value || 0;
        }

        // Not yet resolved - in real implementation, this would suspend
        console.log(`[PROMISE] Promise ${promise_id} still pending`);
        return 0;
    }

    /**
     * Console log
     * @param {number} ptr - Pointer to string
     * @param {number} len - Length of string
     */
    js_console_log(ptr, len) {
        const str = this.readString(ptr);
        console.log('[ZigScript]', str);
    }

    /**
     * Get import object for WebAssembly instantiation
     */
    getImports() {
        return {
            env: {
                memory: this.memory,
                js_console_log: this.js_console_log.bind(this),
            },
            std: {
                json_decode: this.json_decode.bind(this),
                json_encode: this.json_encode.bind(this),
                http_get: this.http_get.bind(this),
                http_post: this.http_post.bind(this),
                fs_read_file: this.fs_read_file.bind(this),
                fs_write_file: this.fs_write_file.bind(this),
                set_timeout: this.set_timeout.bind(this),
                clear_timeout: this.clear_timeout.bind(this),
                promise_await: this.promise_await.bind(this),
            },
        };
    }

    /**
     * Load and run a ZigScript WASM module
     * @param {string} wasmPath - Path to .wasm file
     */
    async run(wasmPath) {
        console.log(`[Runtime] Loading ${wasmPath}...`);

        const response = await fetch(wasmPath);
        const bytes = await response.arrayBuffer();
        const result = await WebAssembly.instantiate(bytes, this.getImports());

        this.wasmInstance = result.instance;
        console.log('[Runtime] Module loaded');

        // Run main function if it exists
        if (result.instance.exports.main) {
            console.log('[Runtime] Running main()...');
            const exitCode = result.instance.exports.main();
            console.log(`[Runtime] main() returned: ${exitCode}`);
            return exitCode;
        }

        return 0;
    }
}

// For Node.js usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ZigScriptRuntime;
}

// For browser usage
if (typeof window !== 'undefined') {
    window.ZigScriptRuntime = ZigScriptRuntime;
}
