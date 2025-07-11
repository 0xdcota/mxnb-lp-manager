// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title ComputedPriceFeedWithSequencer
 * @author Xocolatl.eth
 * @notice Same as ComputedPriceFeed with SequencerChecks.
 * Use this in ethereum L2s.
 * @dev For example: [wsteth/eth]-feed and [eth/usd]-feed to return a [wsteth/usd]-feed.
 * Note: Ensure units work, this contract multiplies the feeds.
 */
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {SequencerFeedChecker} from "./SequencerFeedChecker.sol";

contract ComputedPriceFeedWithSequencer is IPriceFeed, SequencerFeedChecker {
    struct PriceFeedResponse {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    ///@dev custom errors
    error ComputedPriceFeed_invalidInput();
    error ComputedPriceFeed_fetchFeedAssetFailed();
    error ComputedPriceFeed_fetchFeedInterFailed();
    error ComputedPriceFeed_lessThanOrZeroAnswer();
    error ComputedPriceFeed_noRoundId();
    error ComputedPriceFeed_noValidUpdateAt();
    error ComputedPriceFeed_staleFeed();

    uint256 public constant version = 1;

    string private _description;
    uint8 private _decimals;
    uint8 private _feedAssetDecimals;
    uint8 private _feedInterAssetDecimals;

    IPriceFeed public feedAsset;
    IPriceFeed public feedInterAsset;
    uint256 public allowedTimeout;

    constructor(
        string memory description_,
        uint8 decimals_,
        address feedAsset_,
        address feedInterAsset_,
        uint256 allowedTimeout_,
        address sequencerFeed
    ) {
        _description = description_;
        _decimals = decimals_;

        if (
            feedAsset_ == address(0) || feedInterAsset_ == address(0) || allowedTimeout_ == 0
                || sequencerFeed == address(0)
        ) {
            revert ComputedPriceFeed_invalidInput();
        }
        __SequencerFeed_init(sequencerFeed);

        feedAsset = IPriceFeed(feedAsset_);
        feedInterAsset = IPriceFeed(feedInterAsset_);

        _feedAssetDecimals = IPriceFeed(feedAsset_).decimals();
        _feedInterAssetDecimals = IPriceFeed(feedInterAsset_).decimals();

        allowedTimeout = allowedTimeout_;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function latestAnswer() external view returns (int256) {
        PriceFeedResponse memory clComputed = _computeLatestRoundData();
        return clComputed.answer;
    }

    function latestRound() external view returns (uint256) {
        PriceFeedResponse memory clComputed = _computeLatestRoundData();
        return clComputed.roundId;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        PriceFeedResponse memory clComputed = _computeLatestRoundData();
        roundId = clComputed.roundId;
        answer = clComputed.answer;
        startedAt = clComputed.startedAt;
        updatedAt = clComputed.updatedAt;
        answeredInRound = roundId;
    }

    function _computeLatestRoundData() private view returns (PriceFeedResponse memory clComputed) {
        (PriceFeedResponse memory clFeed, PriceFeedResponse memory clInter) = _callandCheckFeeds();

        clComputed.answer = _computeAnswer(clFeed.answer, clInter.answer);
        clComputed.roundId = clFeed.roundId > clInter.roundId ? clFeed.roundId : clInter.roundId;
        clComputed.startedAt = clFeed.startedAt < clInter.startedAt ? clFeed.startedAt : clInter.startedAt;
        clComputed.updatedAt = clFeed.updatedAt > clInter.updatedAt ? clFeed.updatedAt : clInter.updatedAt;
        clComputed.answeredInRound = clComputed.roundId;
    }

    function _computeAnswer(int256 assetAnswer, int256 interAssetAnswer) private view returns (int256) {
        uint256 price = (uint256(assetAnswer) * uint256(interAssetAnswer) * 10 ** (uint256(_decimals)))
            / 10 ** (uint256(_feedAssetDecimals + _feedInterAssetDecimals));
        return int256(price);
    }

    function _callandCheckFeeds()
        private
        view
        returns (PriceFeedResponse memory clFeed, PriceFeedResponse memory clInter)
    {
        checkSequencerFeed();
        // Call the aggregator feeds with try-catch method to identify failure
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
            revert ComputedPriceFeed_fetchFeedAssetFailed();
        }

        try feedInterAsset.latestRoundData() returns (
            uint80 roundIdFeedInterAsset,
            int256 answerFeedInterAsset,
            uint256 startedAtFeedInterAsset,
            uint256 updatedAtInterFeedInterAsset,
            uint80 answeredInRoundFeedInterAsset
        ) {
            clInter.roundId = roundIdFeedInterAsset;
            clInter.answer = answerFeedInterAsset;
            clInter.startedAt = startedAtFeedInterAsset;
            clInter.updatedAt = updatedAtInterFeedInterAsset;
            clInter.answeredInRound = answeredInRoundFeedInterAsset;
        } catch {
            revert ComputedPriceFeed_fetchFeedInterFailed();
        }

        // Perform checks to the returned responses
        if (clFeed.answer <= 0 || clInter.answer <= 0) {
            revert ComputedPriceFeed_lessThanOrZeroAnswer();
        } else if (clFeed.roundId == 0 || clInter.roundId == 0) {
            revert ComputedPriceFeed_noRoundId();
        } else if (
            clFeed.updatedAt > block.timestamp || clFeed.updatedAt == 0 || clInter.updatedAt > block.timestamp
                || clInter.updatedAt == 0
        ) {
            revert ComputedPriceFeed_noValidUpdateAt();
        } else if (
            block.timestamp - clFeed.updatedAt > allowedTimeout || block.timestamp - clInter.updatedAt > allowedTimeout
        ) {
            revert ComputedPriceFeed_staleFeed();
        }
    }
}
