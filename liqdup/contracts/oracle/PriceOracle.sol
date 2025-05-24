// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PriceOracle
 * @notice Contract for getting price data from Chainlink oracles
 */
contract PriceOracle is Ownable {
    AggregatorV3Interface public collateralPriceFeed;
    AggregatorV3Interface public basePriceFeed;
    
    address public collateralToken;
    address public baseToken;

    uint8 private constant PRICE_DECIMALS = 8;

    constructor(
        address _collateralPriceFeed,
        address _basePriceFeed,
        address _collateralToken,
        address _baseToken
    ) {
        collateralPriceFeed = AggregatorV3Interface(_collateralPriceFeed);
        basePriceFeed = AggregatorV3Interface(_basePriceFeed);
        collateralToken = _collateralToken;
        baseToken = _baseToken;
    }

    /**
     * @notice Get the latest collateral price
     * @return Latest price
     */
    function getCollateralPrice() public view returns (uint256) {
        (, int256 price,,,) = collateralPriceFeed.latestRoundData();
        require(price > 0, "Invalid collateral price");
        return uint256(price);
    }

    /**
     * @notice Get the latest base token price
     * @return Latest price
     */
    function getBasePrice() public view returns (uint256) {
        (, int256 price,,,) = basePriceFeed.latestRoundData();
        require(price > 0, "Invalid base price");
        return uint256(price);
    }

    /**
     * @notice Get the USD value of collateral amount
     * @param amount Amount of collateral
     * @return USD value
     */
    function getCollateralValue(uint256 amount) external view returns (uint256) {
        return (amount * getCollateralPrice()) / (10 ** PRICE_DECIMALS);
    }

    /**
     * @notice Get the USD value of debt amount
     * @param amount Amount of debt
     * @return USD value
     */
    function getDebtValue(uint256 amount) external view returns (uint256) {
        return (amount * getBasePrice()) / (10 ** PRICE_DECIMALS);
    }

    /**
     * @notice Update price feed addresses
     */
    function updatePriceFeeds(
        address _collateralPriceFeed,
        address _basePriceFeed
    ) external onlyOwner {
        require(_collateralPriceFeed != address(0), "Invalid collateral price feed");
        require(_basePriceFeed != address(0), "Invalid base price feed");
        
        collateralPriceFeed = AggregatorV3Interface(_collateralPriceFeed);
        basePriceFeed = AggregatorV3Interface(_basePriceFeed);
    }

    /**
     * @notice Update token addresses
     */
    function updateTokens(
        address _collateralToken,
        address _baseToken
    ) external onlyOwner {
        require(_collateralToken != address(0), "Invalid collateral token");
        require(_baseToken != address(0), "Invalid base token");
        
        collateralToken = _collateralToken;
        baseToken = _baseToken;
    }
}
