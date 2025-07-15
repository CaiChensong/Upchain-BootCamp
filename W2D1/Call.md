## call、delegatecall、staticcall

### 题目#1
以下哪个函数调用不会改变调用合约的状态?

- [ ] 以上都会改变状态
- [ ] delegatecall
- [x] staticcall  
- [ ] call


### 题目#2
以下说法正确的是？

- [ ] call 会在失败时自动回滚事务，而 delegatecall 不会
- [x] delegatecall 会在调用者的上下文中执行被调用合约的代码
- [x] call 会在被调用合约的存储和上下文中执行其代码
- [ ] 使用 call 发送 Ether 时，gas 默认有限制

### 题目#3 staticcall

```
pragma solidity ^0.8.0;

contract Callee {
    function getData() public pure returns (uint256) {
        return 42;
    }
}

contract Caller {
    function callGetData(address callee) public view returns (uint256 data) {
        // call by staticcall

        return data;
    }
}
```
补充完整 Caller 合约的 callGetData 方法，使用 staticcall 调用 Callee 合约中 getData 函数，并返回值。
当调用失败时，抛出“staticcall function failed”异常。

```solidity
pragma solidity ^0.8.0;

contract Callee {
    function getData() public pure returns (uint256) {
        return 42;
    }
}

contract Caller {
    function callGetData(address callee) public view returns (uint256 data) {
        // call by staticcall
        (bool success, bytes memory payload) = callee.staticcall(abi.encodeWithSignature("getData()"));
        require(success, "staticcall function faile");

        return abi.decode(payload, (uint256));
    }
}
```

### 题目#4 使用 call 方法来发送 Ether

```
pragma solidity ^0.8.0;

contract Caller {
    function sendEther(address to, uint256 value) public returns (bool) {
        // 使用 call 发送 ether

        return success;
    }

    receive() external payable {}
}
```
补充完整 Caller 合约 的 sendEther 方法，用于向指定地址发送 Ether。要求：

- 使用 call 方法发送 Ether
- 如果发送失败，抛出“sendEther failed”异常并回滚交易。
- 如果发送成功，则返回 true

```solidity
pragma solidity ^0.8.0;

contract Caller {
    function sendEther(address to, uint256 amount) public returns (bool) {
        // 使用 call 发送 ether
        (bool success, ) = to.call{value: amount}(new bytes(0));
        require(success, "sendEther failed");
        return success;
    }

    receive() external payable {}
}
```

### 题目#5 call 调用函数

```
pragma solidity ^0.8.0;

contract Callee {
    uint256 value;

    function getValue() public view returns (uint256) {
        return value;
    }

    function setValue(uint256 value_) public payable {
        require(msg.value > 0);
        value = value_;
    }
}

contract Caller {
    function callSetValue(address callee, uint256 value) public returns (bool) {
        // call setValue()
    }
}
```
补充完整 Caller 合约的 callSetValue 方法，用于设置 Callee 合约的 value 值。要求：

- 使用 call 方法调用用 Callee 的 setValue 方法，并附带 1 Ether
- 如果发送失败，抛出“call function failed”异常并回滚交易。
- 如果发送成功，则返回 true

```solidity
pragma solidity ^0.8.0;

contract Callee {
    uint256 value;

    function getValue() public view returns (uint256) {
        return value;
    }

    function setValue(uint256 value_) public payable {
        require(msg.value > 0);
        value = value_;
    }
}

contract Caller {
    function callSetValue(address callee, uint256 value) public returns (bool) {
        // call setValue()
        (bool success, ) = callee.call{value: 1 ether}(abi.encodeWithSignature("setValue(uint256)", value));
        require(success, "call function failed");
        return success;
    }
    receive() external payable {}
}
```

### 题目#6 使用 delegatecall 调用函数

```
pragma solidity ^0.8.0;

contract Callee {
    uint256 public value;

    function setValue(uint256 _newValue) public {
        value = _newValue;
    }
}

contract Caller {
    uint256 public value;

    function delegateSetValue(address callee, uint256 _newValue) public {
        // delegatecall setValue()

    }
}
```
补充完整 Caller 合约 的 delegateSetValue 方法，调用 Callee 的 setValue 方法用于设置 value 值。要求：

- 使用 delegatecall
- 如果发送失败，抛出“delegate call failed”异常并回滚交易。

```solidity
pragma solidity ^0.8.0;

contract Callee {
    uint256 public value;

    function setValue(uint256 _newValue) public {
        value = _newValue;
    }
}

contract Caller {
    uint256 public value;

    function delegateSetValue(address callee, uint256 _newValue) public {
        // delegatecall setValue()
        (bool success, ) = callee.delegatecall(abi.encodeWithSignature("setValue(uint256)", _newValue));
        require(success, "delegate call failed");
    }
}
```

