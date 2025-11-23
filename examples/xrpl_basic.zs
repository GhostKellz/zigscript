// Basic XRPL functionality
export struct Account {
    address: string,
    balance: i64,
    sequence: i32,
}

export struct Payment {
    from: string,
    to: string,
    amount: i64,
}

export fn create_account(address: string) -> Account {
    return Account {
        address: address,
        balance: 0,
        sequence: 0,
    };
}

export fn make_payment(from: Account, to_address: string, amount: i64) -> Payment {
    return Payment {
        from: from.address,
        to: to_address,
        amount: amount,
    };
}

fn main() -> i32 {
    let account = create_account("rN7n7otQDd6FczFgLdlqtyMVrn3LNU8Ki4");
    let payment = make_payment(account, "rDestination123", 1000000);

    return 0;
}
