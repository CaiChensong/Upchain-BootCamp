/*
题目#2
实践非对称加密 RSA（编程语言不限）：

先生成一个公私钥对，
用私钥对符合 POW 4 个 0 开头的哈希值的 “昵称 + nonce” 进行私钥签名，
用公钥验证
 */
use std::fmt::Debug;
use rsa::{Pkcs1v15Encrypt, RsaPrivateKey, RsaPublicKey};
use hex;
use crate::calculate_hash;

#[derive(Debug, Clone)]
struct Person {
    name: String,
    nonce: u64,
}

#[test]
fn test() {
    let mut rng = rand::thread_rng();
    let bits = 2048;
    let private_key = RsaPrivateKey::new(&mut rng, bits).expect("failed to generate a key");
    let pub_key = RsaPublicKey::from(&private_key);

    let hash = get_hash(
        Person {
            name: "ccs".to_string(),
            nonce: rand::random::<u64>()
        },
        4);
    println!("hash: {}", hash);

    // Encrypt
    let enc_data = pub_key.encrypt(&mut rng, Pkcs1v15Encrypt, hash.as_bytes()).expect("failed to encrypt");
    assert_ne!(hash.as_bytes(), &enc_data[..]);
    println!("hash bytes: {}", hex::encode(hash.as_bytes()));
    println!("encrypt data: {}", hex::encode(&enc_data));

    // Decrypt
    let dec_data = private_key.decrypt(Pkcs1v15Encrypt, &enc_data).expect("failed to decrypt");
    assert_eq!(hash.as_bytes(), &dec_data[..]);
    println!("decrypt data is equal to the original hash data!");
}


fn get_hash(mut person: Person, zero_number: usize) -> String {
    assert!(zero_number <= 64);

    let mut hash = calculate_hash(&person);
    let prefix = "0".repeat(zero_number);
    while !hash.starts_with(&prefix) {
        person.nonce = rand::random::<u64>();
        hash = calculate_hash(&person);
    }
    hash
}

