// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RaffleDraw {
    struct Ticket {
        uint256 ticketId;
        address owner;
        bool exists;
    }

    // Create a struct for raffle parameters to avoid stack too deep error
    struct RaffleParams {
        string name;
        string description;
        string imageURL;
        uint256 startTime;
        uint256 endTime;
        uint256 ticketPrice;
        uint256 prizeAmount;
        string notificationImageURL;
        string notificationMessage;
    }

    // Split the RaffleData into core data and extra data to avoid stack issues
    struct RaffleCore {
        uint256 raffleId;
        string name;
        string description;
        string imageURL;
        uint256 startTime;
        uint256 endTime;
        uint256 ticketPrice; 
        uint256 prizeAmount;
    }
    
    struct RaffleExtra {
        bool isCompleted;
        address winner;
        uint256 totalTicketsSold;
        string notificationImageURL;
        string notificationMessage;
    }

    struct RaffleData {
        RaffleCore core;
        RaffleExtra extra;
        mapping(uint256 => Ticket) tickets;
        mapping(address => uint256[]) userTickets;
        address[] participants;
    }

    // Readable version of RaffleData for return
    struct RaffleDataView {
        uint256 raffleId;
        string name;
        string description;
        string imageURL;
        uint256 startTime;
        uint256 endTime;
        uint256 ticketPrice;
        uint256 prizeAmount;
        bool isCompleted;
        address winner;
        uint256 totalTicketsSold;
        string notificationImageURL;
        string notificationMessage;
    }

    mapping(uint256 => RaffleData) public raffles;
    uint256[] public raffleIds;
    uint256 public nextRaffleId = 1;
    address public admin;
    uint256 public totalAdminProfit;

    event RaffleCreated(
        uint256 raffleId,
        string name,
        uint256 startTime,
        uint256 endTime,
        uint256 ticketPrice,
        uint256 prizeAmount
    );

    event TicketPurchased(
        uint256 raffleId,
        address buyer,
        uint256 ticketId,
        uint256 amount
    );

    event WinnerSelected(
        uint256 raffleId,
        address winner,
        uint256 prizeAmount
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier raffleExists(uint256 _raffleId) {
        require(raffles[_raffleId].core.raffleId != 0, "Raffle does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
        totalAdminProfit = 0;
    }

    // Split the createRaffleDraw function into multiple helper functions to avoid stack depth issues
    function createRaffleDraw(
        uint256 _raffleId,
        RaffleParams calldata params
    ) external onlyAdmin {
        // Validate parameters
        _validateRaffleParams(_raffleId, params);
        
        // Create the raffle
        _createRaffle(_raffleId, params);
        
        // Emit the event
        emit RaffleCreated(
            _raffleId, 
            params.name, 
            params.startTime, 
            params.endTime, 
            params.ticketPrice, 
            params.prizeAmount
        );
        
        // Update nextRaffleId if necessary
        if (nextRaffleId <= _raffleId) {
            nextRaffleId = _raffleId + 1;
        }
    }
    
    // Validation function to reduce stack usage
    function _validateRaffleParams(uint256 _raffleId, RaffleParams calldata params) private view {
        require(params.startTime < params.endTime, "Start time must be before end time");
        require(params.ticketPrice > 0, "Ticket price must be greater than 0");
        require(params.prizeAmount > 0, "Prize amount must be greater than 0");
        require(raffles[_raffleId].core.raffleId == 0, "Raffle ID already exists");
    }
    
    // Create raffle function to reduce stack usage
    function _createRaffle(uint256 _raffleId, RaffleParams calldata params) private {
        raffleIds.push(_raffleId);
        
        RaffleData storage newRaffle = raffles[_raffleId];
        
        // Set core data
        newRaffle.core.raffleId = _raffleId;
        newRaffle.core.name = params.name;
        newRaffle.core.description = params.description;
        newRaffle.core.imageURL = params.imageURL;
        newRaffle.core.startTime = params.startTime;
        newRaffle.core.endTime = params.endTime;
        newRaffle.core.ticketPrice = params.ticketPrice;
        newRaffle.core.prizeAmount = params.prizeAmount;
        
        // Set extra data
        newRaffle.extra.isCompleted = false;
        newRaffle.extra.winner = address(0);
        newRaffle.extra.totalTicketsSold = 0;
        newRaffle.extra.notificationImageURL = params.notificationImageURL;
        newRaffle.extra.notificationMessage = params.notificationMessage;
    }

    function buyTicket(uint256 _raffleId, uint256 _quantity) external payable raffleExists(_raffleId) {
        RaffleData storage raffle = raffles[_raffleId];
        
        require(block.timestamp >= raffle.core.startTime, "Raffle has not started yet");
        require(block.timestamp <= raffle.core.endTime, "Raffle has ended");
        require(!raffle.extra.isCompleted, "Raffle is already completed");
        require(_quantity > 0, "Must purchase at least one ticket");
        
        uint256 totalPrice = raffle.core.ticketPrice * _quantity;
        require(msg.value >= totalPrice, "Insufficient funds sent");

        // Check if this is a new participant
        bool isNewParticipant = raffle.userTickets[msg.sender].length == 0;
        
        // Process ticket purchases - use a helper function to reduce stack usage
        _processPurchase(_raffleId, _quantity, raffle, isNewParticipant);
        
        // Refund excess payment if any
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }
    
    // Helper function to process ticket purchases
    function _processPurchase(
        uint256 _raffleId, 
        uint256 _quantity, 
        RaffleData storage raffle, 
        bool isNewParticipant
    ) private {
        for (uint256 i = 0; i < _quantity; i++) {
            uint256 ticketId = raffle.extra.totalTicketsSold + 1;
            
            Ticket storage newTicket = raffle.tickets[ticketId];
            newTicket.ticketId = ticketId;
            newTicket.owner = msg.sender;
            newTicket.exists = true;
            
            raffle.userTickets[msg.sender].push(ticketId);
            raffle.extra.totalTicketsSold++;
            
            emit TicketPurchased(_raffleId, msg.sender, ticketId, raffle.core.ticketPrice);
        }
        
        // Add participant to list if new
        if (isNewParticipant) {
            raffle.participants.push(msg.sender);
        }
    }

    function selectWinner(uint256 _raffleId) external raffleExists(_raffleId) {
        RaffleData storage raffle = raffles[_raffleId];
        
        require(block.timestamp >= raffle.core.endTime, "Raffle has not ended yet");
        require(!raffle.extra.isCompleted, "Winner already selected");
        require(raffle.extra.totalTicketsSold > 0, "No tickets sold");

        // Use helper functions to reduce stack usage
        address winnerAddress = _selectRandomWinner(raffle, _raffleId);
        _distributeRewards(raffle, winnerAddress);
        
        emit WinnerSelected(_raffleId, winnerAddress, raffle.core.prizeAmount);
    }
    
    // Helper function to select random winner
    function _selectRandomWinner(RaffleData storage raffle, uint256 _raffleId) private view returns (address) {
        // Generate a pseudo-random number for winner selection
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            raffle.extra.totalTicketsSold,
            _raffleId
        )));
        
        uint256 winningTicketId = (randomSeed % raffle.extra.totalTicketsSold) + 1;
        
        // Get the winner from the winning ticket
        return raffle.tickets[winningTicketId].owner;
    }
    
    // Helper function to distribute rewards
    function _distributeRewards(RaffleData storage raffle, address winnerAddress) private {
        // Update raffle data
        raffle.extra.isCompleted = true;
        raffle.extra.winner = winnerAddress;
        
        // Calculate admin fee (5%)
        uint256 totalFunds = raffle.extra.totalTicketsSold * raffle.core.ticketPrice;
        uint256 adminFee = (totalFunds * 5) / 100;
        uint256 prizeToDistribute = totalFunds - adminFee;
        
        // Update admin profit
        totalAdminProfit += adminFee;
        
        // Transfer prize to winner
        payable(winnerAddress).transfer(prizeToDistribute);
        
        // Transfer admin fee
        payable(admin).transfer(adminFee);
    }

    // Get all raffle IDs
    function getAllRaffleIds() public view returns (uint256[] memory) {
        return raffleIds;
    }

    // Get raffle details by ID
    function getRaffle(uint256 _raffleId) external view raffleExists(_raffleId) returns (RaffleDataView memory) {
        RaffleData storage raffle = raffles[_raffleId];
        
        return RaffleDataView(
            raffle.core.raffleId,
            raffle.core.name,
            raffle.core.description,
            raffle.core.imageURL,
            raffle.core.startTime,
            raffle.core.endTime,
            raffle.core.ticketPrice,
            raffle.core.prizeAmount,
            raffle.extra.isCompleted,
            raffle.extra.winner,
            raffle.extra.totalTicketsSold,
            raffle.extra.notificationImageURL,
            raffle.extra.notificationMessage
        );
    }

    // Get user's tickets for a specific raffle
    function getUserTickets(uint256 _raffleId, address _user) external view raffleExists(_raffleId) returns (uint256[] memory) {
        return raffles[_raffleId].userTickets[_user];
    }

    // Get total number of tickets sold for a raffle
    function getTotalTicketsSold(uint256 _raffleId) external view raffleExists(_raffleId) returns (uint256) {
        return raffles[_raffleId].extra.totalTicketsSold;
    }

    // Check if a user has won a raffle
    function hasUserWon(uint256 _raffleId, address _user) external view raffleExists(_raffleId) returns (bool) {
        RaffleData storage raffle = raffles[_raffleId];
        return raffle.extra.isCompleted && raffle.extra.winner == _user;
    }

    // Get admin profit
    function getTotalAdminProfit() external view returns (uint256) {
        return totalAdminProfit;
    }

    // Get active raffles (not ended or completed)
    function getActiveRaffles() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        // Count active raffles
        for (uint256 i = 0; i < raffleIds.length; i++) {
            uint256 raffleId = raffleIds[i];
            RaffleData storage raffle = raffles[raffleId];
            
            if (!raffle.extra.isCompleted && block.timestamp <= raffle.core.endTime) {
                activeCount++;
            }
        }
        
        // Create array of active raffle IDs
        uint256[] memory activeRaffleIds = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < raffleIds.length; i++) {
            uint256 raffleId = raffleIds[i];
            RaffleData storage raffle = raffles[raffleId];
            
            if (!raffle.extra.isCompleted && block.timestamp <= raffle.core.endTime) {
                activeRaffleIds[index] = raffleId;
                index++;
            }
        }
        
        return activeRaffleIds;
    }
    
    // Check if a raffle should select a winner (has ended but winner not selected)
    function raffleReadyForWinnerSelection(uint256 _raffleId) external view raffleExists(_raffleId) returns (bool) {
        RaffleData storage raffle = raffles[_raffleId];
        return block.timestamp >= raffle.core.endTime && !raffle.extra.isCompleted && raffle.extra.totalTicketsSold > 0;
    }
}