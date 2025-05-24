// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title LiquidationLogic
 * @notice Library containing core liquidation calculations and position management logic
 */
library LiquidationLogic {
    // Struct to store position details
    struct Position {
        uint256 collateralAmount;
        uint256 borrowAmount;
        uint256 timestamp;
    }

    /**
     * @notice Calculate the health factor of a position
     * @param collateralValue USD value of collateral
     * @param debtValue USD value of debt
     * @return Health factor scaled by 1e18
     */
    function calculateHealthFactor(
        uint256 collateralValue,
        uint256 debtValue
    ) internal pure returns (uint256) {
        if (debtValue == 0) return type(uint256).max;
        return (collateralValue * 1e18) / debtValue;
    }

    /**
     * @notice Calculate liquidation amount
     * @param collateralAmount Total collateral amount
     * @param debtAmount Total debt amount
     * @param maxLiquidationRatio Maximum ratio that can be liquidated (e.g., 50 for 50%)
     * @return Amount of collateral to liquidate
     * @return Amount of debt to repay
     */
    function calculateLiquidationAmount(
        uint256 collateralAmount,
        uint256 debtAmount,
        uint256 maxLiquidationRatio
    ) internal pure returns (uint256, uint256) {
        require(maxLiquidationRatio <= 100, "Invalid liquidation ratio");
        
        uint256 maxCollateralToLiquidate = (collateralAmount * maxLiquidationRatio) / 100;
        uint256 maxDebtToRepay = (debtAmount * maxLiquidationRatio) / 100;
        
        return (maxCollateralToLiquidate, maxDebtToRepay);
    }

    /**
     * @notice Calculate liquidation bonus
     * @param collateralAmount Amount of collateral being liquidated
     * @param bonusPercentage Bonus percentage (e.g., 5 for 5%)
     * @return Bonus amount of collateral
     */
    function calculateLiquidationBonus(
        uint256 collateralAmount,
        uint256 bonusPercentage
    ) internal pure returns (uint256) {
        require(bonusPercentage <= 100, "Invalid bonus percentage");
        return (collateralAmount * bonusPercentage) / 100;
    }

    /**
     * @notice Check if a position can be liquidated
     * @param healthFactor Current health factor
     * @param liquidationThreshold Threshold below which liquidation is allowed
     * @return True if position can be liquidated
     */
    function canBeLiquidated(
        uint256 healthFactor,
        uint256 liquidationThreshold
    ) internal pure returns (bool) {
        return healthFactor < liquidationThreshold;
    }

    /**
     * @notice Calculate interest for a position
     * @param principal Principal amount
     * @param rate Annual interest rate (scaled by 1e18)
     * @param timeElapsed Time elapsed in seconds
     * @return Interest amount
     */
    function calculateInterest(
        uint256 principal,
        uint256 rate,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        return (principal * rate * timeElapsed) / (365 days * 1e18);
    }
}
