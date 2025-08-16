// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Timelock - 时间锁合约
 * @dev 为治理提案提供时间延迟机制，防止恶意提案立即执行
 * @dev 支持交易排队、延迟执行和取消功能
 */
contract Timelock is Ownable, ReentrancyGuard {
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, uint256 eta);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, uint256 eta);

    uint256 public constant GRACE_PERIOD = 14 days; // 宽限期：提案执行的有效期
    uint256 public constant MINIMUM_DELAY = 2 days; // 最小延迟时间
    uint256 public constant MAXIMUM_DELAY = 30 days; // 最大延迟时间

    // 当前设置的延迟时间
    uint256 public delay;

    // 已排队的交易映射：交易哈希 => 是否已排队
    mapping(bytes32 => bool) public queuedTransactions;

    /**
     * @dev 构造函数，初始化时间锁合约
     * @param admin 管理员地址，拥有合约控制权限
     * @param delay_ 延迟时间，必须在最小和最大延迟之间
     */
    constructor(address admin, uint256 delay_) Ownable(admin) {
        require(delay_ >= MINIMUM_DELAY, "Timelock::constructor: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::constructor: Delay must not exceed maximum delay.");

        delay = delay_;
    }

    // 允许合约接收 ETH 转账
    receive() external payable {}

    /**
     * @dev 设置新的延迟时间
     * @param delay_ 新的延迟时间
     * @notice 只有时间锁合约本身可以调用此函数
     */
    function setDelay(uint256 delay_) public {
        require(msg.sender == address(this), "Timelock::setDelay: Call must come from Timelock.");
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    /**
     * @dev 将交易排队等待执行
     * @param target 目标合约地址
     * @param amount 交易金额
     * @param eta 预计执行时间
     * @return 交易哈希
     * @notice 只有合约所有者可以排队交易
     */
    function queueTransaction(address target, uint256 amount, uint256 eta) public onlyOwner returns (bytes32) {
        uint256 currentTimestamp = block.timestamp;
        require(
            eta >= currentTimestamp + delay, "Timelock::queueTransaction: Estimated execution block must satisfy delay."
        );

        bytes32 txHash = keccak256(abi.encode(target, amount, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, amount, eta);
        return txHash;
    }

    /**
     * @dev 取消已排队的交易
     * @param target 目标合约地址
     * @param amount 交易金额
     * @param eta 预计执行时间
     * @notice 只有合约所有者可以取消交易
     */
    function cancelTransaction(address target, uint256 amount, uint256 eta) public onlyOwner {
        bytes32 txHash = keccak256(abi.encode(target, amount, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, amount, eta);
    }

    /**
     * @dev 执行已排队的交易
     * @param target 目标合约地址
     * @param amount 交易金额
     * @param eta 预计执行时间
     * @return 交易执行的返回数据
     * @notice 只有合约所有者可以执行交易，且必须满足时间锁要求
     */
    function executeTransaction(address bank, address target, uint256 amount, uint256 eta)
        public
        payable
        onlyOwner
        nonReentrant
        returns (bytes memory)
    {
        bytes32 txHash = keccak256(abi.encode(target, amount, eta));
        require(queuedTransactions[txHash], "Timelock::executeTransaction: Transaction hasn't been queued.");
        require(block.timestamp >= eta, "Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        require(block.timestamp <= eta + GRACE_PERIOD, "Timelock::executeTransaction: Transaction is stale.");

        queuedTransactions[txHash] = false;

        // 直接调用 DaoBank 合约的 withdraw 方法，将资金转移到 Gov 合约
        bytes memory callData = abi.encodeWithSelector(bytes4(keccak256("withdrawTo(uint256,address)")), amount, target);

        (bool success, bytes memory returnData) = bank.call(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, amount, eta);
        return returnData;
    }

    /**
     * @dev 将资金转移到指定的治理合约
     * @param govContract 治理合约地址
     * @param amount 转移金额
     * @notice 只有合约所有者可以调用此函数
     */
    function withdrawToGov(address govContract, uint256 amount) external onlyOwner nonReentrant {
        require(govContract != address(0), "Timelock: invalid gov contract address");
        require(amount <= address(this).balance, "Timelock: insufficient balance");

        (bool success,) = payable(govContract).call{value: amount}("");
        require(success, "Timelock: failed to transfer funds to Gov contract");
    }
}
