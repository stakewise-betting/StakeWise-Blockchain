pragma solidity ^0.8.0;

contract Betting {
    // Enum for the betting options
    enum Option {
        OptionA,
        OptionB
    }

    // Structure to store bet information
    struct Bet {
        address user;
        Option option;
        uint256 amount;
    }

    // Variables to store the bets for each option
    Bet[] public betsA;
    Bet[] public betsB;

    // Mapping of user addresses to their deposited amounts (redundant, but useful for some calculations)
    mapping(address => uint256) public balances;

    // Total pool size
    uint256 public totalPoolSize;

    // Owner of the contract
    address public owner;

    // Winning option (initially none)
    Option public winningOption;

    // Whether the winner has been set
    bool public winnerSet;

    // Event emitted when a bet is placed
    event BetPlaced(address indexed user, Option option, uint256 amount);

    // Event emitted when the winner is set and payouts are made
    event WinnerSet(Option winningOption);
    event Payout(address indexed user, uint256 amount);

    constructor() {
        owner = msg.sender;
        winningOption = Option.OptionA; // Set default to A, just for init
        winnerSet = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    modifier winnerNotSet() {
        require(!winnerSet, "Winner already set.");
        _;
    }

    function placeBet(Option _option) public payable {
        require(msg.value > 0, "Bet amount must be greater than zero.");

        Bet memory newBet = Bet({
            user: msg.sender,
            option: _option,
            amount: msg.value
        });

        if (_option == Option.OptionA) {
            betsA.push(newBet);
        } else {
            betsB.push(newBet);
        }

        balances[msg.sender] += msg.value;
        totalPoolSize += msg.value;

        emit BetPlaced(msg.sender, _option, msg.value);
    }

    function setWinningOption(
        Option _winningOption
    ) public onlyOwner winnerNotSet {
        winningOption = _winningOption;
        winnerSet = true;

        // Payout to winners
        payoutWinners();

        emit WinnerSet(_winningOption);
    }

    function payoutWinners() private {
        require(winnerSet, "Winner not yet set.");

        Bet[] memory winningBets;

        if (winningOption == Option.OptionA) {
            winningBets = betsA;
        } else {
            winningBets = betsB;
        }

        uint256 totalWinningBetsAmount = 0;
        for (uint256 i = 0; i < winningBets.length; i++) {
            totalWinningBetsAmount += winningBets[i].amount;
        }

        // Avoid division by zero
        if (totalWinningBetsAmount == 0) {
            return; // No winners, nothing to payout.  Consider refunding losers here.
        }

        for (uint256 i = 0; i < winningBets.length; i++) {
            Bet memory bet = winningBets[i];
            uint256 payoutAmount = (bet.amount * totalPoolSize) /
                totalWinningBetsAmount; // Proportional payout

            (bool success, ) = bet.user.call{value: payoutAmount}("");
            require(success, "Payout failed.");
            emit Payout(bet.user, payoutAmount);
            totalPoolSize -= payoutAmount; // Reduce the total pool.
        }

        // Optional: Refund losers if needed, depending on your requirements.
    }

    // Optional function to allow the owner to withdraw any remaining contract balance.
    function ownerWithdraw() public onlyOwner {
        require(totalPoolSize == 0, "All pool amount not distributed");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Withdrawal failed.");
    }

    receive() external payable {}
}
