pragma solidity 0.4.20;


contract ERC20Interface {
    function transfer(address to, uint256 value) public returns (bool);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function balanceOf(address who) public view returns (uint256);
}


/* 1. Contract is initiated by storing sender as OWNER and with three arguments:
 * deadline : block.number which is also stored as DEADLINE
 * wallet : address which is also stored as WALLET
 * manager : address which is also stored as MANAGER. */
/* Only MANAGER is eglible to perform core functions like authorizing participants as confirmed investors */
/* and withdrawing their money as Token sale funds. */
contract TokenSaleQueue {
    using SafeMath for uint256;

    // owner data
    address public owner;
    address public potentialOwner;

    event NewOwner(address old, address current);
    event NewPotentialOwner(address old, address potential);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function setNewOwner(address _newOwner) public onlyOwner {
        require(_newOwner != address(0));

        potentialOwner = _newOwner;
        NewPotentialOwner(owner, _newOwner);
    }

    function confirmOwnership() public {
        require(msg.sender == potentialOwner);

        owner = potentialOwner;
        potentialOwner = address(0);
        NewOwner(owner, potentialOwner);
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getPotentialOwner() public view returns (address) {
        return potentialOwner;
    }

    /* 2. Contract has internal mapping DEPOSITS : Address -> (balance: uint, authorized: bool) */
    /* representing balance of everyone whoever used deposit method */
    /* This is where balances of all participants stored. */
    /* Additional flag of whether the participant is authorized investor is stored. */
    /* This flag determines if the participant funds can be further processed by the contract manager (see 5., 6.) */
    struct Record {
        bool inList;
        bool authorized;
    }

    uint256 public monthInBlocks = 183000;

    mapping(address => uint) public deposits;
    address public wallet;
    address public manager;
    uint256 public deadline; /* blocks */

    function balanceOf(address who) public view returns (uint256 balance) {
        return deposits[who];
    }

    function isAuthorized(address who) public view returns (bool authorized) {
        return whitelist[who].authorized;
    }

    function getWallet() public view returns (address) {
        return wallet;
    }

    function getDeadline() public view returns (uint256) {
        return deadline;
    }

    function getManager() public view returns (address) {
        return manager;
    }

    event LogWhitelist(address who);
    event LogDeposit(address who, uint256 amount);
    event LogWithdrawal(address who);
    event LogAuthorized(address who);
    event LogProcess(address who);
    event LogRetrieveUnclaimedFunds(address who);


    function TokenSaleQueue(address _wallet, address _manager, uint256 _deadline) public {
        owner = msg.sender;
        wallet = _wallet;
        manager = _manager;
        deadline = _deadline;
    }
    
    modifier onlyManager() {
        require(msg.sender == manager);
        _;
    }

    function setNewManager(address _newManager) public onlyOwner {
        require(_newManager != address(0));

        manager = _newManager;
    }

    function setNewWallet(address _newWallet) public onlyOwner {
        require(_newWallet != address(0));

        wallet = _newWallet;
    }

    /* Contract has map whitelist with address argument */
    mapping(address => Record) public whitelist;

    /* Manager adds user in white list - operation that allows to use deposit function */
    /* Contract checks if sender is equal to manager */
    function addAddressInWhitelist(address who) public onlyManager {
        require(who != address(0));
        whitelist[who].inList = true;
        LogWhitelist(who);
    }

    function isInWhiteList(address who) public view returns (bool result) {
        return whitelist[who].inList;
    }

    /* 3. Contract has payable method deposit */
    /* This is how participant puts his funds in the queue for further processing. */
    /* Participant can later withdraw his funds unless they are processed by the contract owner (6.) */
    function deposit() public payable {
        /* Contract checks that method invocation attaches non-zero value. */
        require(msg.value > 0);

        /* Contract checks that user in whitelist */
        require(whitelist[msg.sender].inList);

        /* Contract checks that `DEADLINE` is not reached. If it is reached, it returns all funds to `sender` */
        require(block.number <= deadline);

        /* Contract adds value sent to the corresponding mapping stored in DEPOSIT using sender as a key */
        deposits[msg.sender] = deposits[msg.sender].add(msg.value);
        LogDeposit(msg.sender, msg.value);
    }

    /* 4. Contract has method withdraw without amount argument */
    /* Ability to withdraw funds for participant which he earlier had put in the contract using deposit function (1.) */
    function withdraw() public {
        /* Contract checks that balance of the sender in DEPOSITS mapping is equal amount */
        require(deposits[msg.sender] > 0);

        uint256 balance = deposits[msg.sender];
        /* Contract sets the amount in corresponding record in DEPOSITS mapping to zero */
        deposits[msg.sender] = 0;

        /* Contract transfers amount to the sender from it's own balance */
        msg.sender.transfer(balance);
        LogWithdrawal(msg.sender);
    }

    /* 5. Contract has method authorize with address argument */
    /* Manager authorizes particular participant - operation that allows to use participant money in Token Sale */
    function authorize(address who) public onlyManager {
        /* Contract checks if sender is equal to manager */
        require(who != address(0));

        Record storage record = whitelist[who];

        /* Contract updates value in whitelist mapping using address as the key and sets authorized = true */
        record.authorized = true;
        LogAuthorized(who);
    }

    /* 6. Contract has method process */
    /* Sender does final confirmation that his money will be used in the Token Sale */
    function process() public {
        Record storage record = whitelist[msg.sender];

        /* Contract checks if value of DEPOSITS with sender key has non-zero balance and authorized is set true */
        require(record.authorized);
        require(deposits[msg.sender] > 0);

        uint256 balance = deposits[msg.sender];
        /* Contract sets balance of the sender entry to zero in the DEPOSITS */
        deposits[msg.sender] = 0;

        require(wallet != address(0));
        /* Contract transfers balance to the WALLET */
        wallet.transfer(balance);

        LogProcess(msg.sender);
    }

    /* 7. Contract has method retrieveUnclaimedFunds with address argument */
    /* Owner can force contract to return participant funds back to the participants when the DEADLINE is reached */
    function retrieveUnclaimedFunds(address who) public onlyOwner {
        /* Contract checks if sender is OWNER */
        require(who != address(0));
        /* Contract checks if current timestamp is later than DEADLINE */
        require(block.number > deadline);

        /* Contract checks if RECORD has non-zero balance */
        require(deposits[msg.sender] > 0);

        uint256 balance = deposits[msg.sender];
        /* Contract sets balance of RECORD to zero */
        deposits[msg.sender] = 0;
        /* Contract sends funds from it's own balance to owner */
        owner.transfer(balance);

        LogRetrieveUnclaimedFunds(who);
    }

    /* Contract has internal mapping token DEPOSITS : Address -> (balance: uint, authorized: bool) */
    /* representing token balance of everyone whoever used deposit method */
    /* This is where token balances of all participants stored. */
    /* Additional flag of whether the participant is authorized investor is stored. */
    /* This flag determines if the participant tokens can be further processed by the contract manager (see 11, 12) */
    mapping(address => mapping(address => uint256)) public tokenDeposits;

    /* White list of tokens */
    mapping(address => bool) public tokenWalletsWhitelist;

    function addTokenWalletInWhitelist(address tokenWallet) public onlyManager {
        require(tokenWallet != address(0));
        tokenWalletsWhitelist[tokenWallet] = true;
        LogTokenWhitelist(tokenWallet);
    }

    function tokenInWhiteList(address tokenWallet) public view returns (bool result) {
        return tokenWalletsWhitelist[tokenWallet];
    }

    function tokenBalanceOf(address tokenWallet, address who) public view returns (uint256 balance) {
        return tokenDeposits[tokenWallet][who];
    }

    event LogTokenWhitelist(address tokenWallet);
    event LogTokenDeposit(address tokenWallet, address who, uint256 amount);
    event LogTokenWithdrawal(address tokenWallet, address who);
    event LogTokenProcess(address tokenWallet, address who);
    event LogTokenRetrieveUnclaimedFunds(address tokenWallet, address who);

    /* 9. Contract has method token deposit */
    /* This is how participant puts his funds in the queue for further processing. */
    /* Participant can later withdraw his token unless they are processed by the conract owner (12.) */
    function tokenDeposit(address tokenWallet, uint256 amount) public {
        /* Contract checks that method invocation attaches non-zero value. */
        require(amount > 0);

        /* Contract checks that token wallet in whitelist */
        require(tokenWalletsWhitelist[tokenWallet]);

        /* Contract checks that user in whitelist */
        require(whitelist[msg.sender].inList);

        /* Contract checks that `DEADLINE` is not reached. */
        require(block.number <= deadline);

        /* msg.sender initiate transferFrom function from ERC20 contract */
        ERC20Interface token = ERC20Interface(tokenWallet);
        require(token.transferFrom(msg.sender, this, amount));

        /* Contract adds value sent to the corresponding mapping stored in token DEPOSIT using sender as a key */
        tokenDeposits[tokenWallet][msg.sender] = tokenDeposits[tokenWallet][msg.sender].add(amount);
        LogTokenDeposit(tokenWallet, msg.sender, amount);
    }

    /* 10. Contract has method token withdraw without amount argument */
    /* Ability to withdraw funds for participant which he earlier had put in the contract using deposit function (9.) */
    function tokenWithdraw(address tokenWallet) public {
        /* Contract checks that balance of the sender in token DEPOSITS mapping is equal amount */
        require(tokenDeposits[tokenWallet][msg.sender] > 0);

        uint256 balance = tokenDeposits[tokenWallet][msg.sender];
        /* Contract sets the amount in corresponding record in DEPOSITS mapping to zero */
        tokenDeposits[tokenWallet][msg.sender] = 0;

        /* Contract transfers amount to the sender from it's own balance */
        ERC20Interface token = ERC20Interface(tokenWallet);
        require(token.transfer(msg.sender, balance));

        LogTokenWithdrawal(tokenWallet, msg.sender);
    }

    /* 12. Contract has method token process */
    /* Sender does final confirmation that his tokens will be used in the Token Sale */
    function tokenProcess(address tokenWallet) public {
        /* Contract checks if value of token DEPOSITS with sender key has non-zero balance and authorized is set true */
        require(whitelist[msg.sender].authorized);
        require(tokenDeposits[tokenWallet][msg.sender] > 0);

        uint256 balance = tokenDeposits[tokenWallet][msg.sender];
        /* Contract sets balance of the sender entry to zero in the DEPOSITS */
        tokenDeposits[tokenWallet][msg.sender] = 0;

        require(wallet != address(0));
        /* Contract transfers tokens to the WALLET */
        ERC20Interface token = ERC20Interface(tokenWallet);
        require(token.transfer(wallet, balance));

        LogTokenProcess(tokenWallet, msg.sender);
    }

    /* 13. Contract has method refund with address argument */
    /* Owner can force contract to return participant funds back to the participants when the DEADLINE is reached */
    function tokenRetrieveUnclaimedFunds(address tokenWallet, address who) public onlyOwner {
        require(who != address(0));

        /* Contract checks if current timestamp is later than DEADLINE */
        require(block.number > deadline);

        /* Contract picks the record in token DEPOSIT mapping with key equal to address argument (RECORD) */
        /* Contract checks if RECORD has non-zero balance */
        require(tokenDeposits[tokenWallet][who] > 0);

        uint256 balance = tokenDeposits[tokenWallet][who];
        /* Contract sets balance of RECORD to zero */
        tokenDeposits[tokenWallet][who] = 0;

        /* Contract transfers tokens to the WALLET */
        ERC20Interface token = ERC20Interface(tokenWallet);
        require(token.transfer(owner, balance));

        LogTokenRetrieveUnclaimedFunds(tokenWallet, who);
    }

    function destroyAndSend(address recipient, address[] tokens) public onlyOwner {
        require(recipient != address(0));
        require(block.number > deadline + monthInBlocks);

        // Transfer tokens to recipient
        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20Interface token = ERC20Interface(tokens[i]);
            uint256 balance = token.balanceOf(this);
            token.transfer(recipient, balance);
        }

        // Transfer Eth to recipient and terminate contract
        selfdestruct(recipient);
    }

    //for test only
    function changeDeadline(uint256 _deadline) public onlyOwner {
        deadline = _deadline;
    }

    //for test only
    function changeMonthInBlocks(uint256 _monthInBlocks) public onlyOwner {
        monthInBlocks = _monthInBlocks;
    }
    
    //for test only
    function changeWallet(address _wallet) public onlyOwner {
        wallet = _wallet;
    }
}


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}
