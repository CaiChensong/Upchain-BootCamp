// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/*
- 实现 TokenBank 存款合约，添加一个函数 permitDeposit 以支持离线签名授权（permit）进行存款。

- 在原来的 TokenBank 添加一个方法 depositWithPermit2()， 这个方法使用 permit2 进行签名授权转账来进行存款。
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract TokenBankPermit {
    IPermit2 public immutable permit2;
    IERC20 public token;
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address _token, address _permit2) {
        require(_token != address(0), "TokenBank: token address must be non-zero");
        require(_permit2 != address(0), "TokenBank: permit2 address must be non-zero");
        token = IERC20(_token);
        permit2 = IPermit2(_permit2);
    }

    receive() external payable {}

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "TokenBank: withdraw amount must be greater than zero");
        require(amount <= balances[msg.sender], "TokenBank: balance is not enough");

        balances[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "TokenBank: transfer failed");
        emit Withdraw(msg.sender, amount);
    }

    function deposit(uint256 amount) public payable {
        require(amount > 0, "TokenBank: deposit amount must be greater than zero");
        require(token.balanceOf(msg.sender) >= amount, "TokenBank: balance is not enough");

        require(token.transferFrom(msg.sender, address(this), amount), "TokenBank: transfer failed");
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function depositWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        require(amount > 0, "TokenBank: deposit amount must be greater than zero");
        require(token.balanceOf(msg.sender) >= amount, "TokenBank: balance is not enough");

        // owner：代币持有者（签名者）地址, spender：被授权消费代币的地址
        IERC20Permit(address(token)).permit(msg.sender, address(this), amount, deadline, v, r, s);

        require(token.transferFrom(msg.sender, address(this), amount), "TokenBank: transfer failed");
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function depositWithPermit2(uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature) public {
        require(amount > 0, "TokenBank: deposit amount must be greater than zero");
        require(token.balanceOf(msg.sender) >= amount, "TokenBank: balance is not enough");

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(token), amount: amount}),
            nonce: nonce,
            deadline: deadline
        });

        ISignatureTransfer.SignatureTransferDetails memory transferDetails =
            ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: amount});

        permit2.permitTransferFrom(permit, transferDetails, msg.sender, signature);

        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }
}

interface ISignatureTransfer {
    struct TokenPermissions {
        // ERC20 token address
        address token;
        // the maximum amount that can be spent
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        // a unique value for every token owner's signature to prevent signature replays
        uint256 nonce;
        // deadline on the permit signature
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        // recipient address
        address to;
        // spender requested amount
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

interface IPermit2 is ISignatureTransfer {}
