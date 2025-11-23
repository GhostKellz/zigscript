// Main file that imports from wallet module
import { Wallet, create, get_balance } from "wallet";

fn main() -> i32 {
    let wallet = create("rN7n7otQDd6FczFgLdlqtyMVrn3LNU8Ki4");
    let balance = get_balance(wallet);

    return balance;
}
