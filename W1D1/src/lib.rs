use std::fmt::Debug;
use sha2::{Digest, Sha256};

mod pow;
mod rsa;
mod simulation;

pub fn calculate_hash<T: Debug>(t: &T) -> String {
    let mut hasher = Sha256::new();
    hasher.update(format!("{:?}", t));
    let result = hasher.finalize();
    hex::encode(result)
}