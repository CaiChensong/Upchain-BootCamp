import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { assert } from "chai";
import { Counter } from "../target/types/counter";

describe("counter", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.counter as Program<Counter>;

  it("初始化并自增计数", async () => {
    const counterKeypair = anchor.web3.Keypair.generate();

    // 初始化计数器账户，count 应为 0
    await program.methods
      .initialize()
      .accounts({
        counter: counterKeypair.publicKey,
        signer: provider.wallet.publicKey,
      })
      .signers([counterKeypair])
      .rpc();

    let account = await program.account.counter.fetch(counterKeypair.publicKey);
    assert.equal(account.count.toNumber(), 0, "初始化后的计数应为 0");

    // 调用自增，count 应为 1
    await program.methods
      .increment()
      .accounts({
        counter: counterKeypair.publicKey,
        signer: provider.wallet.publicKey,
      })
      .rpc();

    account = await program.account.counter.fetch(counterKeypair.publicKey);
    assert.equal(account.count.toNumber(), 1, "自增后的计数应为 1");
  });
});
