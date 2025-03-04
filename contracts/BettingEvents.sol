// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BettingEvents {
    struct BetEvent {
        uint256 eventId; // Renamed 'id' to 'eventId'
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
        string notificationMessage;
        mapping(string => uint256) optionBetCounts; // Track bet counts per option
    }

    struct Bet {
        string option;
        uint256 amount;
        bool exists;
    }

    struct OptionOdds {
        string optionName;
        uint256 oddsPercentage;
    }

    mapping(uint256 => BetEvent) public events;
    uint256 public nextEventId;
    address public admin;

    event EventCreated(
        uint256 eventId, // Event emits eventId, not id
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
        require(events[_eventId].eventId != 0, "Event does not exist"); // Check eventId instead of id
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function createEvent(
        uint256 _eventId, // ADDED _eventId parameter - VERY IMPORTANT
        string memory _name,
        string memory _description,
        string memory _imageURL,
        string[] memory _options,
        uint256 _startTime,
        uint256 _endTime,
        string memory _notificationMessage
    ) external onlyAdmin {
        require(_startTime < _endTime, "Start time must be before end time");
        require(
            _options.length > 1,
            "There must be at least two betting options"
        );
        require(events[_eventId].eventId == 0, "Event ID already exists"); // Ensure eventId is not already used

        BetEvent storage newEvent = events[_eventId];
        newEvent.eventId = _eventId; // Use _eventId provided from frontend - VERY IMPORTANT
        newEvent.name = _name;
        newEvent.description = _description;
        newEvent.imageURL = _imageURL;
        newEvent.options = _options;
        newEvent.startTime = _startTime;
        newEvent.endTime = _endTime;
        newEvent.isCompleted = false;
        newEvent.winningOption = "";
        newEvent.prizePool = 0;
        newEvent.notificationMessage = _notificationMessage;

        emit EventCreated(_eventId, _name, _startTime, _endTime); // Emit eventId - VERY IMPORTANT
        nextEventId++; // Increment nextEventId AFTER using current value
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
        betEvent.optionBetCounts[_option]++; // Increment bet count for the option

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
            uint256 eventId, // Returns eventId, not id
            string memory name,
            string memory description,
            string memory imageURL,
            string[] memory options,
            uint256 startTime,
            uint256 endTime,
            bool isCompleted,
            string memory winningOption,
            uint256 prizePool,
            string memory notificationMessage
        )
    {
        BetEvent storage betEvent = events[_eventId];
        return (
            betEvent.eventId, // Returns betEvent.eventId
            betEvent.name,
            betEvent.description,
            betEvent.imageURL,
            betEvent.options,
            betEvent.startTime,
            betEvent.endTime,
            betEvent.isCompleted,
            betEvent.winningOption,
            betEvent.prizePool,
            betEvent.notificationMessage
        );
    }

    function getEventOptions(
        uint256 _eventId
    ) external view eventExists(_eventId) returns (string[] memory) {
        return events[_eventId].options;
    }

    function getEventPrizePool(
        uint256 _eventId
    ) external view eventExists(_eventId) returns (uint256) {
        return events[_eventId].prizePool;
    }

    function getEventOdds(
        uint256 _eventId
    ) external view eventExists(_eventId) returns (OptionOdds[] memory) {
        BetEvent storage betEvent = events[_eventId];
        uint256 totalBets = betEvent.bettors.length;
        OptionOdds[] memory optionOddsArray = new OptionOdds[](
            betEvent.options.length
        );

        if (totalBets == 0) {
            for (uint256 i = 0; i < betEvent.options.length; i++) {
                optionOddsArray[i] = OptionOdds({
                    optionName: betEvent.options[i],
                    oddsPercentage: 0
                }); // Default to 0% if no bets yet
            }
            return optionOddsArray;
        }

        for (uint256 i = 0; i < betEvent.options.length; i++) {
            string memory option = betEvent.options[i];
            uint256 betCount = betEvent.optionBetCounts[option];
            optionOddsArray[i] = OptionOdds({
                optionName: option,
                oddsPercentage: (betCount * 100) / totalBets // Percentage of bets for each option
            });
        }
        return optionOddsArray;
    }
}
