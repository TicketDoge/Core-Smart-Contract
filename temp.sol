// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title TicketDoge Lottery Contract (with on-chain “top21” leaderboard)
/// @notice Manages ticket minting, referral rewards, and 21-winner payout using a fixed-size array
contract TicketDoge is ERC721URIStorage, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Possible states of the lottery
    enum State {
        Open,
        Distributing
    }

    /// @notice Represents a lottery ticket with referral tracking
    struct Ticket {
        string uri;           // Metadata URI
        uint256 id;           // NFT token ID
        address payable holder; // Ticket owner
        uint256 price;        // Paid price in USDT
        string referralCode;  // Referral code for this ticket
        uint256 timesUsed;    // Number of times this referral was used
        uint256 earnings;     // Total referral earnings (in USDT)
        uint256 referrerId;   // Upline ticket ID (0 if none)
        uint256 xiom;         // Loyalty points
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

    // Doge Wallet
    address private immutable dogeWallet;

    // Fee percentages (basis points)
    uint256 public constant TEAM_FEE_BPS = 21;
    uint256 public constant FUTURE_FEE_BPS = 21;
    uint256 public constant CHARITY_FEE_BPS = 8;

    // Draw pool and configuration
    uint256 public rewardPool;
    uint256 public immutable TARGET_POOL; // e.g. 250 USDT (for Test)

    // Referral & prize settings
    uint256 public constant REFERRER_REWARD_BPS = 10;
    uint256 public constant REFERRAL_REWARD_BPS = 21;
    uint256 public constant BPS_DIVIDER = 100;
    uint256 public constant PRIZE_MULTIPLIER = 3333;

    // Tracking all minted ticket IDs
    uint256[] private allEntries;

    // Mappings for tickets/referrals
    mapping(uint256 => Ticket) public tickets;
    mapping(string => bool) public referralExists;
    mapping(string => uint256) public referralToTicket;
    mapping(string => address) public referralToOwner;
    mapping(uint256 => string) public ticketToReferral;
    mapping(uint256 => address) public ticketToOwner;

    // ───────────────────────────────────────────────
    // NEW: Track which addresses have already won ANY previous draw
    mapping(address => bool) public hasWon;

    // NEW: Fixed-size “leaderboard” of at most 21 ticket IDs, sorted by descending xiom
    uint256[] public topTicketIds;
    uint256 public constant MAX_WINNERS = 21;
    // ───────────────────────────────────────────────

    /// @param initialOwner   Owner of the contract
    /// @param _usdt          Address of USDT token
    /// @param _doge          Address of Doge token
    /// @param _minEntry      Minimum ticket price in USDT (wei)
    /// @param _teamWallet    Team fee receiver
    /// @param _futureWallet  Future project fee receiver
    /// @param _charityWallet Charity fee receiver
    /// @param _dogeWallet    Address that holds Doge for referral payouts
    /// @param _priceFeed     Chainlink price feed (Doge/USD)
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
        TARGET_POOL = 105 * 10 ** IERC20Metadata(_usdt).decimals(); // e.g. 105 USDT
        teamWallet = _teamWallet;
        futureProjWallet = _futureWallet;
        charityWallet = _charityWallet;
        dogeWallet = _dogeWallet;
        priceFeed = _priceFeed;
    }

    // ───────────────────────────────────────────────
    // 1) MINT A NEW LOTTERY TICKET
    // ───────────────────────────────────────────────

    /// @notice Mints a new lottery ticket
    /// @param ticketPrice Price in USDT to mint (wei)
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

        // 1) Generate unique referral code for this new ticket
        string memory newCode = _generateUniqueReferral(recipient);

        address upline;
        uint256 uplineId = 0;
        if (useReferral) {
            _ensure(referralExists[refCode], "Invalid referral code");
            _ensure(referralToOwner[refCode] != recipient, "Cannot use your own referral");
            upline = referralToOwner[refCode];
            uplineId = referralToTicket[refCode];
            // Discount for referred user
            ticketPrice = (ticketPrice * (BPS_DIVIDER - REFERRER_REWARD_BPS)) / BPS_DIVIDER;
        }

        // 2) Transfer USDT from msg.sender and mint NFT
        usdtToken.safeTransferFrom(msg.sender, address(this), ticketPrice);
        nextTokenId++;
        _safeMint(recipient, nextTokenId);
        _setTokenURI(nextTokenId, uri);

        // 3) Assign initial random xiom points (100–1000)
        uint256 xiomPts = _randomXiom(recipient);

        // 4) Store ticket data
        tickets[nextTokenId] = Ticket({
            uri: uri,
            id: nextTokenId,
            holder: payable(recipient),
            price: ticketPrice,
            referralCode: newCode,
            timesUsed: 0,
            earnings: 0,
            referrerId: useReferral ? uplineId : 0,
            xiom: xiomPts
        });

        // 5) Register referral mappings
        referralExists[newCode] = true;
        referralToTicket[newCode] = nextTokenId;
        ticketToReferral[nextTokenId] = newCode;
        referralToOwner[newCode] = recipient;
        ticketToOwner[nextTokenId] = recipient;

        // 6) Add to allEntries for future xiom boosts
        allEntries.push(nextTokenId);

        // 7) UPDATE “top21” LEADERBOARD with this new ticket
        _updateTopTickets(nextTokenId);

        // 8) Distribute funds (fees, referrals, pool)
        _distributeFunds(ticketPrice, useReferral, upline, uplineId);
    }

    // ───────────────────────────────────────────────
    // 2) DISTRIBUTE USDT TO REFERRER, FEES, AND DRAW POOL
    // ───────────────────────────────────────────────
    function _distributeFunds(
        uint256 amount,
        bool useReferral,
        address upline,
        uint256 uplineId
    ) internal {
        if (useReferral) {
            uint256 reward = (amount * REFERRAL_REWARD_BPS) / BPS_DIVIDER;
            // 2.1) Pay referrer in USDT→Doge, add xiom to upline and ancestors
            tickets[uplineId].earnings += reward;
            tickets[uplineId].timesUsed++;
            tickets[uplineId].xiom += 1500;
            // RE-EVALUATE top21 for upline
            _updateTopTickets(uplineId);

            // Now boost ancestors by +1500 xiom each
            uint256 ancestor = tickets[uplineId].referrerId;
            while (ancestor != 0) {
                tickets[ancestor].xiom += 1500;
                _updateTopTickets(ancestor);
                ancestor = tickets[ancestor].referrerId;
            }

            // Convert “reward USDT” → “rewardInDoge”, send to upline
            uint256 rewardInDoge = _toDoge(reward);
            usdtToken.safeTransfer(dogeWallet, reward);
            dogeToken.safeTransferFrom(dogeWallet, upline, rewardInDoge);

            // Subtract referral reward from amount going forward
            amount -= reward;
        }

        // 2.2) Pay team, future project, and charity fees
        uint256 teamAmt = (amount * TEAM_FEE_BPS) / BPS_DIVIDER;
        uint256 futureAmt = (amount * FUTURE_FEE_BPS) / BPS_DIVIDER;
        uint256 charityAmt = (amount * CHARITY_FEE_BPS) / BPS_DIVIDER;
        usdtToken.safeTransfer(teamWallet, teamAmt);
        usdtToken.safeTransfer(futureProjWallet, futureAmt);
        usdtToken.safeTransfer(charityWallet, charityAmt);

        // 2.3) Add remainder to rewardPool; if ≥ TARGET_POOL, switch to Distributing
        uint256 poolContrib = (amount * (BPS_DIVIDER - TEAM_FEE_BPS - FUTURE_FEE_BPS - CHARITY_FEE_BPS)) / BPS_DIVIDER;
        rewardPool += poolContrib;
        if (rewardPool >= TARGET_POOL) {
            currentState = State.Distributing;
        }
    }

    // ───────────────────────────────────────────────
    // 3) PICK & PAY OUT UP TO 21 WINNERS
    // ───────────────────────────────────────────────

    /// @notice Selects up to 21 winners when pool target is reached.
    ///         We simply pay all ticket IDs in `topTicketIds`, mark them `hasWon`,
    ///         then clear `topTicketIds` for the next round.
    function pickWinners() external {
        _ensureState(State.Distributing, "Pool target not met");

        // If no one is currently in the top21 array, nothing to pay
        uint256 count = topTicketIds.length;
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
            hasWon[winner] = true;
        }

        // 3.2) Clear topTicketIds so that next draw starts fresh
        delete topTicketIds;

        // 3.3) Reset pool, boost everyone’s xiom by 5%, and reopen
        rewardPool = 0;
        _boostXioms();
        currentState = State.Open;
    }

    // ───────────────────────────────────────────────
    // 4) OVERRIDE TRANSFER TO KEEP REFERRAL MAPPINGS
    // ───────────────────────────────────────────────

    /// @notice Keep referral ownership when transferring tickets
    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) {
        string memory code = tickets[tokenId].referralCode;
        referralToOwner[code] = to;
        tickets[tokenId].holder = payable(to);
        super.transferFrom(from, to, tokenId);
    }

    // ───────────────────────────────────────────────
    // 5) REFERRAL & XIOM HELPERS
    // ───────────────────────────────────────────────

    /// @dev Creates a unique 8-char referral code (“AAA-0000”)
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

    /// @dev Pseudo-random xiom point generator (100–1000)
    function _randomXiom(address user) internal view returns (uint256) {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, user)));
        return ((seed % 10) + 1) * 100;
    }

    /// @dev Boost xiom points of *all* previous entries by 5%
    function _boostXioms() internal {
        for (uint256 i = 0; i < allEntries.length; i++) {
            uint256 tid = allEntries[i];
            tickets[tid].xiom = (tickets[tid].xiom * 105) / 100;
            // NOTE: Since *all* tickets get scaled by 1.05, their relative order does NOT change,
            // so we do NOT need to call _updateTopTickets here.
        }
    }

    /// @dev Convert an “amount” of USDT (wei) → equivalent Doge (wei), via Chainlink price feed
    function _toDoge(uint256 amount) internal view returns (uint256) {
        ( , int256 price, , , ) = AggregatorV3Interface(priceFeed).latestRoundData();
        require(price > 0, "Invalid price");
        uint256 rawPrice = uint256(price);
        uint256 priceDecimals = AggregatorV3Interface(priceFeed).decimals(); // e.g. 8
        uint256 usdtDecimals = IERC20Metadata(address(usdtToken)).decimals(); // e.g. 18
        uint256 dogeDecimals = IERC20Metadata(address(dogeToken)).decimals(); // e.g. 8

        // Make “amount” be at Doge-decimals before dividing by rawPrice
        if (usdtDecimals > dogeDecimals) {
            uint256 diff = usdtDecimals - dogeDecimals;
            amount = amount / (10 ** diff);
        } else {
            uint256 diff = dogeDecimals - usdtDecimals;
            amount = amount * (10 ** diff);
        }

        // (amount * 10^priceDecimals) / rawPrice = how many Doge (8-dec)
        uint256 dogeAmount = (amount * (10 ** priceDecimals)) / rawPrice;
        return dogeAmount;
    }

    // ───────────────────────────────────────────────
    // 6) TOP-21 LEADERBOARD MANAGEMENT
    // ───────────────────────────────────────────────

    /// @notice When a ticket’s xiom changes (or when it’s first minted),
    ///         call this to keep “topTicketIds” sorted (desc) with ≤ 21 entries.
    function _updateTopTickets(uint256 tid) internal {
        address holder = tickets[tid].holder;

        // 1) If this holder has already won in any previous draw, remove tid if present and return
        if (hasWon[holder]) {
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

    // ───────────────────────────────────────────────
    // 7) ENSURE HELPERS & VIEW FUNCTIONS
    // ───────────────────────────────────────────────

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

    /// @notice Returns all tickets owned by a given user
    function userTickets(address user) external view returns (Ticket[] memory) {
        uint256 total = nextTokenId;
        uint256 count = 0;
        for (uint256 i = 1; i <= total; i++) {
            if (ownerOf(i) == user) count++;
        }
        Ticket[] memory result = new Ticket[](count);
        uint256 idx = 0;
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
