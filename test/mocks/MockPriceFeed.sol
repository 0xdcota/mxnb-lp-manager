// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IPriceFeed} from "../../src/interfaces/IPriceFeed.sol";

contract MockPriceFeed is IPriceFeed {
    int256 private _price;
    uint8 private _decimals;
    string private _description;

    constructor(int256 price, uint8 decimals_, string memory description_) {
        _price = price;
        _decimals = decimals_;
        _description = description_;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external view override returns (string memory) {
        return _description;
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function latestAnswer() external view override returns (int256) {
        return _price;
    }

    function latestRound() external pure override returns (uint256) {
        return 1;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, _price, block.timestamp, block.timestamp, 1);
    }

    function setPrice(int256 newPrice) external {
        _price = newPrice;
    }
}
