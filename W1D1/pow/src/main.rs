/*
题目#1
实践 POW， 编写程序（编程语言不限）用自己的昵称 + nonce，不断修改nonce 进行 sha256 Hash 运算：

直到满足 4 个 0 开头的哈希值，打印出花费的时间、Hash 的内容及Hash值。

再次运算直到满足 5 个 0 开头的哈希值，打印出花费的时间、Hash 的内容及Hash值。
 */
use std::fmt::{Debug, Display};
use std::time::{SystemTime, UNIX_EPOCH};
use sha2::{Sha256, Digest};
use hex;

#[derive(Debug)]
struct Person {
    name: String,
    nonce: u64,
}

fn main() {

    // 满足 4 个 0 开头的哈希值
    test_pow(
        Person {
            name: "ccs".to_string(),
            nonce: rand::random::<u64>(),
        },
        4
    );
    println!("========================================");

    // 满足 5 个 0 开头的哈希值
    test_pow(
        Person {
            name: "ccs".to_string(),
            nonce: rand::random::<u64>(),
        },
        5
    );
}

fn test_pow(mut person: Person, zero_number: usize) {
    assert!(zero_number <= 64);

    let start_time = get_timestamp();
    println!("start time: {}", start_time);

    let mut hash = calculate_hash(&person);
    let prefix = "0".repeat(zero_number);
    while !hash.starts_with(&prefix) {
        person.nonce = rand::random::<u64>();
        hash = calculate_hash(&person);
    }

    let end_time = get_timestamp();
    println!("end time: {}", end_time);
    println!("used time: {} ms", end_time - start_time);

    println!("hash start {} ‘0’: {}", zero_number, hash);
}

fn calculate_hash<T: Debug>(t: &T) -> String {
    let mut hasher = Sha256::new();
    hasher.update(format!("{:?}", t));
    let result = hasher.finalize();
    hex::encode(result)
}

fn get_timestamp() -> u128 {
    SystemTime::now().duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis()
}
