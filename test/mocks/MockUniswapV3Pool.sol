// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract MockUniswapV3Pool {
    address public token0;
    address public token1;
    int24 public tickSpacing;
    uint160 private _sqrtPriceX96;
    int24 private _tick;
    bool private _unlocked = true;

    struct Position {
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    mapping(bytes32 => Position) public positions;

    constructor(address _token0, address _token1, int24 _tickSpacing) {
        token0 = _token0;
        token1 = _token1;
        tickSpacing = _tickSpacing;
        _sqrtPriceX96 = 79228162514264337593543950336; // approximately 1:1 price
        _tick = 0;
    }

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        return (_sqrtPriceX96, _tick, 0, 1, 1, 0, _unlocked);
    }

    function increaseObservationCardinalityNext(uint16) external {}

    function mint(address, int24, int24, uint128, bytes calldata) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function burn(int24, int24, uint128) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function collect(address, int24, int24, uint128, uint128) external pure returns (uint128, uint128) {
        return (0, 0);
    }

    function swap(address, bool, int256, uint160, bytes calldata) external pure returns (int256, int256) {
        return (0, 0);
    }

    function observations(uint256) external view returns (uint32 blockTimestamp, int56, uint160, bool) {
        return (uint32(block.timestamp - 1), 0, 0, true);
    }

    function observe(uint32[] calldata) external pure returns (int56[] memory, uint160[] memory) {
        int56[] memory tickCumulatives = new int56[](1);
        uint160[] memory secondsPerLiquidityCumulativeX128s = new uint160[](1);
        return (tickCumulatives, secondsPerLiquidityCumulativeX128s);
    }

    // Implement other required functions with minimal logic for testing
    function liquidity() external pure returns (uint128) {
        return 0;
    }

    function fee() external pure returns (uint24) {
        return 3000;
    }

    function feeGrowthGlobal0X128() external pure returns (uint256) {
        return 0;
    }

    function feeGrowthGlobal1X128() external pure returns (uint256) {
        return 0;
    }

    function protocolFees() external pure returns (uint128, uint128) {
        return (0, 0);
    }

    function ticks(int24) external pure returns (uint128, int128, uint256, uint256, int56, uint160, uint32, bool) {
        return (0, 0, 0, 0, 0, 0, 0, false);
    }

    function tickBitmap(int16) external pure returns (uint256) {
        return 0;
    }

    function snapshotCumulativesInside(int24, int24) external pure returns (int56, uint160, uint32) {
        return (0, 0, 0);
    }

    function flash(address, uint256, uint256, bytes calldata) external {}

    function collectProtocol(address, uint128, uint128) external pure returns (uint128, uint128) {
        return (0, 0);
    }

    function setFeeProtocol(uint8, uint8) external {}

    function initialize(uint160) external {}
}
