// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../oracle/PriceOracle.sol";
import "../libraries/LiquidationLogic.sol";

/**
 * @title LiquidationPool
 * @notice Main contract for managing liquidation pool and executing liquidations
 */
contract LiquidationPool is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using LiquidationLogic for LiquidationLogic.Position;

    // State variables
    PriceOracle public priceOracle;
    mapping(address => uint256) public deposits; // user => amount
    mapping(address => LiquidationLogic.Position) public positions;
    uint256 public totalDeposits;
    uint256 public liquidationThreshold = 150; // 150% collateralization ratio
    uint256 public constant LIQUIDATION_BONUS = 5; // 5% bonus for liquidators

    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event PositionOpened(address indexed user, uint256 collateralAmount, uint256 borrowAmount);
    event Liquidated(address indexed liquidator, address indexed user, uint256 collateralLiquidated, uint256 debtRepaid);

    constructor(address _priceOracle) {
        priceOracle = PriceOracle(_priceOracle);
    }

    /**
     * @notice Deposit tokens into the liquidation pool
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        IERC20(priceOracle.baseToken()).safeTransferFrom(msg.sender, address(this), amount);
        deposits[msg.sender] += amount;
        totalDeposits += amount;
        
        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Withdraw tokens from the liquidation pool
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        IERC20(priceOracle.baseToken()).safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Open a new position with collateral
     * @param collateralAmount Amount of collateral to deposit
     * @param borrowAmount Amount to borrow
     */
    function openPosition(uint256 collateralAmount, uint256 borrowAmount) external nonReentrant {
        require(collateralAmount > 0, "Collateral must be greater than 0");
        require(borrowAmount > 0, "Borrow amount must be greater than 0");
        require(totalDeposits >= borrowAmount, "Insufficient liquidity");

        // Transfer collateral
        IERC20(priceOracle.collateralToken()).safeTransferFrom(msg.sender, address(this), collateralAmount);

        // Create position
        positions[msg.sender] = LiquidationLogic.Position({
            collateralAmount: collateralAmount,
            borrowAmount: borrowAmount,
            timestamp: block.timestamp
        });

        // Transfer borrowed amount
        IERC20(priceOracle.baseToken()).safeTransfer(msg.sender, borrowAmount);
        totalDeposits -= borrowAmount;

        emit PositionOpened(msg.sender, collateralAmount, borrowAmount);
    }

    /**
     * @notice Liquidate an underwater position
     * @param user Address of the position to liquidate
     */
    function liquidate(address user) external nonReentrant {
        LiquidationLogic.Position storage position = positions[user];
        require(position.collateralAmount > 0, "Position does not exist");

        // Check if position is liquidatable
        uint256 collateralValue = priceOracle.getCollateralValue(position.collateralAmount);
        uint256 debtValue = priceOracle.getDebtValue(position.borrowAmount);
        
        require(collateralValue * 100 < debtValue * liquidationThreshold, "Position is not liquidatable");

        // Calculate liquidation amounts
        uint256 bonus = (position.collateralAmount * LIQUIDATION_BONUS) / 100;
        uint256 collateralToLiquidator = position.collateralAmount + bonus;
        
        // Transfer collateral to liquidator
        IERC20(priceOracle.collateralToken()).safeTransfer(msg.sender, collateralToLiquidator);
        
        // Repay debt
        IERC20(priceOracle.baseToken()).safeTransferFrom(msg.sender, address(this), position.borrowAmount);
        totalDeposits += position.borrowAmount;

        emit Liquidated(msg.sender, user, collateralToLiquidator, position.borrowAmount);

        // Clear position
        delete positions[user];
    }

    /**
     * @notice Update liquidation threshold
     * @param newThreshold New threshold value (150 = 150%)
     */
    function setLiquidationThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold > 100, "Invalid threshold");
        liquidationThreshold = newThreshold;
    }
}
