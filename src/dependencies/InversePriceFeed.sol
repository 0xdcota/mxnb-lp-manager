// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title InversePriceFeed
 * @author Xocolatl.eth
 * @notice Contract that takes a IPriceFeed-like price feed or
 * chainlink compatible feed and returns the inverse price.
 * @dev For example:
 * [eth/usd]-feed (dollars per one unit of eth) will be flipped to a
 * [usd/eth]-feed (eth per one unit of dollar).
 */
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";

contract InversePriceFeed is IPriceFeed {
    struct PriceFeedResponse {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    ///@dev custom errors
    error InversePriceFeed_invalidInput();
    error InversePriceFeed_fetchFeedAssetFailed();
    error InversePriceFeed_fetchFeedInterFailed();
    error InversePriceFeed_lessThanOrZeroAnswer();
    error InversePriceFeed_noRoundId();
    error InversePriceFeed_noValidUpdateAt();
    error InversePriceFeed_staleFeed();

    uint256 public constant version = 1;

    string private _description;
    uint8 private _decimals;
    uint8 private _feedAssetDecimals;

    IPriceFeed public feedAsset;
    uint256 public allowedTimeout;

    constructor(string memory description_, uint8 decimals_, address feedAsset_, uint256 allowedTimeout_) {
        _description = description_;
        _decimals = decimals_;

        if (feedAsset_ == address(0) || allowedTimeout_ == 0) {
            revert InversePriceFeed_invalidInput();
        }

        feedAsset = IPriceFeed(feedAsset_);
        _feedAssetDecimals = IPriceFeed(feedAsset_).decimals();
        allowedTimeout = allowedTimeout_;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function latestAnswer() external view returns (int256) {
        PriceFeedResponse memory feedLatestRound = _callandCheckFeed();
        return _computeInverseAnswer(feedLatestRound.answer);
    }

    function latestRound() external view returns (uint256) {
        PriceFeedResponse memory clComputed = _callandCheckFeed();
        return clComputed.roundId;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        PriceFeedResponse memory feedLatestRound = _callandCheckFeed();
        int256 invPrice = _computeInverseAnswer(feedLatestRound.answer);

        roundId = feedLatestRound.roundId;
        answer = invPrice;
        startedAt = feedLatestRound.startedAt;
        updatedAt = feedLatestRound.updatedAt;
        answeredInRound = feedLatestRound.roundId;
    }

    function _computeInverseAnswer(int256 assetAnswer) private view returns (int256) {
        uint256 inverse = 10 ** (uint256(2 * _decimals)) / uint256(assetAnswer);
        return int256(inverse);
    }

    function _callandCheckFeed() private view returns (PriceFeedResponse memory clFeed) {
        // Call the aggregator feed with try-catch method to identify failure
        try feedAsset.latestRoundData() returns (
            uint80 roundIdFeedAsset,
            int256 answerFeedAsset,
            uint256 startedAtFeedAsset,
            uint256 updatedAtFeedAsset,
            uint80 answeredInRoundFeedAsset
        ) {
            clFeed.roundId = roundIdFeedAsset;
            clFeed.answer = answerFeedAsset;
            clFeed.startedAt = startedAtFeedAsset;
            clFeed.updatedAt = updatedAtFeedAsset;
            clFeed.answeredInRound = answeredInRoundFeedAsset;
        } catch {
            revert InversePriceFeed_fetchFeedAssetFailed();
        }

        // Perform checks to the returned response
        if (clFeed.answer <= 0) {
            revert InversePriceFeed_lessThanOrZeroAnswer();
        } else if (clFeed.roundId == 0) {
            revert InversePriceFeed_noRoundId();
        } else if (clFeed.updatedAt > block.timestamp || clFeed.updatedAt == 0) {
            revert InversePriceFeed_noValidUpdateAt();
        } else if (block.timestamp - clFeed.updatedAt > allowedTimeout) {
            revert InversePriceFeed_staleFeed();
        }
    }
}
