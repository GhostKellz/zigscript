// Simplified XRPL example
export struct Account {
    address: string,
    balance: i32,
}

export fn create_account(address: string) -> Account {
    return Account {
        address: address,
        balance: 0,
    };
}

fn main() -> i32 {
    let account = create_account("rN7n7otQDd6FczFgLdlqtyMVrn3LNU8Ki4");
    return account.balance;
}
