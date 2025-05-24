// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockPriceFeed
 * @notice Mock implementation of Chainlink's AggregatorV3Interface for testing
 */
contract MockPriceFeed is AggregatorV3Interface, Ownable {
    uint8 private _decimals;
    string private _description;
    uint256 private _version;
    int256 private _price;
    uint80 private _roundId;
    uint256 private _timestamp;

    constructor(
        uint8 decimalsValue,
        string memory description
    ) {
        _decimals = decimalsValue;
        _description = description;
        _version = 1;
        _price = 1000 * 10**decimalsValue; // Default price of 1000 USD
        _roundId = 1;
        _timestamp = block.timestamp;
    }

    /**
     * @notice Set the latest price
     * @param price New price
     */
    function setPrice(int256 price) external onlyOwner {
        require(price > 0, "Price must be positive");
        _price = price;
        _roundId++;
        _timestamp = block.timestamp;
    }

    // AggregatorV3Interface functions

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external view override returns (string memory) {
        return _description;
    }

    function version() external view override returns (uint256) {
        return _version;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        require(_roundId > 0, "Invalid round ID");
        return (_roundId, _price, _timestamp, _timestamp, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _price, _timestamp, _timestamp, _roundId);
    }
}
