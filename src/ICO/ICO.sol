// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AquatimusICO is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable AQUAT;
    IERC20 public immutable USDT;

    // Price: number of USDT units per AQUAT × divisor
    uint256 public price = 24;
    uint256 public divisor = 10_000;

    bool public isEnded;
    uint256 public totalSoldTokens;
    uint256 public totalUsdtRaised;

    event TokensPurchased(address indexed buyer, address indexed receiver, uint256 usdtAmount, uint256 aquatAmount);
    event ICOEnded(uint256 unsoldTokens);
    event PriceUpdated(uint256 newPrice, uint256 newDivisor);

    constructor(address initialOwner, address aquat, address usdt) Ownable(initialOwner) {
        require(aquat != address(0) && usdt != address(0), "Zero address");
        AQUAT = IERC20(aquat);
        USDT = IERC20(usdt);
    }

    /// @notice Buy AQUAT tokens by spending USDT
    /// @param receiver Address to receive AQUAT tokens
    /// @param amount Amount of USDT to spend (in USDT’s smallest unit)
    function buy(address receiver, uint256 amount) external {
        require(!isEnded, "ICO ended");
        require(amount > 0, "Zero amount");

        uint256 usdAmount = (amount * price) / divisor;
        require(usdAmount > 0, "Amount too small");

        // Pull USDT from buyer to this contract
        USDT.safeTransferFrom(msg.sender, owner(), usdAmount);

        // Send AQUAT from contract balance to receiver
        AQUAT.safeTransfer(receiver, amount);

        totalUsdtRaised += usdAmount;
        totalSoldTokens += amount;

        emit TokensPurchased(msg.sender, receiver, usdAmount, amount);
    }

    /// @notice Owner can end the ICO and withdraw remaining AQUAT
    function endICO() external onlyOwner {
        require(!isEnded, "Already ended");
        uint256 unsold = AQUAT.balanceOf(address(this));
        if (unsold > 0) {
            AQUAT.safeTransfer(owner(), unsold);
        }
        isEnded = true;
        emit ICOEnded(unsold);
    }

    /// @notice Adjust price/divisor (e.g. in case of market changes)
    function setPrice(uint256 newPrice, uint256 newDivisor) external onlyOwner {
        require(newPrice > 0 && newDivisor > 0, "Invalid");
        price = newPrice;
        divisor = newDivisor;
        emit PriceUpdated(newPrice, newDivisor);
    }

    /// @notice Check how many AQUAT tokens remain in the contract
    function remainingTokens() external view returns (uint256) {
        return AQUAT.balanceOf(address(this));
    }
}
