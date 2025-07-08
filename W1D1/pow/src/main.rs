/*
题目#1
实践 POW， 编写程序（编程语言不限）用自己的昵称 + nonce，不断修改nonce 进行 sha256 Hash 运算：

直到满足 4 个 0 开头的哈希值，打印出花费的时间、Hash 的内容及Hash值。

再次运算直到满足 5 个 0 开头的哈希值，打印出花费的时间、Hash 的内容及Hash值。
 */


use std::time::{SystemTime, UNIX_EPOCH};
use std::hash::{DefaultHasher, Hash, Hasher};

#[derive(Hash)]
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
    println!("========================================");

    // 满足 6 个 0 开头的哈希值
    test_pow(
        Person {
            name: "ccs".to_string(),
            nonce: rand::random::<u64>(),
        },
        6
    );
}

fn test_pow(mut person: Person, zero_number: usize) {
    assert!(zero_number <= 16);

    let start_time = get_timestamp();
    println!("start time: {}", start_time);

    let mut hash = format!("{:X}", calculate_hash(&person));
    while hash.len() > 16 - zero_number {
        person.nonce = rand::random::<u64>();
        hash = format!("{:X}", calculate_hash(&person));
    }

    let end_time = get_timestamp();
    println!("end time: {}", end_time);
    println!("used time: {} ms", end_time - start_time);

    println!("hash start {} ‘0’: {}", zero_number, format_hash(hash));
}

fn calculate_hash<T: Hash>(t: &T) -> u64 {
    let mut s = DefaultHasher::new();
    t.hash(&mut s);
    s.finish()
}

fn format_hash(mut hash: String) -> String {
    for _ in 0..16 - hash.len() {
        hash = format!("0{}", hash);
    }
    hash
}

fn get_timestamp() -> u128 {
    SystemTime::now().duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis()
}
