//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#3
staticcall

补充完整 Caller 合约的 callGetData 方法，使用 staticcall 调用 Callee 合约中 getData 函数，并返回值。
当调用失败时，抛出“staticcall function failed”异常。
*/
contract Callee3 {
    function getData() public pure returns (uint256) {
        return 42;
    }

    receive() external payable {}
}

contract Caller3 {
    function callGetData(address callee) public view returns (uint256 data) {
        // call by staticcall
        (bool success, bytes memory payload) = callee.staticcall(abi.encodeWithSignature("getData()"));
        require(success, "staticcall function faile");

        return abi.decode(payload, (uint256));
    }
}

/*
题目#4
使用 call 方法来发送 Ether

补充完整 Caller 合约 的 sendEther 方法，用于向指定地址发送 Ether。要求：

- 使用 call 方法发送 Ether
- 如果发送失败，抛出“sendEther failed”异常并回滚交易。
- 如果发送成功，则返回 true
*/

contract Callee4 {
    receive() external payable {}
}

contract Caller4 {
    function sendEther(address to, uint256 amount) public returns (bool) {
        // 使用 call 发送 ether
        (bool success,) = to.call{value: amount}(new bytes(0));
        require(success, "sendEther failed");
        return success;
    }

    receive() external payable {}
}

/*
题目#5
call 调用函数

补充完整 Caller 合约的 callSetValue 方法，用于设置 Callee 合约的 value 值。要求：

- 使用 call 方法调用用 Callee 的 setValue 方法，并附带 1 Ether
- 如果发送失败，抛出“call function failed”异常并回滚交易。
- 如果发送成功，则返回 true
*/

contract Callee5 {
    uint256 value;

    function getValue() public view returns (uint256) {
        return value;
    }

    function setValue(uint256 value_) public payable {
        require(msg.value > 0);
        value = value_;
    }
}

contract Caller5 {
    function callSetValue(address callee, uint256 value) public returns (bool) {
        // call setValue()
        (bool success,) = callee.call{value: 1 ether}(abi.encodeWithSignature("setValue(uint256)", value));
        require(success, "call function failed");
        return success;
    }

    receive() external payable {}
}

/*
题目#6
使用 delegatecall 调用函数

补充完整 Caller 合约 的 delegateSetValue 方法，调用 Callee 的 setValue 方法用于设置 value 值。要求：

- 使用 delegatecall
- 如果发送失败，抛出“delegate call failed”异常并回滚交易。
*/
contract Callee6 {
    uint256 public value;

    function setValue(uint256 _newValue) public {
        value = _newValue;
    }
}

contract Caller6 {
    uint256 public value;

    function delegateSetValue(address callee, uint256 _newValue) public {
        // delegatecall setValue()
        (bool success,) = callee.delegatecall(abi.encodeWithSignature("setValue(uint256)", _newValue));
        require(success, "delegate call failed");
    }
}
