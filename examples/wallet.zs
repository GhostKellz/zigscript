// Wallet module example
export struct Wallet {
    address: string,
    balance: i32,
}

export fn create(address: string) -> Wallet {
    return Wallet {
        address: address,
        balance: 0,
    };
}

export fn get_balance(wallet: Wallet) -> i32 {
    return wallet.balance;
}
