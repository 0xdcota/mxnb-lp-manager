// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MxnbLpManager} from "../../src/MxnbLpManager.sol";
import {IUniswapV3Pool} from "../../src/interfaces/uniswap-v3/IUniswapV3Pool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockPriceFeed} from "../mocks/MockPriceFeed.sol";
import {MockUniswapV3Pool} from "../mocks/MockUniswapV3Pool.sol";

contract TestUnitMxnbLpManager is Test {
    MxnbLpManager public lpManager;
    MockERC20 public token0;
    MockERC20 public token1;
    MockUniswapV3Pool public pool;
    MockPriceFeed public usdOracle0;
    MockPriceFeed public usdOracle1;

    address public constant ZERO_ADDRESS = address(0);
    address public owner;
    address public user1;
    address public user2;
    address public rebalancer;

    uint256 public constant PRECISION = 10 ** 18;
    uint256 public constant FULL_PERCENT = 10000;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        rebalancer = makeAddr("rebalancer");

        vm.startPrank(owner);

        // Deploy mock tokens
        token0 = new MockERC20("Token0", "TK0", 18);
        token1 = new MockERC20("Token1", "TK1", 18);

        // Deploy mock pool
        pool = new MockUniswapV3Pool(address(token0), address(token1), 60);

        // Deploy mock price feeds
        usdOracle0 = new MockPriceFeed(100000000, 8, "Token0/USD"); // $1.00
        usdOracle1 = new MockPriceFeed(100000000, 8, "Token1/USD"); // $1.00

        // Deploy LP Manager
        lpManager = new MxnbLpManager(address(pool), address(usdOracle0), address(usdOracle1));

        // Set up rebalancer
        lpManager.setApprovedRebalancer(rebalancer, true);

        vm.stopPrank();

        // Mint tokens to users
        token0.mint(user1, 1000 * 10 ** 18);
        token1.mint(user1, 1000 * 10 ** 18);
        token0.mint(user2, 1000 * 10 ** 18);
        token1.mint(user2, 1000 * 10 ** 18);
    }

    // Constructor Tests
    function testConstructor() public view {
        assertEq(lpManager.pool(), address(pool));
        assertEq(lpManager.token0(), address(token0));
        assertEq(lpManager.token1(), address(token1));
        assertEq(lpManager.owner(), owner);
        assertEq(lpManager.feeRecipient(), owner);
        assertEq(lpManager.fee(), lpManager.DEFAULT_BASE_FEE());
        assertEq(lpManager.feeSplit(), lpManager.DEFAULT_BASE_FEE_SPLIT());
        assertTrue(lpManager.allowToken0());
        assertTrue(lpManager.allowToken1());
        assertTrue(lpManager.approvedRebalancer(owner));
    }

    function testConstructorSetsCorrectTokenMetadata() public view {
        assertEq(lpManager.name(), "LpToken: TK0-TK1");
        assertEq(lpManager.symbol(), "Lp-TK0-TK1");
        assertEq(lpManager.decimals(), 18);
    }

    // Setter Function Tests
    function testSetActiveDepositorWhitelist() public {
        vm.prank(owner);
        lpManager.setActiveDepositorWhitelist(true);
        assertTrue(lpManager.activeDepositorWhitelist());

        vm.prank(owner);
        lpManager.setActiveDepositorWhitelist(false);
        assertFalse(lpManager.activeDepositorWhitelist());
    }

    function testSetActiveDepositorWhitelistRevertsIfAlreadySet() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_AlreadySet()"));
        lpManager.setActiveDepositorWhitelist(false); // Already false by default
    }

    function testSetActiveDepositorWhitelistRevertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        lpManager.setActiveDepositorWhitelist(true);
    }

    function testSetDepositor() public {
        vm.prank(owner);
        lpManager.setDepositor(user1, true);
        assertTrue(lpManager.approvedDepositor(user1));

        vm.prank(owner);
        lpManager.setDepositor(user1, false);
        assertFalse(lpManager.approvedDepositor(user1));
    }

    function testSetDepositorRevertsForZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_ZeroAddress()"));
        lpManager.setDepositor(ZERO_ADDRESS, true);
    }

    function testSetAllowedTokens() public {
        vm.prank(owner);
        lpManager.setAlowedTokens(false, true);
        assertFalse(lpManager.allowToken0());
        assertTrue(lpManager.allowToken1());

        vm.prank(owner);
        lpManager.setAlowedTokens(true, false);
        assertTrue(lpManager.allowToken0());
        assertFalse(lpManager.allowToken1());
    }

    function testSetUsdOracles() public {
        MockPriceFeed newOracle0 = new MockPriceFeed(110000000, 8, "NewToken0/USD");
        MockPriceFeed newOracle1 = new MockPriceFeed(90000000, 8, "NewToken1/USD");

        vm.prank(owner);
        lpManager.setUsdOracles(address(newOracle0), address(newOracle1));

        assertEq(address(lpManager.usdOracle0Ref()), address(newOracle0));
        assertEq(address(lpManager.usdOracle1Ref()), address(newOracle1));
    }

    function testSetUsdOraclesRevertsForZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_ZeroAddress()"));
        lpManager.setUsdOracles(ZERO_ADDRESS, address(usdOracle1));
    }

    function testSetBpsRanges() public {
        vm.prank(owner);
        lpManager.setBpsRanges(1000, 2000);
        assertEq(lpManager.bpsRangeLower(), 1000);
        assertEq(lpManager.bpsRangeUpper(), 2000);
    }

    function testSetBpsRangesRevertsForInvalidRange() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_InvalidBaseBpsRange()"));
        lpManager.setBpsRanges(0, 1000); // Lower bound cannot be 0

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_InvalidBaseBpsRange()"));
        lpManager.setBpsRanges(1000, 0); // Upper bound cannot be 0

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_InvalidBaseBpsRange()"));
        lpManager.setBpsRanges(10001, 1000); // Exceeds FULL_PERCENT
    }

    function testSetFeeRecipient() public {
        vm.prank(owner);
        lpManager.setFeeRecipient(user1);
        assertEq(lpManager.feeRecipient(), user1);
    }

    function testSetFeeRecipientRevertsForZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_ZeroAddress()"));
        lpManager.setFeeRecipient(ZERO_ADDRESS);
    }

    function testSetFee() public {
        uint256 newFee = PRECISION / 10; // 10%
        vm.prank(owner);
        lpManager.setFee(newFee);
        assertEq(lpManager.fee(), newFee);
    }

    function testSetFeeRevertsIfExceedsPrecision() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_FeeMustBeLtePrecision()"));
        lpManager.setFee(PRECISION + 1);
    }

    function testSetFeeSplit() public {
        uint256 newFeeSplit = PRECISION * 6 / 10; // 60%
        vm.prank(owner);
        lpManager.setFeeSplit(newFeeSplit);
        assertEq(lpManager.feeSplit(), newFeeSplit);
    }

    function testSetFeeSplitRevertsIfExceedsPrecision() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_SplitMustBeLtePrecision()"));
        lpManager.setFeeSplit(PRECISION + 1);
    }

    function testSetHysteresis() public {
        uint256 newHysteresis = PRECISION / 20; // 5%
        vm.prank(owner);
        lpManager.setHysteresis(newHysteresis);
        assertEq(lpManager.hysteresis(), newHysteresis);
    }

    function testSetHysteresisRevertsIfExceedsPrecision() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_FeeMustBeLtePrecision()"));
        lpManager.setHysteresis(PRECISION);
    }

    function testSetAffiliate() public {
        vm.prank(owner);
        lpManager.setAffiliate(user1);
        assertEq(lpManager.affiliate(), user1);
    }

    function testSetApprovedRebalancer() public {
        vm.prank(owner);
        lpManager.setApprovedRebalancer(user1, true);
        assertTrue(lpManager.approvedRebalancer(user1));

        vm.prank(owner);
        lpManager.setApprovedRebalancer(user1, false);
        assertFalse(lpManager.approvedRebalancer(user1));
    }

    function testSetApprovedRebalancerRevertsForZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_ZeroAddress()"));
        lpManager.setApprovedRebalancer(ZERO_ADDRESS, true);
    }

    function testSetDepositMax() public {
        uint256 newMax0 = 500 * 10 ** 18;
        uint256 newMax1 = 600 * 10 ** 18;

        vm.prank(owner);
        lpManager.setDepositMax(newMax0, newMax1);

        assertEq(lpManager.deposit0Max(), newMax0);
        assertEq(lpManager.deposit1Max(), newMax1);
    }

    function testSetMaxTotalSupply() public {
        uint256 newMaxSupply = 1000000 * 10 ** 18;

        vm.prank(owner);
        lpManager.setMaxTotalSupply(newMaxSupply);

        assertEq(lpManager.maxTotalSupply(), newMaxSupply);
    }

    function testSetActionBlockDelay() public {
        uint256 newDelay = 10;

        vm.prank(owner);
        lpManager.setActionBlockDelay(newDelay);

        assertEq(lpManager.actionBlockDelay(), newDelay);
    }

    function testSetActionBlockDelayRevertsForZero() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_ZeroValue()"));
        lpManager.setActionBlockDelay(0);
    }

    // View Function Tests
    function testCurrentTick() public view {
        // Should return 0 based on mock setup
        assertEq(lpManager.currentTick(), 0);
    }

    function testGetCurrentSqrtPriceX96() public view {
        // Should return the mock sqrt price
        uint160 expectedPrice = 79228162514264337593543950336;
        assertEq(lpManager.getCurrentSqrtPriceX96(), expectedPrice);
    }

    function testFetchOracle() public view {
        // Both oracles return $1.00, so 1 token0 should equal 1 token1
        uint256 amountOut = lpManager.fetchOracle(address(token0), address(token1), 1 * 10 ** 18);
        assertEq(amountOut, 1 * 10 ** 18);
    }

    function testFetchOracleWithDifferentPrices() public {
        // Set token0 oracle to $2.00 and token1 oracle to $1.00
        usdOracle0.setPrice(200000000); // $2.00
        usdOracle1.setPrice(100000000); // $1.00

        // 1 token0 should equal 2 token1
        uint256 amountOut = lpManager.fetchOracle(address(token0), address(token1), 1 * 10 ** 18);
        assertEq(amountOut, 2 * 10 ** 18);

        // 2 token1 should equal 1 token0
        amountOut = lpManager.fetchOracle(address(token1), address(token0), 2 * 10 ** 18);
        assertEq(amountOut, 1 * 10 ** 18);
    }

    // Access Control Tests
    function testOnlyOwnerFunctions() public {
        // Test that non-owners cannot call owner functions
        vm.prank(user1);
        vm.expectRevert();
        lpManager.setFeeRecipient(user2);

        vm.prank(user1);
        vm.expectRevert();
        lpManager.setFee(PRECISION / 2);

        vm.prank(user1);
        vm.expectRevert();
        lpManager.setApprovedRebalancer(user2, true);
    }

    function testRebalancerOnlyFunctions() public {
        // Non-rebalancer should not be able to call rebalancer functions
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_NotAllowed()"));
        lpManager.autoRebalance(true, false);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_NotAllowed()"));
        lpManager.swapIdleAndAddToLiquidity(1000, 0, false);
    }

    // Deposit Tests (Basic)
    function testDepositRevertsWithZeroAmounts() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_ZeroValue()"));
        lpManager.deposit(0, 0, user1);
    }

    function testDepositRevertsWithZeroAddress() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_ZeroAddress()"));
        lpManager.deposit(100, 100, ZERO_ADDRESS);
    }

    function testDepositRevertsWhenTokenNotAllowed() public {
        // Disable token0
        vm.prank(owner);
        lpManager.setAlowedTokens(false, true);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3TokenizedLp_Token0NotAllowed()"));
        lpManager.deposit(100, 0, user1);
    }

    // Events Tests
    function testSetFeeRecipientEmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit FeeRecipient(user1);
        lpManager.setFeeRecipient(user1);
    }

    function testSetApprovedRebalancerEmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit ApprovedRebalancer(user1, true);
        lpManager.setApprovedRebalancer(user1, true);
    }

    // Events for testing
    event FeeRecipient(address newFeeRecipient);
    event ApprovedRebalancer(address rebalancer, bool isApproved);
}
