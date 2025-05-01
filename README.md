StakeWise-Blockchain/
├── build/ # Directory for compiled contract artifacts
│ └── contracts/ # Contains compiled JSON artifacts of contracts
│ └── BettingEvents.json # Compiled ABI and bytecode for the BettingEvents contract
├── contracts/ # Directory for Solidity smart contract source code
│ ├── .gitkeep # Placeholder file to ensure Git tracks the empty directory
│ └── BettingEvents.sol # The main Solidity smart contract for betting events
├── migrations/ # Directory for contract deployment scripts (Truffle/Hardhat convention)
│ ├── .gitkeep # Placeholder file to ensure Git tracks the empty directory
│ └── 2_deploy_betting.js # JavaScript deployment script for the betting contract(s)
├── test/ # Directory for smart contract test files
│ └── .gitkeep # Placeholder file to ensure Git tracks the empty directory
├── .gitattributes # Defines Git attributes for pathnames (e.g., line endings)
├── .gitignore # Specifies intentionally untracked files for Git
├── package-lock.json # Records exact dependency versions (npm)
├── package.json # Project metadata, dependencies, and scripts
└── truffle-config.js # Configuration file for the Truffle development framework
