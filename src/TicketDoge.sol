/*

 /$$$$$$$                                      /$$$$$$$$ /$$           /$$                   /$$    
| $$__  $$                                    |__  $$__/|__/          | $$                  | $$    
| $$  \ $$  /$$$$$$   /$$$$$$   /$$$$$$          | $$    /$$  /$$$$$$$| $$   /$$  /$$$$$$  /$$$$$$  
| $$  | $$ /$$__  $$ /$$__  $$ /$$__  $$         | $$   | $$ /$$_____/| $$  /$$/ /$$__  $$|_  $$_/  
| $$  | $$| $$  \ $$| $$  \ $$| $$$$$$$$         | $$   | $$| $$      | $$$$$$/ | $$$$$$$$  | $$    
| $$  | $$| $$  | $$| $$  | $$| $$_____/         | $$   | $$| $$      | $$_  $$ | $$_____/  | $$ /$$
| $$$$$$$/|  $$$$$$/|  $$$$$$$|  $$$$$$$         | $$   | $$|  $$$$$$$| $$ \  $$|  $$$$$$$  |  $$$$/
|_______/  \______/  \____  $$ \_______/         |__/   |__/ \_______/|__/  \__/ \_______/   \___/  
                     /$$  \ $$                                                                      
                   |  $$$$$$/                                                                      
                    \______/                                                                       

*/

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Counters.sol";
import {console} from "forge-std/console.sol";

struct ListedToken {
    string tokenURI;
    uint256 tokenId;
    uint256 drawId;
    address payable owner;
    uint256 price;
    string refral;
    uint256 totalreferralUsed;
    uint256 totalReferralEarned;
    bool listed;
    uint256 totalPriceUSD;
    uint256 uplineId;
    uint256 depth;
    uint256 allDirects;
}

struct Player {
    uint256 draw_Id;
    uint256 nft_Id;
    uint256 amount;
    uint256 time;
    address payable nftAddress;
    uint256 totalPriceUSD;
}

