// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IPyth {
    struct Price {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint256 publishTime;
    }

    function getPriceUnsafe(bytes32 id) external view returns (Price memory price);
    function priceFeedExists(bytes32 id) external view returns (bool);
}
