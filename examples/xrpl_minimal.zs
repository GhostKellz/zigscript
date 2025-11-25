export struct Account {
    address: string,
    balance: i64,
}

export fn create_account(address: string) -> Account {
    return Account {
        address: address,
        balance: 0,
    };
}

fn main() -> i32 {
    return 0;
}
