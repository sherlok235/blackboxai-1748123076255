const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LiquidationPool", function () {
  let liquidationPool;
  let priceOracle;
  let collateralToken;
  let baseToken;
  let collateralPriceFeed;
  let basePriceFeed;
  let owner;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy Mock Tokens
    const MockToken = await ethers.getContractFactory("MockToken");
    collateralToken = await MockToken.deploy("Mock WETH", "WETH", 18);
    baseToken = await MockToken.deploy("Mock USDC", "USDC", 6);

    // Deploy Mock Price Feeds
    const MockPriceFeed = await ethers.getContractFactory("MockPriceFeed");
    collateralPriceFeed = await MockPriceFeed.deploy(8, "ETH/USD");
    basePriceFeed = await MockPriceFeed.deploy(8, "USDC/USD");

    // Set initial prices
    await collateralPriceFeed.setPrice(ethers.utils.parseUnits("2000", 8)); // ETH = $2000
    await basePriceFeed.setPrice(ethers.utils.parseUnits("1", 8)); // USDC = $1

    // Deploy Price Oracle
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    priceOracle = await PriceOracle.deploy(
      collateralPriceFeed.address,
      basePriceFeed.address,
      collateralToken.address,
      baseToken.address
    );

    // Deploy Liquidation Pool
    const LiquidationPool = await ethers.getContractFactory("LiquidationPool");
    liquidationPool = await LiquidationPool.deploy(priceOracle.address);

    // Mint tokens to users
    await collateralToken.mint(user1.address, ethers.utils.parseEther("10")); // 10 WETH
    await baseToken.mint(user2.address, ethers.utils.parseUnits("30000", 6)); // 30,000 USDC

    // Approve tokens
    await collateralToken.connect(user1).approve(liquidationPool.address, ethers.constants.MaxUint256);
    await baseToken.connect(user2).approve(liquidationPool.address, ethers.constants.MaxUint256);
  });

  describe("Basic Operations", function () {
    it("Should allow deposits and withdrawals", async function () {
      const depositAmount = ethers.utils.parseUnits("10000", 6); // 10,000 USDC
      await baseToken.mint(user1.address, depositAmount);
      await baseToken.connect(user1).approve(liquidationPool.address, depositAmount);
      
      await liquidationPool.connect(user1).deposit(depositAmount);
      expect(await liquidationPool.deposits(user1.address)).to.equal(depositAmount);
      
      await liquidationPool.connect(user1).withdraw(depositAmount);
      expect(await liquidationPool.deposits(user1.address)).to.equal(0);
    });

    it("Should allow opening positions", async function () {
      // First deposit some base tokens to the pool
      const depositAmount = ethers.utils.parseUnits("20000", 6); // 20,000 USDC
      await baseToken.connect(user2).deposit(depositAmount);

      // User1 opens a position with 1 ETH collateral
      const collateralAmount = ethers.utils.parseEther("1"); // 1 WETH
      const borrowAmount = ethers.utils.parseUnits("1000", 6); // 1,000 USDC

      await liquidationPool.connect(user1).openPosition(collateralAmount, borrowAmount);
      
      const position = await liquidationPool.positions(user1.address);
      expect(position.collateralAmount).to.equal(collateralAmount);
      expect(position.borrowAmount).to.equal(borrowAmount);
    });

    it("Should allow liquidation of underwater positions", async function () {
      // Setup: Create a position and make it liquidatable
      const depositAmount = ethers.utils.parseUnits("20000", 6);
      await baseToken.connect(user2).deposit(depositAmount);

      const collateralAmount = ethers.utils.parseEther("1");
      const borrowAmount = ethers.utils.parseUnits("1000", 6);

      await liquidationPool.connect(user1).openPosition(collateralAmount, borrowAmount);

      // Drop ETH price to make position liquidatable
      await collateralPriceFeed.setPrice(ethers.utils.parseUnits("1000", 8)); // ETH = $1000

      // User2 liquidates the position
      await baseToken.connect(user2).approve(liquidationPool.address, borrowAmount);
      await liquidationPool.connect(user2).liquidate(user1.address);

      // Verify position is liquidated
      const position = await liquidationPool.positions(user1.address);
      expect(position.collateralAmount).to.equal(0);
      expect(position.borrowAmount).to.equal(0);
    });
  });

  describe("Price Oracle Integration", function () {
    it("Should correctly fetch and use price data", async function () {
      const ethPrice = await priceOracle.getCollateralPrice();
      const usdcPrice = await priceOracle.getBasePrice();
      
      expect(ethPrice).to.equal(ethers.utils.parseUnits("2000", 8));
      expect(usdcPrice).to.equal(ethers.utils.parseUnits("1", 8));
    });
  });

  describe("Edge Cases", function () {
    it("Should prevent withdrawing more than deposited", async function () {
      const depositAmount = ethers.utils.parseUnits("1000", 6);
      await baseToken.mint(user1.address, depositAmount);
      await baseToken.connect(user1).approve(liquidationPool.address, depositAmount);
      
      await liquidationPool.connect(user1).deposit(depositAmount);
      
      const largerAmount = depositAmount.mul(2);
      await expect(
        liquidationPool.connect(user1).withdraw(largerAmount)
      ).to.be.revertedWith("Insufficient balance");
    });

    it("Should prevent opening position with insufficient collateral", async function () {
      const depositAmount = ethers.utils.parseUnits("20000", 6);
      await baseToken.connect(user2).deposit(depositAmount);

      const smallCollateral = ethers.utils.parseEther("0.1");
      const largeBorrow = ethers.utils.parseUnits("1000", 6);

      // Try to open position with too little collateral
      await expect(
        liquidationPool.connect(user1).openPosition(smallCollateral, largeBorrow)
      ).to.be.revertedWith("Position is not liquidatable");
    });
  });
});