contract TicketDoge is ERC721URIStorage {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error DogeTicket__OnlyOwner(address account);
    error DogeTicket__ReferralCanNotBeUsedByReferralOwner();
    error DogeTicket__ReferralAlreadyCreated();
    error DogeTicket__ReentrencyCall();
    error DogeTicket__TransferFailed();
    error DogeTicket__IncufficientTicketPrice();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    //Mappings
    mapping(uint256 => ListedToken) private idToListedToken;
    mapping(uint256 tokenId => string referral) private tokenIdToReferral;
    mapping(string referralCode => uint256 tokenId) private referralToTokenId;
    mapping(string referralCode => address ownerReferralCode)
        private referralToOwner;
    mapping(string referralCode => bool hasCreated) private referralHasCreated;
    mapping(address user => uint256 nfts) private usersNfts;

    Player[] private totalPlayers;
    Player[] private newplayers;
    address[] private users;

    //Counter Variables
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;

    //Initial Variables
    address public immutable dogeCoinToken;
    uint256 public nftToCarPecentage = 10;
    uint256 public drawFeePercentage = 0;
    uint256 public totalDogeWinner;
    address payable owner;
    uint256 public drawId = 1;
    address public team;
    address public futureProject;
    address public charity;
    uint256 public feePool;
    uint256 public feeTeam;
    uint256 public feeFutureProject;
    uint256 public feeCharity;
    uint256 public feeOwnerReferral;
    uint256 public feeSpenderReferral;
    uint256 public totalPool;
    uint256 public constant MINIMUM_TICKET_PRICE = 300000e18;
    //Getter variables
    address public recentTotalWinner;
    address public recentNewWinner;
    uint256 public lastTotalReward;
    uint256 public lastNewReward;

    //Reentrency Lock Variables
    bool private createLock = false;
    bool private winnerTotalLock = false;
    bool private winnerNewLock = false;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert DogeTicket__OnlyOwner(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event CreateNft(
        uint256 indexed tokenId,
        address indexed _address,
        string _tokenURI,
        uint256 indexed _lotteryId,
        uint256 _timestamp,
        string _referralCode,
        uint256 _totalPriceUSD
    );
    event CreateDraw(
        uint256 indexed _lotteryId,
        uint256 _totalPlayers,
        uint256 _nftIdWinner_Players,
        address indexed _winnerPlayers,
        uint256 _amount,
        uint256 _time
    );

    event CreateNewDraw(
        uint256 indexed _lotteryId,
        uint256 _totalPlayers,
        uint256 _nftIdWinner_Players,
        address indexed _winnerPlayers,
        uint256 _amount,
        uint256 _time
    );

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _token,
        address _team,
        address _futureProject,
        address _charity,
        uint256 _feePool,
        uint256 _feeTeam,
        uint256 _feeFutureProject,
        uint256 _feeCharity,
        uint256 _feeOwnerRefral,
        uint256 _feeSpenderReferral,
        uint256 _totalDogeWinner
    ) ERC721("Ticket Doge NFT", "TDN") {
        owner = payable(msg.sender);
        team = _team;
        futureProject = _futureProject;
        charity = _charity;
        feePool = _feePool;
        feeTeam = _feeTeam;
        feeFutureProject = _feeFutureProject;
        feeCharity = _feeCharity;
        feeOwnerReferral = _feeOwnerRefral;
        feeSpenderReferral = _feeSpenderReferral;
        totalDogeWinner = _totalDogeWinner;
        dogeCoinToken = _token;
    }

    /*//////////////////////////////////////////////////////////////
                           ERC721 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {
        super.transferFrom(from, to, tokenId);
        string memory referral = tokenIdToReferral[tokenId];
        referralToOwner[referral] = to;
        usersNfts[msg.sender]--;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override(ERC721, IERC721) {
        super.safeTransferFrom(from, to, tokenId, data);
        string memory referral = tokenIdToReferral[tokenId];
        referralToOwner[referral] = to;
        usersNfts[msg.sender]--;
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createToken(
        string memory tokenURI,
        uint256 totalCarPrice,
        string memory _referralCode,
        string memory _upReferral,
        uint256 _totalPriceUSD
    ) external {
        if (createLock) {
            revert DogeTicket__ReentrencyCall();
        }
        createLock = true;

        if (totalCarPrice < MINIMUM_TICKET_PRICE) {
            revert DogeTicket__IncufficientTicketPrice();
        }

        if (referralHasCreated[_referralCode]) {
            revert DogeTicket__ReferralAlreadyCreated();
        }
        referralHasCreated[_referralCode] = true;

        _tokenIds.increment();
        uint256 currentTokenId = _tokenIds.current();
        _safeMint(msg.sender, currentTokenId);
        _setTokenURI(currentTokenId, tokenURI);
        usersNfts[msg.sender]++;
        users.push(msg.sender);

        uint256 mintPrice = (totalCarPrice * nftToCarPecentage) / 10000;
        mintPrice = ((mintPrice * (10000 + drawFeePercentage)) / 10000);

        if (referralToOwner[_upReferral] != address(0)) {
            if (referralToOwner[_upReferral] == msg.sender) {
                revert DogeTicket__ReferralCanNotBeUsedByReferralOwner();
            }

            mintPrice = (mintPrice * (100 - feeSpenderReferral)) / 100;

            bool success = IERC20(dogeCoinToken).transferFrom(
                msg.sender,
                address(this),
                mintPrice
            );
            if (!success) {
                revert DogeTicket__TransferFailed();
            }

            uint256 referralReward = (mintPrice * feeOwnerReferral) / 100;
            transferToReferral(_upReferral, referralReward);
            idToListedToken[referralToTokenId[_upReferral]].totalreferralUsed++;

            mintPrice = (mintPrice * (100 - feeOwnerReferral)) / 100;

            transferToMgmts(mintPrice);

            totalPool += (mintPrice * feePool) / 100;

            referralToOwner[_referralCode] = msg.sender;
            tokenIdToReferral[currentTokenId] = _referralCode;
            referralToTokenId[_referralCode] = currentTokenId;

            totalPlayers.push(
                Player({
                    draw_Id: drawId,
                    nft_Id: currentTokenId,
                    amount: mintPrice,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceUSD: _totalPriceUSD
                })
            );
            newplayers.push(
                Player({
                    draw_Id: drawId,
                    nft_Id: currentTokenId,
                    amount: mintPrice,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceUSD: _totalPriceUSD
                })
            );
            emit CreateNft(
                currentTokenId,
                msg.sender,
                tokenURI,
                drawId,
                block.timestamp,
                _referralCode,
                _totalPriceUSD
            );

            uint256 _uplineId = referralToTokenId[_upReferral];
            idToListedToken[_uplineId].allDirects++;
            uint256 depthChild = idToListedToken[_uplineId].depth + 1;

            uint256 upperId = idToListedToken[_uplineId].uplineId;

            for (uint256 j; j < idToListedToken[_uplineId].depth; j++) {
                idToListedToken[upperId].allDirects++;
                upperId = idToListedToken[upperId].uplineId;
            }

            idToListedToken[currentTokenId] = ListedToken(
                tokenURI,
                currentTokenId,
                drawId,
                payable(msg.sender),
                mintPrice,
                _referralCode,
                0,
                0,
                true,
                _totalPriceUSD,
                _uplineId,
                depthChild,
                0
            );
        } else {
            bool success = IERC20(dogeCoinToken).transferFrom(
                msg.sender,
                address(this),
                mintPrice
            );
            if (!success) {
                revert DogeTicket__TransferFailed();
            }

            transferToMgmts(mintPrice);

            totalPool += (mintPrice * feePool) / 100;

            referralToOwner[_referralCode] = msg.sender;
            tokenIdToReferral[currentTokenId] = _referralCode;
            referralToTokenId[_referralCode] = currentTokenId;

            idToListedToken[currentTokenId] = ListedToken(
                tokenURI,
                currentTokenId,
                drawId,
                payable(msg.sender),
                mintPrice,
                _referralCode,
                0,
                0,
                true,
                _totalPriceUSD,
                0,
                0,
                0
            );

            totalPlayers.push(
                Player({
                    draw_Id: drawId,
                    nft_Id: currentTokenId,
                    amount: mintPrice,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceUSD: _totalPriceUSD
                })
            );
            newplayers.push(
                Player({
                    draw_Id: drawId,
                    nft_Id: currentTokenId,
                    amount: mintPrice,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceUSD: _totalPriceUSD
                })
            );
            emit CreateNft(
                currentTokenId,
                msg.sender,
                tokenURI,
                drawId,
                block.timestamp,
                _referralCode,
                _totalPriceUSD
            );
        }

        if (totalPool >= totalDogeWinner) {
            createWinnerTotalPlayers("code");
        }
        createLock = false;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createWinnerTotalPlayers(string memory _code) internal {
        if (winnerTotalLock) {
            revert DogeTicket__ReentrencyCall();
        }
        winnerTotalLock = true;

        uint256 winnerTotalPlayer = _randomModulo(totalPlayers.length, _code);
        uint256 _tokenId = totalPlayers[winnerTotalPlayer].nft_Id;
        address winnerTotalPlayerAddress = totalPlayers[winnerTotalPlayer]
            .nftAddress == ownerOf(_tokenId)
            ? totalPlayers[winnerTotalPlayer].nftAddress
            : ownerOf(_tokenId);

        // uint256 p_winner=totalPlayers[winnerTotalPlayer].amount ;
        uint256 priceWinner = totalPool / 2;

        bool success = IERC20(dogeCoinToken).transfer(
            payable(winnerTotalPlayerAddress),
            priceWinner
        );

        if (!success) {
            revert DogeTicket__TransferFailed();
        }

        emit CreateDraw(
            drawId,
            totalPlayers.length,
            totalPlayers[winnerTotalPlayer].nft_Id,
            winnerTotalPlayerAddress,
            priceWinner,
            block.timestamp
        );
        deleteIndexArray(winnerTotalPlayer);
        totalPool -= priceWinner;
        lastTotalReward = priceWinner;
        recentTotalWinner = winnerTotalPlayerAddress;

        createWinnerNewPlayers("code");
        winnerTotalLock = false;
    }

    function createWinnerNewPlayers(string memory _code) internal {
        if (winnerNewLock) {
            revert DogeTicket__ReentrencyCall();
        }
        winnerNewLock = true;
        uint256 winnerNewPlayer = _randomModulo(newplayers.length, _code);
        uint256 _tokenId = newplayers[winnerNewPlayer].nft_Id;
        address winnerNewPlayerAddress = newplayers[winnerNewPlayer]
            .nftAddress == ownerOf(_tokenId)
            ? newplayers[winnerNewPlayer].nftAddress
            : ownerOf(_tokenId);

        // uint256 p_winner=totalPlayers[winnerNewPlayer].amount;
        uint256 priceWinner = totalPool;

        bool success = IERC20(dogeCoinToken).transfer(
            payable(winnerNewPlayerAddress),
            priceWinner
        );

        if (!success) {
            revert DogeTicket__TransferFailed();
        }

        emit CreateNewDraw(
            drawId,
            newplayers.length,
            newplayers[winnerNewPlayer].nft_Id,
            winnerNewPlayerAddress,
            priceWinner,
            block.timestamp
        );

        recentNewWinner = winnerNewPlayerAddress;
        lastNewReward = priceWinner;
        delete newplayers;
        totalPool = 0;
        drawId++;
        drawFeePercentage = drawFeePercentage + 110;
        winnerNewLock = false;
    }

    function transferToMgmts(uint256 amount) internal {
        bool success1 = IERC20(dogeCoinToken).transfer(
            team,
            (amount * feeTeam) / 100
        );

        bool success2 = IERC20(dogeCoinToken).transfer(
            futureProject,
            (amount * feeFutureProject) / 100
        );

        bool success3 = IERC20(dogeCoinToken).transfer(
            charity,
            (amount * feeCharity) / 100
        );

        if (!success1 || !success2 || !success3) {
            revert DogeTicket__TransferFailed();
        }
    }

    function transferToReferral(
        string memory referralCode,
        uint256 amount
    ) internal {
        address referralOwner = referralToOwner[referralCode];
        uint256 id = referralToTokenId[referralCode];
        bool success = IERC20(dogeCoinToken).transfer(referralOwner, amount);

        idToListedToken[id].totalReferralEarned += amount;

        if (!success) {
            revert DogeTicket__TransferFailed();
        }
    }

    function _randomModulo(
        uint256 madulo,
        string memory code
    ) internal view returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(block.timestamp, code))) %
            madulo;
    }

    function deleteIndexArray(uint256 index) internal {
        for (uint256 i = index; i < totalPlayers.length - 1; i++) {
            totalPlayers[i] = totalPlayers[i + 1];
        }
        totalPlayers.pop();
    }

    /*//////////////////////////////////////////////////////////////
                       VIEW AND PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint256 totalItemCount = _tokenIds.current();
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

    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint256 nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);

        uint256 currentIndex = 0;
        for (uint256 i = 0; i < nftCount; i++) {
            uint256 currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        return tokens;
    }

    function getTotalPlayers() public view returns (Player[] memory) {
        return totalPlayers;
    }

    function getNewPlayers() public view returns (Player[] memory) {
        return newplayers;
    }

    function getTotalPool() public view returns (uint256) {
        return totalPool;
    }

    function getTotalDogeWinner() public view returns (uint256) {
        return totalDogeWinner;
    }

    function getOwnerAddress() public view returns (address) {
        return owner;
    }

    function getRecentTotalWinner() public view returns (address) {
        return recentTotalWinner;
    }

    function getRecentNewWinner() public view returns (address) {
        return recentNewWinner;
    }

    function getReferralCodeById(
        uint256 tokenId
    ) public view returns (string memory) {
        return tokenIdToReferral[tokenId];
    }

    function getReferralOwner(
        string memory referral
    ) public view returns (address) {
        return referralToOwner[referral];
    }

    function getTokenIdByReferral(
        string memory referral
    ) public view returns (uint256) {
        return referralToTokenId[referral];
    }

    function getNftToCarPercentage() public view returns (uint256) {
        return nftToCarPecentage;
    }

    function getDrawFeePercentage() public view returns (uint256) {
        return drawFeePercentage;
    }

    function getListedTokenFromId(
        uint256 tokenId
    ) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    function getDrawId() public view returns (uint256) {
        return drawId;
    }

    function getLastTotalReward() public view returns (uint256) {
        return lastTotalReward;
    }

    function getLastNewReward() public view returns (uint256) {
        return lastNewReward;
    }

    function getReferralHasCreated(
        string memory referral
    ) public view returns (bool) {
        return referralHasCreated[referral];
    }

    function getAllDirects(uint256 id) public view returns (uint256) {
        return idToListedToken[id].allDirects;
    }

    function getUserNftsCount(address user) public view returns (uint256) {
        return usersNfts[user];
    }

    function getAllUsers() public view returns (address[] memory) {
        return users;
    }
}
