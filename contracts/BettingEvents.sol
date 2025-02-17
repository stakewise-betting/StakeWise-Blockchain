// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BettingEvents {
    struct BetEvent {
        uint256 id;
        string name;
        string description;
        string imageURL;
        string[] options;
        uint256 startTime;
        uint256 endTime;
        bool isCompleted;
        string winningOption;
        uint256 prizePool;
        mapping(address => Bet) bets;
        address[] bettors;
    }

    struct Bet {
        string option;
        uint256 amount;
        bool exists;
    }

    mapping(uint256 => BetEvent) public events;
    uint256 public nextEventId;
    address public admin;

    event EventCreated(
        uint256 id,
        string name,
        uint256 startTime,
        uint256 endTime
    );
    event BetPlaced(
        uint256 eventId,
        address bettor,
        uint256 amount,
        string option
    );
    event WinnerDeclared(uint256 eventId, string winningOption);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier eventExists(uint256 _eventId) {
        require(_eventId < nextEventId, "Event does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function createEvent(
        string memory _name,
        string memory _description,
        string memory _imageURL,
        string[] memory _options,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyAdmin {
        require(_startTime < _endTime, "Start time must be before end time");
        require(
            _options.length > 1,
            "There must be at least two betting options"
        );

        BetEvent storage newEvent = events[nextEventId];
        newEvent.id = nextEventId;
        newEvent.name = _name;
        newEvent.description = _description;
        newEvent.imageURL = _imageURL;
        newEvent.options = _options;
        newEvent.startTime = _startTime;
        newEvent.endTime = _endTime;
        newEvent.isCompleted = false;
        newEvent.winningOption = "";
        newEvent.prizePool = 0;

        emit EventCreated(nextEventId, _name, _startTime, _endTime);
        nextEventId++;
    }

    function placeBet(
        uint256 _eventId,
        string memory _option
    ) external payable eventExists(_eventId) {
        BetEvent storage betEvent = events[_eventId];
        require(
            block.timestamp >= betEvent.startTime,
            "Event has not started yet"
        );
        require(block.timestamp <= betEvent.endTime, "Event has ended");
        require(msg.value > 0, "Bet amount must be greater than 0");

        bool validOption = false;
        for (uint256 i = 0; i < betEvent.options.length; i++) {
            if (
                keccak256(abi.encodePacked(betEvent.options[i])) ==
                keccak256(abi.encodePacked(_option))
            ) {
                validOption = true;
                break;
            }
        }
        require(validOption, "Invalid betting option");

        Bet storage userBet = betEvent.bets[msg.sender];
        require(!userBet.exists, "You have already placed a bet");

        userBet.option = _option;
        userBet.amount = msg.value;
        userBet.exists = true;
        betEvent.bettors.push(msg.sender);
        betEvent.prizePool += msg.value;

        emit BetPlaced(_eventId, msg.sender, msg.value, _option);
    }

    function declareWinner(
        uint256 _eventId,
        string memory _winningOption
    ) external onlyAdmin eventExists(_eventId) {
        BetEvent storage betEvent = events[_eventId];
        require(!betEvent.isCompleted, "Event already completed");
        require(block.timestamp >= betEvent.endTime, "Event not ended yet");

        bool validOption = false;
        for (uint256 i = 0; i < betEvent.options.length; i++) {
            if (
                keccak256(abi.encodePacked(betEvent.options[i])) ==
                keccak256(abi.encodePacked(_winningOption))
            ) {
                validOption = true;
                break;
            }
        }
        require(validOption, "Invalid option");

        betEvent.winningOption = _winningOption;
        betEvent.isCompleted = true;

        uint256 totalWinnersBetAmount = 0;
        address payable[] memory winnersPayable = new address payable[](
            betEvent.bettors.length
        );
        uint256 winnersCount = 0;

        for (uint256 i = 0; i < betEvent.bettors.length; i++) {
            address bettor = betEvent.bettors[i];
            if (
                keccak256(abi.encodePacked(betEvent.bets[bettor].option)) ==
                keccak256(abi.encodePacked(_winningOption))
            ) {
                totalWinnersBetAmount += betEvent.bets[bettor].amount;
                winnersPayable[winnersCount] = payable(bettor);
                winnersCount++;
            }
        }

        if (totalWinnersBetAmount > 0) {
            for (uint256 i = 0; i < winnersCount; i++) {
                address payable winner = winnersPayable[i];
                uint256 winnerReward = (betEvent.bets[winner].amount *
                    betEvent.prizePool) / totalWinnersBetAmount;
                winner.transfer(winnerReward);
            }
        }

        emit WinnerDeclared(_eventId, _winningOption);
    }

    function getEvent(
        uint256 _eventId
    )
        external
        view
        eventExists(_eventId)
        returns (
            uint256 id,
            string memory name,
            string memory description,
            string memory imageURL,
            string[] memory options,
            uint256 startTime,
            uint256 endTime,
            bool isCompleted,
            string memory winningOption,
            uint256 prizePool
        )
    {
        BetEvent storage betEvent = events[_eventId];
        return (
            betEvent.id,
            betEvent.name,
            betEvent.description,
            betEvent.imageURL,
            betEvent.options,
            betEvent.startTime,
            betEvent.endTime,
            betEvent.isCompleted,
            betEvent.winningOption,
            betEvent.prizePool
        );
    }

    function getEventOptions(
        uint256 _eventId
    ) external view eventExists(_eventId) returns (string[] memory) {
        return events[_eventId].options;
    }
}
