// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
/**
 * 假设已经完成合约充值,有充足的金额
 */

contract Wallet is Test {
    error Wallet_Exceed_Limit();
    error Wallet_Withdraw_Amount_Illegal();
    error Wallet_Transfer_Error();

    uint256 private constant PRECISION = 1e8;
    uint256 public startKey;
    uint256 public endKey;
    ERC20 public usdt;

    /**
     *  val结构
     * 高128bit  存放当前时间点取出的amount
     * 低128bit  存放下一个时间点的key
     */
    mapping(uint256 => uint256) public moneyInOneDayMap;

    modifier amountIllegal(uint256 amount) {
        if (amount == 0 || amount > 50 * PRECISION) {
            revert Wallet_Withdraw_Amount_Illegal();
        }
        _;
    }

    constructor(address usdtAddr) {
        usdt = ERC20(usdtAddr);
    }

    function withdraw(uint256 amount) external amountIllegal(amount) returns (bool rst) {
        uint256 nowTime = block.timestamp;

        // 24H内已提取金额
        uint256 paidMoney = 0;
        // 最后一次取款金额
        uint256 endAmount = 0;
        uint256 limit = nowTime - 1 days;

        uint256 localEndKey = endKey; // Store endKey in a local variable
        uint256 localStartKey = startKey; // Store startKey in a local variable

        if (endKey != 0) {
            (endAmount, paidMoney) = split(moneyInOneDayMap[localEndKey]);
        }

        while (limit >= localStartKey && localStartKey > 0) {
            uint256 val = moneyInOneDayMap[localStartKey];
            delete moneyInOneDayMap[localStartKey];
            (uint256 oldAmount, uint256 timeKey) = split(val);
            paidMoney -= oldAmount;
            localStartKey = timeKey;
        }

        uint256 newPaidMoney = paidMoney + amount;
        if (paidMoney + amount > 100 * PRECISION) {
            revert Wallet_Exceed_Limit();
        }

        if (localStartKey == 0) {
            localStartKey = nowTime;
            localEndKey = nowTime;
            moneyInOneDayMap[localStartKey] = merge(amount, amount);
        } else {
            moneyInOneDayMap[localEndKey] = merge(endAmount, nowTime);
            moneyInOneDayMap[nowTime] = merge(amount, newPaidMoney);
        }

        startKey = localStartKey; // Update the state variable
        endKey = nowTime; // Update the state variable

        //transfer
        bool mark = usdt.transfer(msg.sender, amount);
        if (!mark) {
            revert Wallet_Transfer_Error();
        }
        return true;
    }

    function split(uint256 val) internal pure returns (uint256, uint256) {
        uint256 timeKey = val & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        uint256 amount = val >> 128;
        return (amount, timeKey);
    }

    function merge(uint256 amount, uint256 timeKey) internal pure returns (uint256) {
        return amount << 128 | timeKey;
    }
}
