const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Deploy Mock Tokens
  const MockToken = await ethers.getContractFactory("MockToken");
  const collateralToken = await MockToken.deploy("Mock WETH", "WETH", 18);
  await collateralToken.deployed();
  console.log("Collateral Token deployed to:", collateralToken.address);

  const baseToken = await MockToken.deploy("Mock USDC", "USDC", 6);
  await baseToken.deployed();
  console.log("Base Token deployed to:", baseToken.address);

  // Deploy Mock Price Feeds
  const MockPriceFeed = await ethers.getContractFactory("MockPriceFeed");
  const collateralPriceFeed = await MockPriceFeed.deploy(8, "ETH/USD");
  await collateralPriceFeed.deployed();
  console.log("Collateral Price Feed deployed to:", collateralPriceFeed.address);

  const basePriceFeed = await MockPriceFeed.deploy(8, "USDC/USD");
  await basePriceFeed.deployed();
  console.log("Base Price Feed deployed to:", basePriceFeed.address);

  // Deploy Price Oracle
  const PriceOracle = await ethers.getContractFactory("PriceOracle");
  const priceOracle = await PriceOracle.deploy(
    collateralPriceFeed.address,
    basePriceFeed.address,
    collateralToken.address,
    baseToken.address
  );
  await priceOracle.deployed();
  console.log("Price Oracle deployed to:", priceOracle.address);

  // Deploy Liquidation Pool
  const LiquidationPool = await ethers.getContractFactory("LiquidationPool");
  const liquidationPool = await LiquidationPool.deploy(priceOracle.address);
  await liquidationPool.deployed();
  console.log("Liquidation Pool deployed to:", liquidationPool.address);

  // Set initial prices
  await collateralPriceFeed.setPrice(ethers.utils.parseUnits("2000", 8)); // ETH = $2000
  await basePriceFeed.setPrice(ethers.utils.parseUnits("1", 8)); // USDC = $1

  // Mint some tokens to deployer for testing
  await collateralToken.mint(
    deployer.address,
    ethers.utils.parseEther("1000") // 1000 WETH
  );
  await baseToken.mint(
    deployer.address,
    ethers.utils.parseUnits("2000000", 6) // 2M USDC
  );

  console.log("\nDeployment completed!");
  console.log("\nContract Addresses:");
  console.log("-------------------");
  console.log("Collateral Token (WETH):", collateralToken.address);
  console.log("Base Token (USDC):", baseToken.address);
  console.log("Collateral Price Feed:", collateralPriceFeed.address);
  console.log("Base Price Feed:", basePriceFeed.address);
  console.log("Price Oracle:", priceOracle.address);
  console.log("Liquidation Pool:", liquidationPool.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
