// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {console} from "forge-std/console.sol";

/// @title TicketDoge Lottery Contract
/// @notice Manages ticket minting, referral rewards, and send reward
contract TicketDoge is ERC721URIStorage, Ownable {
    using SafeERC20 for IERC20;
    /// @notice Possible states of the lottery

    enum State {
        Open,
        Distributing
    }

    /// @notice Represents a lottery ticket with referral tracking
    struct Ticket {
        string uri; // Metadata URI
        uint256 id; // NFT token ID
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

    State public currentState = State.Open;

    uint256 public minEntry;

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
    uint256 public rewardPool;
    uint256 public immutable TARGET_POOL; // 250 USDT(for Test) @

    // Referral & prize settings
    uint256 public constant REFERRER_REWARD_BPS = 10;
    uint256 public constant REFERRAL_REWARD_BPS = 21;
    uint256 public constant BPS_DIVIDER = 100;
    uint256 public constant PRIZE_MULTIPLIER = 3333;

    // Tracking entries
    uint256[] private allEntries;

    // Mappings
    mapping(uint256 => Ticket) public tickets;
    mapping(string => bool) public referralExists;
    mapping(string => uint256) public referralToTicket;
    mapping(string => address) public referralToOwner;
    mapping(uint256 => string) public ticketToReferral;
    mapping(uint256 => address) public ticketToOwner;

    mapping(uint256 => bool) public hasWon;
    // NEW: Fixed-size “leaderboard” of at most 21 ticket IDs, sorted by descending xiom
    uint256[] public topTicketIds;
    uint256 public constant MAX_WINNERS = 21;

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
        TARGET_POOL = 105 * 10 ** IERC20Metadata(_usdt).decimals(); // @
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
        _ensureState(State.Open, "Draw not open");
        _ensure(ticketPrice >= minEntry, "Below minimum entry");

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
        usdtToken.safeTransferFrom(msg.sender, address(this), ticketPrice);
        nextTokenId++;
        _safeMint(recipient, nextTokenId);
        _setTokenURI(nextTokenId, uri);

        // Record ticket data
        uint256 xiomPts = _randomXiom(recipient);
        tickets[nextTokenId] = Ticket(
            uri, nextTokenId, payable(recipient), ticketPrice, newCode, 0, 0, useReferral ? uplineId : 0, xiomPts
        );

        // Register referral mappings
        referralExists[newCode] = true;
        referralToTicket[newCode] = nextTokenId;
        ticketToReferral[nextTokenId] = newCode;
        referralToOwner[newCode] = recipient;
        ticketToOwner[nextTokenId] = recipient;

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
            usdtToken.safeTransfer(dogeWallet, reward);
            dogeToken.safeTransferFrom(dogeWallet, upline, rewardInDoge);
            amount -= reward;
        }
        // Team fee
        uint256 teamAmt = (amount * TEAM_FEE_BPS) / BPS_DIVIDER;
        uint256 futureAmt = (amount * FUTURE_FEE_BPS) / BPS_DIVIDER;
        uint256 charityAmt = (amount * CHARITY_FEE_BPS) / BPS_DIVIDER;
        usdtToken.safeTransfer(teamWallet, teamAmt);
        usdtToken.safeTransfer(futureProjWallet, futureAmt);
        usdtToken.safeTransfer(charityWallet, charityAmt);

        // Add remainder to pool and check draw trigger
        rewardPool += (amount * (BPS_DIVIDER - TEAM_FEE_BPS - FUTURE_FEE_BPS - CHARITY_FEE_BPS)) / BPS_DIVIDER;
        if (rewardPool >= TARGET_POOL) {
            currentState = State.Distributing;
        }
    }

    /// @notice Selects up to 21 winners when the pool target is reached.
    ///         Once an address has won in any previous draw, they are skipped/never chosen again.
    function pickWinners() external {
        _ensureState(State.Distributing, "Pool target not met");

        // If no one is currently in the top21 array, nothing to pay
        uint256 count = topTicketIds.length;
        console.log(count);
        if (count == 0) {
            // Just reset pool & reopen
            rewardPool = 0;
            _boostXioms();
            currentState = State.Open;
            return;
        }

        // Compute “5 USDT” in token decimals
        uint256 decimals = IERC20Metadata(address(usdtToken)).decimals();
        uint256 prizeAmount = 5 * (10 ** decimals);

        // 3.1) Pay each of the (≤21) entries in topTicketIds
        for (uint256 i = 0; i < count; i++) {
            uint256 tid = topTicketIds[i];
            address payable winner = tickets[tid].holder;
            usdtToken.safeTransfer(winner, prizeAmount);
            // Mark permanently ineligible
            hasWon[tid] = true;
        }

        // 3.2) Clear topTicketIds so that next draw starts fresh
        delete topTicketIds;

        // 3.3) Reset pool, boost everyone’s xiom by 5%, and reopen
        rewardPool = 0;
        _boostXioms();
        currentState = State.Open;
    }

    /// @notice Override to keep referral ownership when transferring tickets
    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) {
        string memory code = tickets[tokenId].referralCode;
        referralToOwner[code] = to;
        tickets[tokenId].holder = payable(to);
        super.transferFrom(from, to, tokenId);
    }

    /// @dev Creates a unique 8-char referral code
    function _generateUniqueReferral(address user) internal view returns (string memory) {
        for (uint256 i = 0; i < 10; i++) {
            string memory code = _randomReferral(user, i);
            if (!referralExists[code]) {
                return code;
            }
        }
        revert TDError("Could not generate unique referral code");
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
        (, int256 price,,,) = AggregatorV3Interface(priceFeed).latestRoundData();
        require(price > 0, "Invalid price");
        // Let’s say priceFeed returns price = $0.12345678 (8‐decimals)
        // i.e. price = 0_12345678. To get “USDT → Doge” you might do:
        uint256 rawPrice = uint256(price); // e.g. 12345678
        uint256 priceDecimals = AggregatorV3Interface(priceFeed).decimals(); // = 8
        uint256 usdtDecimals = IERC20Metadata(address(usdtToken)).decimals(); // e.g. 18
        uint256 dogeDecimals = IERC20Metadata(address(dogeToken)).decimals(); // e.g. 8

        // Let’s compute: “how many DOGE units for 1 USDT”?
        // 1 USDT = $1.00. If Chainlink price is “1 DOGE = $0.12345678”, then 1 USDT → 8.10000000 DOGE.
        // dogeAmount = (1 * 10^usdtDecimals) * (10^priceDecimals) / rawPrice
        //             ^ (“1 USDT in USDT‐wei”)     ^(fix to 8‐decimals)
        if (usdtDecimals > dogeDecimals) {
            uint256 diff = usdtDecimals - dogeDecimals;
            amount = amount / (10 ** diff);
        } else {
            uint256 diff = dogeDecimals - usdtDecimals;
            amount = amount * (10 ** diff);
        }

        uint256 dogeAmount = (amount * 10 ** priceDecimals) / rawPrice;
        return dogeAmount;
    }

    /// @notice When a ticket’s xiom changes (or when it’s first minted),
    ///         call this to keep “topTicketIds” sorted (desc) with ≤ 21 entries.
    function _updateTopTickets(uint256 tid) internal {
        // 1) If this holder has already won in any previous draw, remove tid if present and return
        if (hasWon[tid]) {
            _removeFromTop(tid);
            return;
        }

        // 2) Remove tid if it was already in the array (so we can re-insert it)
        _removeFromTop(tid);

        // 3) If there’s still room (<21), just insert in order
        if (topTicketIds.length < MAX_WINNERS) {
            _insertToTop(tid);
            return;
        }

        // 4) Otherwise, check if tid’s xiom is strictly greater than the current “smallest” (last index)
        uint256 lastTid = topTicketIds[topTicketIds.length - 1];
        uint256 lastXiom = tickets[lastTid].xiom;
        uint256 xiomPts = tickets[tid].xiom;
        if (xiomPts > lastXiom) {
            // Evict the last (smallest) and re-insert tid
            topTicketIds.pop();
            _insertToTop(tid);
            return;
        }
        // If xiomPts ≤ lastXiom, it doesn’t belong in top21, so do nothing
    }

    /// @dev Helper: remove `tid` from `topTicketIds[]` if it’s there. Returns true if removed.
    function _removeFromTop(uint256 tid) internal returns (bool) {
        uint256 len = topTicketIds.length;
        for (uint256 i = 0; i < len; i++) {
            if (topTicketIds[i] == tid) {
                // Shift everything down from i+1 … len-1
                for (uint256 j = i; j + 1 < len; j++) {
                    topTicketIds[j] = topTicketIds[j + 1];
                }
                topTicketIds.pop();
                return true;
            }
        }
        return false;
    }

    /// @dev Helper: insert `tid` into `topTicketIds[]` in descending-`xiom` order.
    ///      After this, we guarantee length ≤ MAX_WINNERS (21) by popping if needed.
    function _insertToTop(uint256 tid) internal {
        uint256 xiomPts = tickets[tid].xiom;
        uint256 len = topTicketIds.length;

        // 1) Find insertion index (first i where existing xiom < xiomPts)
        uint256 idx = len; // default: append at end
        for (uint256 i = 0; i < len; i++) {
            uint256 curTid = topTicketIds[i];
            if (tickets[curTid].xiom < xiomPts) {
                idx = i;
                break;
            }
        }

        // 2) Push dummy to expand array by 1
        topTicketIds.push(tid);
        // 3) Shift elements right from idx…end
        for (uint256 j = topTicketIds.length - 1; j > idx; j--) {
            topTicketIds[j] = topTicketIds[j - 1];
        }
        // 4) Place tid at position idx
        topTicketIds[idx] = tid;

        // 5) If we now exceed MAX_WINNERS, pop the last element
        if (topTicketIds.length > MAX_WINNERS) {
            topTicketIds.pop();
        }
    }

    /// @dev Ensures the contract is in expected state
    function _ensureState(State expected, string memory msgError) internal view {
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
    function userTickets(address user) external view returns (Ticket[] memory) {
        uint256 total = nextTokenId;
        uint256 count;
        for (uint256 i = 1; i <= total; i++) {
            if (ownerOf(i) == user) count++;
        }
        Ticket[] memory result = new Ticket[](count);
        uint256 idx;
        for (uint256 i = 1; i <= total; i++) {
            if (ownerOf(i) == user) {
                result[idx++] = tickets[i];
            }
        }
        return result;
    }

    /// @notice Get xiom points for a ticket
    function xiomOf(uint256 tid) external view returns (uint256) {
        return tickets[tid].xiom;
    }
}
