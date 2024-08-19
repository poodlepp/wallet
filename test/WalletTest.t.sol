// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {Wallet} from "../src/Wallet.sol";

contract WalletTest is StdCheats, Test {
    uint256 private constant PRECISION = 1e8;
    ERC20Mock usdtMock;
    Wallet wallet;
    address public user = address(1);
    address public user2 = address(2);

    function setUp() public {
        usdtMock = new ERC20Mock();
        ERC20Mock(usdtMock).mint(user, 10 ether);

        //创建钱包，充值 10000
        wallet = new Wallet(address(usdtMock));
        ERC20Mock(usdtMock).mint(address(wallet), 10000 * PRECISION);

        // 设置当前区块的时间戳,测试链timstamp过小会有异常
        uint256 newTimestamp = 1672531200; // 2023-01-01 00:00:00 UTC
        vm.warp(newTimestamp);
    }

    /**
     * 普通ERC20 transfer, 用于gas对比
     */
    function testNormalTransfer() public {
        vm.prank(user);
        usdtMock.transfer(user2, 1 ether);
    }

    // 成功调用测试
    function testWithdraw_success() public {
        vm.startPrank(user);
        wallet.withdraw(1 * PRECISION);
        wallet.withdraw(2 * PRECISION);
        wallet.withdraw(3 * PRECISION);
        wallet.withdraw(4 * PRECISION);
        vm.stopPrank();
        assertEq(usdtMock.balanceOf(address(wallet)), 9990 * PRECISION);
    }
    //入参非0场景

    function testWithdraw_0_Illegal() public {
        vm.expectRevert(Wallet.Wallet_Withdraw_Amount_Illegal.selector);
        vm.startPrank(user);
        wallet.withdraw(0);
        vm.stopPrank();
    }

    // 单笔不能超过50
    function testWithdraw_51_Illegal() public {
        vm.expectRevert(Wallet.Wallet_Withdraw_Amount_Illegal.selector);
        vm.startPrank(user);
        wallet.withdraw(51 * PRECISION);
        vm.stopPrank();
    }

    // 连续withdraw不能超过100
    function testWithdraw_101_Illegal() public {
        vm.startPrank(user);
        wallet.withdraw(40 * PRECISION);
        wallet.withdraw(40 * PRECISION);
        vm.expectRevert(Wallet.Wallet_Exceed_Limit.selector);
        wallet.withdraw(40 * PRECISION);
        vm.stopPrank();
    }

    //每12hours提取50$,正常运行； 50次后加速提取，失败
    function testWithdraw_success_next_day() public {
        uint256 nowTime = block.timestamp;
        vm.startPrank(user);
        wallet.withdraw(50 * PRECISION);

        for (uint256 i = 0; i < 50; i++) {
            nowTime += 12 hours;
            vm.warp(nowTime);
            wallet.withdraw(50 * PRECISION);
        }

        // there is 11 hours
        nowTime += 11 hours;
        vm.warp(nowTime);
        vm.expectRevert(Wallet.Wallet_Exceed_Limit.selector);
        wallet.withdraw(50 * PRECISION);
        vm.stopPrank();
    }

    //每3小时提取10$，正常运行； 50次后加速提取，失败
    function testWithdraw_success_frequently() public {
        uint256 nowTime = block.timestamp;
        vm.startPrank(user);
        wallet.withdraw(10 * PRECISION);

        for (uint256 i = 0; i < 50; i++) {
            nowTime += 3 hours;
            vm.warp(nowTime);
            wallet.withdraw(10 * PRECISION);
        }

        // there is 11 hours
        nowTime += 3 hours;
        vm.warp(nowTime);
        vm.expectRevert(Wallet.Wallet_Exceed_Limit.selector);
        wallet.withdraw(40 * PRECISION);
        vm.stopPrank();
    }
}
