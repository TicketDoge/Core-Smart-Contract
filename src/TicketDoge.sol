// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

/// @title TicketDoge Lottery Contract
/// @notice Manages ticket minting, referral rewards, and draw mechanics
contract TicketDoge is ERC721URIStorage, Ownable {
    /// @notice Possible states of the lottery
    enum LotteryState {
        Open,
        Drawing,
        Paused
    }

    /// @notice Represents a lottery ticket with referral tracking
    struct Ticket {
        string uri; // Metadata URI
        uint256 id; // NFT token ID
        uint256 drawId; // Associated draw round
        address payable holder; // Ticket owner
        uint256 price; // Paid price in USDT
        string referralCode; // Referral code for this ticket
        uint256 timesUsed; // Number of times this referral was used
        uint256 earnings; // Total referral earnings
        uint256 referrerId; // Upline ticket ID (0 if none)
        uint256 xiom; // Loyalty points
    }

    /// @notice Error wrapper
    error TDError(string reason);

    IERC20 public immutable usdtToken;
    IERC20 public immutable dogeToken;
    address internal immutable priceFeed;

    LotteryState public currentState = LotteryState.Open;

    uint256 public minEntry;
    uint256 public maxEntry;

    uint256 private nextTokenId;

    // Fee wallets (immutable)
    address public immutable teamWallet;
    address public immutable futureProjWallet;
    address public immutable charityWallet;

    //Doge Wallet
    address private immutable dogeWallet;

    // Fee percentages (basis points)
    uint256 public constant TEAM_FEE_BPS = 21;
    uint256 public constant FUTURE_FEE_BPS = 21;
    uint256 public constant CHARITY_FEE_BPS = 8;

    // Draw pool and configuration
    uint256 public drawPool;
    uint256 public drawCount = 1;
    uint256 public immutable TARGET_POOL; // 250 USDT(for Test) @

    // Referral & prize settings
    uint256 public constant REFERRER_REWARD_BPS = 10;
    uint256 public constant REFERRAL_REWARD_BPS = 21;
    uint256 public constant BPS_DIVIDER = 100;
    uint256 public constant PRIZE_MULTIPLIER = 3333; // Out of 1000

    // Tracking entries
    uint256[] private recentEntries;
    uint256[] private allEntries;

    // Latest winners
    address[] private lastNewWinners;
    address[] private lastOldWinners;
    uint256[] private lastNewPrizes;
    uint256[] private lastOldPrizes;

    // Mappings
    mapping(uint256 => Ticket) public tickets;
    mapping(string => bool) public referralExists;
    mapping(string => uint256) public referralToTicket;
    mapping(string => address) public referralToOwner;
    mapping(uint256 => string) public ticketToReferral;
    mapping(uint256 => address) public ticketToOwner;

    /// @param initialOwner Owner of the contract
    /// @param _usdt         Address of USDT token
    /// @param _minEntry     Minimum ticket price
    /// @param _teamWallet   Team fee receiver
    /// @param _futureWallet Future project fee receiver
    /// @param _charityWallet Charity fee receiver
    constructor(
        address initialOwner,
        address _usdt,
        address _doge,
        uint256 _minEntry,
        address _teamWallet,
        address _futureWallet,
        address _charityWallet,
        address _dogeWallet,
        address _priceFeed
    ) ERC721("Ticket Doge", "TDN") Ownable(initialOwner) {
        usdtToken = IERC20(_usdt);
        dogeToken = IERC20(_doge);
        minEntry = _minEntry;
        maxEntry = (125_000 * 10 ** IERC20Metadata(_usdt).decimals()) / PRIZE_MULTIPLIER;
        TARGET_POOL = 250 * 10 ** IERC20Metadata(_usdt).decimals(); // @
        teamWallet = _teamWallet;
        futureProjWallet = _futureWallet;
        charityWallet = _charityWallet;
        dogeWallet = _dogeWallet;
        priceFeed = _priceFeed;
    }

    /// @notice Mints a new lottery ticket
    /// @param ticketPrice Price in USDT to mint
    /// @param recipient   Ticket receiver
    /// @param useReferral Whether a referral code is used
    /// @param refCode     Referral code (if any)
    /// @param uri         Metadata URI
    function mintTicket(
        uint256 ticketPrice,
        address recipient,
        bool useReferral,
        string memory refCode,
        string memory uri
    ) external {
        _ensureState(LotteryState.Open, "Draw not open");
        _ensure(ticketPrice >= minEntry, "Below minimum entry");
        _ensure(ticketPrice <= maxEntry, "Above maximum entry");

        // Generate unique referral code for this ticket
        string memory newCode = _generateUniqueReferral(recipient);

        address upline;
        uint256 uplineId;
        if (useReferral) {
            _ensure(referralExists[refCode], "Invalid referral code");
            _ensure(referralToOwner[refCode] != recipient, "Can not Use Your Own Referral");
            upline = referralToOwner[refCode];
            uplineId = referralToTicket[refCode];
            // Discount for referred user
            ticketPrice = (ticketPrice * (BPS_DIVIDER - REFERRER_REWARD_BPS)) / BPS_DIVIDER;
        }

        // Transfer USDT and mint NFT
        _ensure(usdtToken.transferFrom(msg.sender, address(this), ticketPrice), "USDT transfer failed");
        nextTokenId++;
        _safeMint(recipient, nextTokenId);
        _setTokenURI(nextTokenId, uri);

        // Record ticket data
        uint256 xiomPts = _randomXiom(recipient);
        tickets[nextTokenId] = Ticket(
            uri,
            nextTokenId,
            drawCount,
            payable(recipient),
            ticketPrice,
            newCode,
            0,
            0,
            useReferral ? uplineId : 0,
            xiomPts
        );

        // Register referral mappings
        referralExists[newCode] = true;
        referralToTicket[newCode] = nextTokenId;
        ticketToReferral[nextTokenId] = newCode;
        referralToOwner[newCode] = recipient;
        ticketToOwner[nextTokenId] = recipient;

        recentEntries.push(nextTokenId);
        allEntries.push(nextTokenId);

        // Distribute funds (fees, referrals, pool)
        _distributeFunds(ticketPrice, useReferral, upline, uplineId);
    }

    /// @dev Distributes USDT to referrer, fees, and draw pool
    function _distributeFunds(uint256 amount, bool useReferral, address upline, uint256 uplineId) internal {
        if (useReferral) {
            uint256 reward = (amount * REFERRAL_REWARD_BPS) / BPS_DIVIDER;
            tickets[uplineId].earnings += reward;
            tickets[uplineId].timesUsed++;
            tickets[uplineId].xiom += 1500;
            uint256 ancestor = tickets[uplineId].referrerId;
            while (ancestor != 0) {
                tickets[ancestor].xiom += 1500;
                ancestor = tickets[ancestor].referrerId;
            }

            uint256 rewardInDoge = _toDoge(reward);
            usdtToken.transfer(dogeWallet, reward);
            dogeToken.transferFrom(dogeWallet, upline, rewardInDoge);
            amount -= reward;
        }
        // Team fee
        uint256 teamAmt = (amount * TEAM_FEE_BPS) / BPS_DIVIDER;
        uint256 futureAmt = (amount * FUTURE_FEE_BPS) / BPS_DIVIDER;
        uint256 charityAmt = (amount * CHARITY_FEE_BPS) / BPS_DIVIDER;
        usdtToken.transfer(teamWallet, teamAmt);
        usdtToken.transfer(futureProjWallet, futureAmt);
        usdtToken.transfer(charityWallet, charityAmt);

        // Add remainder to pool and check draw trigger
        drawPool += (amount * (BPS_DIVIDER - TEAM_FEE_BPS - FUTURE_FEE_BPS - CHARITY_FEE_BPS)) / BPS_DIVIDER;
        if (drawPool >= TARGET_POOL) {
            currentState = LotteryState.Drawing;
        }
    }

    /// @notice Selects winners when pool target is reached
    function pickWinners() external {
        _ensureState(LotteryState.Drawing, "Pool target not met");

        uint256 newIdx = _randomIndex(recentEntries.length, 0);
        uint256 oldIdx = _randomIndex(allEntries.length, 1);

        uint256 newTicketId = recentEntries[newIdx];
        uint256 oldTicketId = allEntries[oldIdx];
        address newWinner = ticketToOwner[newTicketId];
        address oldWinner = ticketToOwner[oldTicketId];

        uint256 prizeNew = (tickets[newTicketId].price * PRIZE_MULTIPLIER) / 1000;
        uint256 prizeOld = (tickets[oldTicketId].price * PRIZE_MULTIPLIER) / 1000;

        usdtToken.transfer(newWinner, prizeNew);
        usdtToken.transfer(oldWinner, prizeOld);

        lastNewWinners.push(newWinner);
        lastOldWinners.push(oldWinner);
        lastNewPrizes.push(prizeNew);
        lastOldPrizes.push(prizeOld);

        _boostXioms();
        delete recentEntries;
        drawPool -= (prizeNew + prizeOld);
        drawCount++;
        currentState = LotteryState.Open;
    }

    /// @notice Override to keep referral ownership when transferring tickets
    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) {
        string memory code = tickets[tokenId].referralCode;
        referralToOwner[code] = to;
        tickets[tokenId].holder = payable(to);
        super.transferFrom(from, to, tokenId);
    }

    /// @dev Generates a pseudo-random index
    function _randomIndex(uint256 length, uint256 salt) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1), salt))) % length;
    }

    /// @dev Creates a unique 8-char referral code
    function _generateUniqueReferral(address user) internal view returns (string memory) {
        string memory code;
        for (uint256 i = 0; i < 10; i++) {
            code = _randomReferral(user, i);
            if (!referralExists[code]) break;
        }
        return code;
    }

    /// @dev Pseudo-random referral code generator (AAA-0000)
    function _randomReferral(address user, uint256 idx) internal view returns (string memory) {
        bytes memory buf = new bytes(8);
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, user, idx)));
        for (uint256 i = 0; i < 3; i++) {
            buf[i] = bytes1(uint8(65 + (seed >> (i * 8)) % 26));
        }
        buf[3] = "-";
        for (uint256 i = 4; i < 8; i++) {
            buf[i] = bytes1(uint8(48 + (seed >> (i * 8)) % 10));
        }
        return string(buf);
    }

    /// @dev Pseudo-random xiom point generator (100-1000)
    function _randomXiom(address user) internal view returns (uint256) {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, user)));
        return ((seed % 10) + 1) * 100;
    }

    /// @dev Boost xiom points of all previous entries by 5%
    function _boostXioms() internal {
        for (uint256 i = 0; i < allEntries.length; i++) {
            uint256 tid = allEntries[i];
            tickets[tid].xiom = (tickets[tid].xiom * 105) / 100;
        }
    }

    function _toDoge(uint256 amount) internal view returns (uint256) {
        uint256 usdtdecimals = IERC20Metadata(address(usdtToken)).decimals();
        uint256 dogedecimals = IERC20Metadata(address(dogeToken)).decimals();
        (, int256 price,,,) = AggregatorV3Interface(priceFeed).latestRoundData();
        require(price > 0, "Invalid price");
        uint256 addDecimals = usdtdecimals - AggregatorV3Interface(priceFeed).decimals();
        uint256 dogeEquivalent = amount * (10 ** usdtdecimals) / (uint256(price) * 10 ** addDecimals);
        return dogeEquivalent * (10 ** dogedecimals) / (10 ** usdtdecimals);
    }

    /// @dev Ensures the contract is in expected state
    function _ensureState(LotteryState expected, string memory msgError) internal view {
        if (currentState != expected) revert TDError(msgError);
    }

    /// @dev Reverts with error string
    function _ensure(bool condition, string memory msgError) internal pure {
        if (!condition) revert TDError(msgError);
    }

    /// @notice Returns ticket data
    function getTicket(uint256 tid) external view returns (Ticket memory) {
        return tickets[tid];
    }

    /// @notice Returns caller’s tickets
    function myTickets() external view returns (Ticket[] memory) {
        uint256 total = nextTokenId;
        uint256 count;
        for (uint256 i = 1; i <= total; i++) {
            if (ownerOf(i) == msg.sender) count++;
        }
        Ticket[] memory result = new Ticket[](count);
        uint256 idx;
        for (uint256 i = 1; i <= total; i++) {
            if (ownerOf(i) == msg.sender) {
                result[idx++] = tickets[i];
            }
        }
        return result;
    }

    /// @notice Latest winners/prizes getters
    function latestNewWinner() external view returns (address) {
        return lastNewWinners[drawCount - 2];
    }

    function latestOldWinner() external view returns (address) {
        return lastOldWinners[drawCount - 2];
    }

    function latestNewPrize() external view returns (uint256) {
        return lastNewPrizes[drawCount - 2];
    }

    function latestOldPrize() external view returns (uint256) {
        return lastOldPrizes[drawCount - 2];
    }

    /// @notice Get xiom points for a ticket
    function xiomOf(uint256 tid) external view returns (uint256) {
        return tickets[tid].xiom;
    }
}
