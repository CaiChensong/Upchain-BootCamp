import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { assert } from "chai";
import { Counter } from "../target/types/counter";

describe("counter", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.counter as Program<Counter>;

  it("初始化并自增计数", async () => {
    // 创建counter的PDA账户
    const [counterPda, bump] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("counter"), provider.wallet.publicKey.toBuffer()],
      program.programId
    );

    // 初始化计数器账户，count 应为 0
    await program.methods
      .initialize()
      .accountsPartial({
        counter: counterPda,
        signer: provider.wallet.publicKey,
      })
      .rpc();

    let account = await program.account.counter.fetch(counterPda);
    assert.equal(account.count.toNumber(), 0, "初始化后的计数应为 0");

    // 调用自增，count 应为 1
    await program.methods
      .increment()
      .accountsPartial({
        counter: counterPda,
        signer: provider.wallet.publicKey,
      })
      .rpc();

    account = await program.account.counter.fetch(counterPda);
    assert.equal(account.count.toNumber(), 1, "自增后的计数应为 1");
  });
});
