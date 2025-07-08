use sha2::{Digest, Sha256};

#[derive(Debug, Clone)]
struct Transaction {
    sender: String,
    recipient: String,
    amount: usize,
}

#[derive(Debug, Clone)]
struct Block {
    index: usize,
    timestamp: u64,
    transactions: Vec<Transaction>,
    proof: usize,
    previous_hash: String,
}

#[derive(Debug, Clone)]
struct Blockchain {
    chain: Vec<Block>,
    current_transactions: Vec<Transaction>,
}

impl Blockchain {
    fn new() -> Self {
        let mut blockchain = Blockchain {
            chain: Vec::new(),
            current_transactions: vec![],
        };
        blockchain.new_block(111, "abc".to_string());
        blockchain
    }

    fn new_block(&mut self, proof: usize, previous_hash: String) -> &Block {
        let block = Block {
            index: self.chain.len() + 1,
            timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs(),
            transactions: self.current_transactions.clone(),
            proof,
            previous_hash,
        };
        self.current_transactions.clear();
        self.chain.push(block);
        self.chain.last().unwrap()
    }

    fn new_transaction(&mut self, sender: String, recipient: String, amount: usize) {
        self.current_transactions.push(Transaction { sender, recipient, amount });
    }

    fn last_block(&self) -> &Block {
        self.chain.last().unwrap()
    }

    fn get_proof(&self, last_hash: &str) -> usize {
        let mut proof = 0;
        while !Self::valid_proof(proof, last_hash) {
            proof += 1;
        }
        proof
    }

    fn valid_proof(proof: usize, last_hash: &str) -> bool {
        let mut hasher = Sha256::new();
        hasher.update(format!("{}{}", last_hash, proof));
        let result = hasher.finalize();
        hex::encode(result).starts_with("0000")
    }

    fn calculate_hash(block: &Block) -> String {
        let mut hasher = Sha256::new();
        hasher.update(format!("{:?}", block));
        let result = hasher.finalize();
        hex::encode(result)
    }
}


fn main() {
    let mut blockchain = Blockchain::new();
    println!("first block: {:?}", blockchain.last_block());

    blockchain.new_transaction("aaa".to_string(), "bbb".to_string(), 3);

    let last_block = blockchain.last_block();
    let last_hash = Blockchain::calculate_hash(&last_block);
    let proof = blockchain.get_proof(last_hash.as_str());

    let new_block = blockchain.new_block(proof, last_hash);
    println!("second block: {:?}", new_block);

    blockchain.new_transaction("aaa".to_string(), "bbb".to_string(), 3);
    blockchain.new_transaction("ccc".to_string(), "ddd".to_string(), 1);
    blockchain.new_transaction("eee".to_string(), "fff".to_string(), 2);

    let last_block = blockchain.last_block();
    let last_hash = Blockchain::calculate_hash(&last_block);
    let proof = blockchain.get_proof(last_hash.as_str());

    let new_block = blockchain.new_block(proof, last_hash);
    println!("new block: {:?}", new_block);
}

