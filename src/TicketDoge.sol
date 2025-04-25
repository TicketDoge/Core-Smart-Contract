// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {console} from "forge-std/console.sol";

contract TicketDoge is ERC721URIStorage, Ownable {
    enum State {
        Started,
        SelectingWinners,
        Paused
    }

    struct ListedToken {
        string tokenURI;
        uint256 tokenId;
        uint256 drawId;
        address payable owner;
        uint256 price;
        string referral;
        uint256 totalreferralUsed;
        uint256 totalReferralEarned;
        uint256 uplineId;
    }

    error TicketDoge__Error(string errorMessage);

    IERC20 public USDT;
    uint256 public USDT_DESIMALS;

    State public state = State.Started;

    uint256 public MINIMUM_ENTRANCE;
    uint256 public MAXIMUM_ENTRANCE;

    uint256 private _tokenId;

    address public immutable TEAM_BENEFIT_WALLET;
    uint256 public constant TEAM_BENEFIT_FEE = 21;
    address public immutable FUTURE_PROJECT_WALLET;
    uint256 public constant FUTURE_PROJECT_FEE = 21;
    address public immutable CHARITY_WALLET;
    uint256 public constant CHARITY_FEE = 8;

    uint256[] newPlayers;
    uint256[] oldPlayers;

    uint256 public drawPool;
    uint256 public drawId = 1;
    uint256 public constant TARGET_DRAW_BALANCE = 250000000000000000000;

    uint256 public REFERRER_REWARD = 10;
    uint256 public REFERRAL_REWARD = 21;
    uint256 public DIVIDER = 100;

    uint256 public PRIZE_COEFFICIANT = 3333;

    address[] newPlayersWinners;
    address[] oldPlayersWinners;
    uint256[] newPlayersWinnersPrizes;
    uint256[] oldPlayersWinnersPrizes;

    mapping(uint256 tokenId => ListedToken token) public idToListedToken;
    mapping(address user => bool isUser) public isUser;
    mapping(string referralCode => bool isrefferal) public isrefferal;
    mapping(string referralCode => address owner) public referralToOwner;
    mapping(string referralCode => uint256 token) public referralToTokenId;
    mapping(uint256 tokenId => string referralCode) public tokenIdToReferral;
    mapping(uint256 tokenId => address owner) public tokenIdToOwner;

    constructor(
        address initialOwner,
        address _usdt,
        uint256 _minimumEntrance,
        address _teamBenefitWallet,
        address _futureProjectWallet,
        address _charityWallet
    ) ERC721("Ticket Doge", "TDN") Ownable(initialOwner) {
        USDT = IERC20(_usdt);
        USDT_DESIMALS = IERC20Metadata(_usdt).decimals();

        MINIMUM_ENTRANCE = _minimumEntrance;
        MAXIMUM_ENTRANCE = uint256(125000000000000000000000) / uint256(3333);

        TEAM_BENEFIT_WALLET = _teamBenefitWallet;
        FUTURE_PROJECT_WALLET = _futureProjectWallet;
        CHARITY_WALLET = _charityWallet;
    }

    function createNft(
        uint256 ticketPrice,
        address user,
        bool hasReferral,
        string memory referralCode,
        string memory tokenURI
    ) public {
        string memory ticketReferral;
        for (uint256 i = 0; i < 10; i++) {
            ticketReferral = _generateRandomReferral(user, i);
            if (!isrefferal[ticketReferral]) {
                break;
            }
        }

        _require(state == State.Started, "Target Pool Balance Is Reached, Wait For Selecting Winner");

        _require(ticketPrice >= MINIMUM_ENTRANCE, "Insufficient Amount To Send");

        _require(ticketPrice < MAXIMUM_ENTRANCE, "Too Much Amount To Send");

        if (hasReferral) {
            _require(isrefferal[referralCode], "Referral Does Not Exist");
            _require(referralToOwner[referralCode] != user, "Can not Use Your Own Referral");
            ticketPrice = (ticketPrice * (DIVIDER - REFERRER_REWARD)) / DIVIDER;
        }

        _require(USDT.transferFrom(msg.sender, address(this), ticketPrice), "USDT Transfer Failed");

        _tokenId++;

        _safeMint(user, _tokenId);
        _setTokenURI(_tokenId, tokenURI);

        address upline;
        uint256 uplineId;
        if (hasReferral) {
            upline = referralToOwner[referralCode];
            uplineId = referralToTokenId[referralCode];
            idToListedToken[uplineId].totalreferralUsed++;

            idToListedToken[_tokenId] = ListedToken({
                tokenURI: tokenURI,
                tokenId: _tokenId,
                drawId: drawId,
                owner: payable(user),
                price: ticketPrice,
                referral: ticketReferral,
                totalreferralUsed: 0,
                totalReferralEarned: 0,
                uplineId: uplineId
            });
        } else {
            idToListedToken[_tokenId] = ListedToken({
                tokenURI: tokenURI,
                tokenId: _tokenId,
                drawId: drawId,
                owner: payable(user),
                price: ticketPrice,
                referral: ticketReferral,
                totalreferralUsed: 0,
                totalReferralEarned: 0,
                uplineId: 0
            });
        }

        referralToTokenId[ticketReferral] = _tokenId;
        tokenIdToReferral[_tokenId] = ticketReferral;
        tokenIdToOwner[_tokenId] = user;
        referralToOwner[ticketReferral] = user;
        isrefferal[ticketReferral] = true;

        newPlayers.push(_tokenId);
        oldPlayers.push(_tokenId);

        _distributeAmount(ticketPrice, hasReferral, upline, uplineId);
    }

    function _distributeAmount(uint256 amount, bool hasReferral, address upline, uint256 uplineId) internal {
        if (hasReferral) {
            uint256 uplineReward = (amount * (REFERRAL_REWARD)) / DIVIDER;
            amount -= uplineReward;
            idToListedToken[uplineId].totalReferralEarned += uplineReward;
            _require(USDT.transfer(upline, uplineReward), "USDT Transfer Failed");
        }

        uint256 teamBenefitAmount = (amount * (TEAM_BENEFIT_FEE)) / DIVIDER;
        _require(USDT.transfer(TEAM_BENEFIT_WALLET, teamBenefitAmount), "USDT Transfer Failed");

        uint256 futureProjectAmount = (amount * (FUTURE_PROJECT_FEE)) / DIVIDER;
        _require(USDT.transfer(FUTURE_PROJECT_WALLET, futureProjectAmount), "USDT Transfer Failed");

        uint256 charityAmount = (amount * (CHARITY_FEE)) / DIVIDER;
        _require(USDT.transfer(CHARITY_WALLET, charityAmount), "USDT Transfer Failed");

        drawPool += (amount * (DIVIDER - TEAM_BENEFIT_FEE - FUTURE_PROJECT_FEE - CHARITY_FEE)) / DIVIDER;

        if (drawPool >= TARGET_DRAW_BALANCE) {
            state = State.SelectingWinners;
        }
    }

    function _require(bool condition, string memory message) internal pure {
        if (!condition) {
            revert TicketDoge__Error(message);
        }
    }

    function selectingWinners() public {
        _require(state == State.SelectingWinners, "Target Pool Balance Is Not Reached");
        uint256 newPlayersSize = newPlayers.length;
        uint256 oldPlayerSize = oldPlayers.length;

        uint256 newPlayersWinnerIndex = _randNum(newPlayersSize, 0);
        uint256 oldPlayersWinnerIndex = _randNum(oldPlayerSize, 1);

        uint256 newPlayersWinnerTokenId = newPlayers[newPlayersWinnerIndex];
        address newPlayersWinner = tokenIdToOwner[newPlayersWinnerTokenId];
        uint256 newPlayersWinnerPrize = (idToListedToken[newPlayersWinnerTokenId].price * PRIZE_COEFFICIANT) / 1000;

        uint256 oldPlayersWinnerTokenId = oldPlayers[oldPlayersWinnerIndex];
        address oldPlayersWinner = tokenIdToOwner[oldPlayersWinnerTokenId];
        uint256 oldPlayersWinnerPrize = (idToListedToken[oldPlayersWinnerTokenId].price * PRIZE_COEFFICIANT) / 1000;

        _require(USDT.transfer(newPlayersWinner, newPlayersWinnerPrize), "USDT Transfer Failed");

        _require(USDT.transfer(oldPlayersWinner, oldPlayersWinnerPrize), "USDT Transfer Failed");

        newPlayersWinners.push(newPlayersWinner);
        oldPlayersWinners.push(oldPlayersWinner);
        newPlayersWinnersPrizes.push(newPlayersWinnerPrize);
        oldPlayersWinnersPrizes.push(oldPlayersWinnerPrize);

        delete newPlayers;
        drawPool -= (newPlayersWinnerPrize + oldPlayersWinnerPrize);
        drawId++;

        state = State.Started;
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721, IERC721) {
        string memory referral = idToListedToken[tokenId].referral;
        referralToOwner[referral] = to;
        idToListedToken[tokenId].owner = payable(to);
        super.transferFrom(from, to, tokenId);
    }

    function _randNum(uint256 size, uint256 index) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1), index))) % size;
    }

    function _generateRandomReferral(address user, uint256 index) internal view returns (string memory) {
        bytes memory result = new bytes(8);

        uint256 randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, user, index)));

        for (uint256 i = 0; i < 3; i++) {
            uint256 rand = uint256(keccak256(abi.encodePacked(randomSeed, i)));
            result[i] = bytes1(uint8(65 + (rand % 26)));
        }

        result[3] = bytes1(uint8(45));

        for (uint256 i = 4; i < 8; i++) {
            uint256 rand = uint256(keccak256(abi.encodePacked(randomSeed, i)));
            result[i] = bytes1(uint8(48 + (rand % 10)));
        }

        return string(result);
    }

    function getToken(uint256 tokenId) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint256 totalItemCount = _tokenId;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (ownerOf(i + 1) == msg.sender) {
                itemCount += 1;
            }
        }

        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (ownerOf(i + 1) == msg.sender) {
                uint256 currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    function getLatestNewPlayersWinner() public view returns (address) {
        return newPlayersWinners[drawId - 2];
    }

    function getLatestOldPlayersWinner() public view returns (address) {
        return oldPlayersWinners[drawId - 2];
    }

    function getLatestNewPlayersPrize() public view returns (uint256) {
        return newPlayersWinnersPrizes[drawId - 2];
    }

    function getLatestOldPlayersPrize() public view returns (uint256) {
        return oldPlayersWinnersPrizes[drawId - 2];
    }
}
