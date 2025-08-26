use anchor_lang::prelude::*;

declare_id!("F1rLREdWryjrPdcZeqcqctzbiFAUReeJYE8Nmq2ecY9T");

/*
题目#1 编写第一个 Solana 程序（Program）

使用 Anchor 编写一个简单的计数器程序，包含两个指令：

- initialize(ctx) ：用 seed 派生出账户，初始化 count = 0
- increment(ctx) ：将账户中的 count 加 1

请贴出 github 链接
*/

#[program]
pub mod counter {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        ctx.accounts.counter.count = 0;
        msg!("Initialize: {:?}", ctx.program_id);
        msg!("Current Counter: {:?}", ctx.accounts.counter.count);
        Ok(())
    }

    pub fn increment(ctx: Context<Increment>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        msg!("Counter before increment: {:?}", counter.count);
        counter.count += 1;
        msg!("Counter after increment: {:?}", counter.count);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = signer, space = 8 + 8)]
    pub counter: Account<'info, Counter>,
    #[account(mut)]
    pub signer: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Increment<'info> {
    #[account(mut)]
    pub counter: Account<'info, Counter>,
    #[account(mut)]
    pub signer: Signer<'info>,
}

#[account]
pub struct Counter {
    pub count: u64,
}
