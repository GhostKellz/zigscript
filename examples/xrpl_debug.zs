struct Account {
    address: string,
}

fn make_payment(from: Account, to_address: string) -> i32 {
    return 0;
}

fn main() -> i32 {
    let account = Account { address: "test" };
    let x = make_payment(account, "dest");
    return x;
}
