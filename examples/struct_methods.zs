struct Counter {
    value: i32,

    fn increment() -> void {
        self.value = self.value + 1;
    }

    fn get() -> i32 {
        return self.value;
    }
}

fn main() -> i32 {
    let counter = Counter { value: 10 };
    counter.increment();
    counter.increment();
    return counter.get();
}
