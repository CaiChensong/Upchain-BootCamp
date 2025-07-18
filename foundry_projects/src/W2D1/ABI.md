## ABI

### 题目#1
计算以下函数签名的 ABI 编码后的字节大小：
`function transfer(address recipient, uint256 amount)`

```
解答：
编码结果：0xa9059cbb000000000000000000000000ab7c8803962c0f2f5bbbe3fa8bf41cd82aa1923c0000000000000000000000000000000000000000000000000de0b6b3a7640000
共 68 字节
```

### 题目#2 ABI 编码和解码
```
// example code

pragma solidity ^0.8.0;

contract ABIEncoder {
    function encodeUint(uint256 value) public pure returns (bytes memory) {
        //
    }

    function encodeMultiple(
        uint num,
        string memory text
    ) public pure returns (bytes memory) {
       //
    }
}

contract ABIDecoder {
    function decodeUint(bytes memory data) public pure returns (uint) {
        //
    }

    function decodeMultiple(
        bytes memory data
    ) public pure returns (uint, string memory) {
        //
    }
}
```
- 完善ABIEncoder合约的encodeUint和encodeMultiple函数，使用abi.encode对参数进行编码并返回
- 完善ABIDecoder合约的decodeUint和decodeMultiple函数，使用abi.decode将字节数组解码成对应类型的数据

```solidity
pragma solidity ^0.8.0;

contract ABIEncoder {
    function encodeUint(uint256 value) public pure returns (bytes memory) {
        return abi.encode(value);
    }

    function encodeMultiple(
        uint num,
        string memory text
    ) public pure returns (bytes memory) {
        return abi.encode(num, text);
    }
}

contract ABIDecoder {
    function decodeUint(bytes memory data) public pure returns (uint) {
        return abi.decode(data, (uint));
    }

    function decodeMultiple(
        bytes memory data
    ) public pure returns (uint, string memory) {
        return abi.decode(data, (uint, string));
    }
}
```

### 题目#3 函数选择器

```
pragma solidity ^0.8.0;

contract FunctionSelector {
    uint256 private storedValue;

    function getValue() public view returns (uint) {
        return storedValue;
    }

    function setValue(uint value) public {
        storedValue = value;
    }

    function getFunctionSelector1() public pure returns (bytes4) {
        //
    }

    function getFunctionSelector2() public pure returns (bytes4) {
        //
    }
}
```

- 补充完整getFunctionSelector1函数，返回getValue函数的签名
- 补充完整getFunctionSelector2函数，返回setValue函数的签名

```solidity
pragma solidity ^0.8.0;

contract FunctionSelector {
    uint256 private storedValue;

    function getValue() public view returns (uint) {
        return storedValue;
    }

    function setValue(uint value) public {
        storedValue = value;
    }

    function getFunctionSelector1() public pure returns (bytes4) {
        return bytes4(keccak256("getValue()"));
    }

    function getFunctionSelector2() public pure returns (bytes4) {
        return bytes4(keccak256("setValue(uint256)"));
    }
}
```

### 题目#4 encodeWithSignature、encodeWithSelector 和 encodeCall

```
pragma solidity ^0.8.0;

contract DataStorage {
    string private data;

    function setData(string memory newData) public {
        data = newData;
    }

    function getData() public view returns (string memory) {
        return data;
    }
}

contract DataConsumer {
    address private dataStorageAddress;

    constructor(address _dataStorageAddress) {
        dataStorageAddress = _dataStorageAddress;
    }

    function getDataByABI() public returns (string memory) {
        // payload
        (bool success, bytes memory data) = dataStorageAddress.call(payload);
        require(success, "call function failed");
        
        // return data
    }

    function setDataByABI1(string calldata newData) public returns (bool) {
        // playload
        (bool success, ) = dataStorageAddress.call(payload);

        return success;
    }

    function setDataByABI2(string calldata newData) public returns (bool) {
        // selector
        // playload

        (bool success, ) = dataStorageAddress.call(payload);

        return success;
    }

    function setDataByABI3(string calldata newData) public returns (bool) {
        // playload

        (bool success, ) = dataStorageAddress.call(playload);
        return success;
    }
}
```

- 补充完整getDataByABI，对getData函数签名及参数进行编码，调用成功后解码并返回数据
- 补充完整setDataByABI1，使用abi.encodeWithSignature()编码调用setData函数，确保调用能够成功
- 补充完整setDataByABI2，使用abi.encodeWithSelector()编码调用setData函数，确保调用能够成功
- 补充完整setDataByABI3，使用abi.encodeCall()编码调用setData函数，确保调用能够成功

```solidity
pragma solidity ^0.8.0;

contract DataStorage {
    string private data;

    function setData(string memory newData) public {
        data = newData;
    }

    function getData() public view returns (string memory) {
        return data;
    }
}

contract DataConsumer {
    address private dataStorageAddress;

    constructor(address _dataStorageAddress) {
        dataStorageAddress = _dataStorageAddress;
    }

    function getDataByABI() public returns (string memory) {
        // payload
        bytes memory payload =  abi.encodeWithSignature("getData()");
        (bool success, bytes memory data) = dataStorageAddress.call(payload);
        require(success, "call function \"getData()\" failed");

        // return data
        return abi.decode(data, (string));
    }

    function setDataByABI1(string calldata newData) public returns (bool) {
        // signature
        // payload
        bytes memory payload =  abi.encodeWithSignature("setData(string)", newData);
        (bool success, ) = dataStorageAddress.call(payload);
        require(success, "call function \"setData(string)\" failed");

        return success;
    }

    function setDataByABI2(string calldata newData) public returns (bool) {
        // selector
        // payload
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("setData(string)")), newData);
        (bool success, ) = dataStorageAddress.call(payload);
        require(success, "call function \"setData(string)\" failed");

        return success;
    }

    function setDataByABI3(string calldata newData) public returns (bool) {
        // call
        // payload
        bytes memory payload = abi.encodeCall(DataStorage.setData, (newData));
        (bool success, ) = dataStorageAddress.call(payload);
        require(success, "call function \"setData(string)\" failed");

        return success;
    }
}
```
