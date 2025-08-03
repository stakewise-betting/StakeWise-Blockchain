// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RaffleDraw {
    // STATE VARIABLES
    address public admin;
    uint256 public nextRaffleId;

    // DATA STRUCTURES
    struct Raffle {
        uint256 raffleId;
        string name;
        string imageURL;
        string category;
        uint256 startTime;
        uint256 endTime;
        uint256 ticketPrice;
        uint256 prizeAmount;
        bool isCompleted;
        address winner;
        uint256 totalTicketsSold;
        address[] participants;
        mapping(address => uint256) ticketsBought;
    }

    struct RaffleView {
        uint256 raffleId;
        string name;
        string imageURL;
        string category;
        uint256 startTime;
        uint256 endTime;
        uint256 ticketPrice;
        uint256 prizeAmount;
        bool isCompleted;
        address winner;
        uint256 totalTicketsSold;
    }

    mapping(uint256 => Raffle) public raffles;
    uint256[] public raffleIds;

    // EVENTS
    event RaffleCreated(
        uint256 indexed raffleId,
        string name,
        uint256 prizeAmount,
        uint256 endTime
    );

    event TicketPurchased(
        uint256 indexed raffleId,
        address indexed buyer,
        uint256 quantity,
        uint256 totalCost
    );

    event WinnerDrawn(
        uint256 indexed raffleId,
        address indexed winner,
        uint256 prizeAmount
    );

    // NEW EVENT for ending raffle without tickets
    event RaffleEnded(
        uint256 indexed raffleId,
        string name,
        uint256 prizeAmountReturned
    );

    // MODIFIERS
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier raffleExists(uint256 _raffleId) {
        require(raffles[_raffleId].raffleId != 0, "Raffle does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
        nextRaffleId = 1;
    }

    function createRaffle(
        string memory _name,
        string memory _imageURL,
        string memory _category,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _ticketPrice,
        uint256 _prizeAmount
    ) external payable onlyAdmin {
        require(_startTime < _endTime, "Start time must be before end time");
        require(_ticketPrice > 0, "Ticket price must be greater than 0");
        require(_prizeAmount > 0, "Prize amount must be greater than 0");
        require(msg.value == _prizeAmount, "Must send exact prize amount to fund the raffle");

        uint256 currentRaffleId = nextRaffleId;
        raffles[currentRaffleId].raffleId = currentRaffleId;
        raffles[currentRaffleId].name = _name;
        raffles[currentRaffleId].imageURL = _imageURL;
        raffles[currentRaffleId].category = _category;
        raffles[currentRaffleId].startTime = _startTime;
        raffles[currentRaffleId].endTime = _endTime;
        raffles[currentRaffleId].ticketPrice = _ticketPrice;
        raffles[currentRaffleId].prizeAmount = _prizeAmount;
        
        raffleIds.push(currentRaffleId);
        nextRaffleId++;

        emit RaffleCreated(currentRaffleId, _name, _prizeAmount, _endTime);
    }

    function buyTickets(uint256 _raffleId, uint256 _quantity) external payable raffleExists(_raffleId) {
        Raffle storage raffle = raffles[_raffleId];
        require(block.timestamp >= raffle.startTime, "Raffle has not started yet");
        require(block.timestamp <= raffle.endTime, "Raffle has ended");
        require(!raffle.isCompleted, "Raffle is already completed");
        require(_quantity > 0 && _quantity <= 1000, "Quantity must be between 1 and 1000");

        uint256 totalCost = raffle.ticketPrice * _quantity;
        require(msg.value == totalCost, "Insufficient or incorrect ETH sent");

        for (uint i = 0; i < _quantity; i++) {
            raffle.participants.push(msg.sender);
        }
        
        raffle.ticketsBought[msg.sender] += _quantity;
        raffle.totalTicketsSold += _quantity;

        emit TicketPurchased(_raffleId, msg.sender, _quantity, totalCost);
    }

    function drawWinner(uint256 _raffleId) external onlyAdmin raffleExists(_raffleId) {
        Raffle storage raffle = raffles[_raffleId];
        require(block.timestamp >= raffle.endTime, "Raffle has not ended yet");
        require(!raffle.isCompleted, "Winner has already been selected");
        require(raffle.participants.length > 0, "No tickets were sold for this raffle");

        uint256 randomIndex = _generateRandomNumber(raffle.participants.length);
        address winningAddress = raffle.participants[randomIndex];
        raffle.winner = winningAddress;
        raffle.isCompleted = true;

        (bool successPrize, ) = payable(winningAddress).call{value: raffle.prizeAmount}("");
        require(successPrize, "Failed to transfer prize to winner");
        
        uint256 ticketRevenue = address(this).balance - raffle.prizeAmount;
        if (ticketRevenue > 0) {
            (bool successRevenue, ) = payable(admin).call{value: ticketRevenue}("");
            require(successRevenue, "Failed to transfer revenue to admin");
        }

        emit WinnerDrawn(_raffleId, winningAddress, raffle.prizeAmount);
    }

    /**
     * @dev NEW FUNCTION: Ends a raffle with no tickets sold and returns prize to admin
     */
    function endRaffle(uint256 _raffleId) external onlyAdmin raffleExists(_raffleId) {
        Raffle storage raffle = raffles[_raffleId];
        require(block.timestamp >= raffle.endTime, "Raffle has not ended yet");
        require(!raffle.isCompleted, "Raffle is already completed");
        require(raffle.participants.length == 0, "Cannot end raffle with sold tickets - use drawWinner instead");

        // Mark raffle as completed
        raffle.isCompleted = true;
        // No winner since no tickets were sold
        raffle.winner = address(0);

        // Return the prize amount to admin
        (bool success, ) = payable(admin).call{value: raffle.prizeAmount}("");
        require(success, "Failed to return prize to admin");

        emit RaffleEnded(_raffleId, raffle.name, raffle.prizeAmount);
    }

    function _generateRandomNumber(uint256 _upperBound) private view returns (uint256) {
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            _upperBound
        )));
        return randomSeed % _upperBound;
    }

    function getRaffle(uint256 _raffleId) external view raffleExists(_raffleId) returns (RaffleView memory) {
        Raffle storage r = raffles[_raffleId];
        return RaffleView(
            r.raffleId,
            r.name,
            r.imageURL,
            r.category,
            r.startTime,
            r.endTime,
            r.ticketPrice,
            r.prizeAmount,
            r.isCompleted,
            r.winner,
            r.totalTicketsSold
        );
    }

    function getAllRaffleIds() external view returns (uint256[] memory) {
        return raffleIds;
    }

    function getUserTicketCount(uint256 _raffleId, address _user) external view raffleExists(_raffleId) returns (uint256) {
        return raffles[_raffleId].ticketsBought[_user];
    }
}