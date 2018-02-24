pragma solidity 0.4.20;

contract ERC20Interface {
    function transfer(address to, uint256 value) public returns (bool);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
}

/* 1. Contract is initiated by storing sender as OWNER and with two arguments deadline : timestamp which is also stored as DEADLINE and wallet : address which is also stored as WALLET. */
/* Only owner is eglible to perform core functions like authorizing participants as confirmed investors and withdrawing their money as Token sale funds. */
contract TokenSaleQueue {
    using SafeMath for uint256;

    address public owner;
    address public potentialOwner;

    event NewOwner(address old, address current);
    event NewPotentialOwner(address old, address potential);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function setNewOwner(address _new) public onlyOwner {
        require(_new != address(0));

        potentialOwner = _new;
        NewPotentialOwner(owner, _new);
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

    /* 2. Contract has internal mapping DEPOSITS : Address -> (balance: uint, authorized: bool) representing balance of everyone whoever used deposit method */
    /* This is where balances of all participants stored. Additional flag of whether the participant is authorized investor is stored. This flag determines if the participant funds can be further processed by the contract manager (see 5., 6.) */
    struct Record {
        uint256 balance;
        bool authorized;
    }

    mapping(address => Record) public deposits;
    address public wallet;
    address public manager;
    uint256 public deadline; /* blocks */

    function balanceOf(address who) public view returns (uint256 balance) {
        return deposits[who].balance;
    }

    function isAuthorized(address who) public view returns (bool authorized) {
        return deposits[who].authorized;
    }

    function getWallet() public view returns (address) {
        return wallet;
    }

    function getDeadline() public view returns (uint) {
        return deadline;
    }

    function getManager() public view returns (address) {
        return manager;
    }

    event Deposit(address who, uint256 amount);
    event Withdrawal(address who);
    event Authorized(address who);
    event Process(address who);
    event Refund(address who);

    function TokenSaleQueue(address _wallet, address _manager,  uint _deadline) public {
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

    mapping (address => bool) whitelistUsers;

    function addUsersInWhitelist (address user) public onlyOwner {
        require(user != address(0));
        whitelistUsers[user] = true;
    }

    function userInWhiteList(address user) public view returns (bool result) {
        return whitelistUsers[user];
    }

    /* 3. Contract has payable method deposit */
    /* This is how participant puts his funds in the queue for further processing. Participant can later withdraw his funds unless they are processed by the contract owner (6.) */
    function deposit() public payable {
        /* Contract checks that method invocation attaches non-zero value. */
        require(msg.value > 0);

        /* Contract checks that user in whitelist */
        require(whitelistUsers[msg.sender]);

        /* Contract checks that `DEADLINE` is not reached. If it is reached, it returns all funds to `sender` */
        require(block.number <= deadline);

        /* Contract adds value sent to the corresponding mapping stored in DEPOSIT using sender as a key */
        deposits[msg.sender].balance = deposits[msg.sender].balance.add(msg.value);
        Deposit(msg.sender, msg.value);
    }

    /* 4. Contract has method withdraw without amount argument */
    /* Ability to withdraw funds for participant which he earlier had put in the contract using deposit function (1.) */
    function withdraw() public {
        /* Contract checks that balance of the sender in DEPOSITS mapping is equal amount */
        Record storage record = deposits[msg.sender];
        require(record.balance > 0);

        uint256 balance = record.balance;
        /* Contract sets the amount in corresponding record in DEPOSITS mapping to zero */
        record.balance = 0;

        /* Contract transfers amount to the sender from it's own balance */
        msg.sender.transfer(balance);
        Withdrawal(msg.sender);
    }

    /* 5. Contract has method authorize with address argument */
    /* Manager authorizes particular participant - operation that allows to use participant money in Token Sale */
    function authorize(address who) onlyManager public {
        /* Contract checks if sender is equal to manager */
        require(who != address(0));

        Record storage record = deposits[who];
        require(record.balance > 0);

        /* Contract updates corresponding value in DEPOSITS mapping using address as the key and sets authorized = true */
        record.authorized = true;
        Authorized(who);
    }

    /* 6. Contract has method process */
    /* Sender does final confirmation that his money will be used in the Token Sale */
    function process() public {
        Record storage record = deposits[msg.sender];

        /* Contract checks if value of DEPOSITS with sender key has non-zero balance and authorized is set true */
        require(record.balance > 0);
        require(record.authorized);

        uint256 balance = record.balance;
        /* Contract sets balance of the sender entry to zero in the DEPOSITS */
        record.balance = 0;

        /* Contract transfers balance to the WALLET */
        wallet.transfer(balance);

        Process(msg.sender);
    }

    /* 7. Contract has method refund with address argument */
    /* Owner can force contract to return participant funds back to the participants when the DEADLINE is reached */
    function refund(address who) public onlyOwner {
        /* Contract checks if sender is OWNER */
        require(who != address(0));
        /* Contract checks if current timestamp is later than DEADLINE */
        require(block.number > deadline);

        /* Contract picks the record in DEPOSIT mapping with key equal to address argument (RECORD) */
        Record storage record = deposits[who];
        /* Contract checks if RECORD has non-zero balance */
        require(record.balance > 0);

        uint256 balance = record.balance;
        /* Contract sets balance of RECORD to zero */
        record.balance = 0;
        /* Contract sends funds from it's own balance to owner */
        owner.transfer(balance);

        Refund(who);
    }

    function destroyAndSend(address _recipient) public onlyOwner {
        /* Contract checks if current timestamp is later than DEADLINE + 183000 (~ 1 month)*/
        require(block.number > deadline + 183000);

        selfdestruct(_recipient);
    }

    /* Contract has internal mapping token DEPOSITS : Address -> (balance: uint, authorized: bool) representing token balance of everyone whoever used deposit method */
    /* This is where token balances of all participants stored. Additional flag of whether the participant is authorized investor is stored. This flag determines if the participant tokens can be further processed by the contract manager (see 11, 12) */
    mapping(address => mapping(address => Record)) public tokenDeposits;

    /* White list of tokens */
    mapping (address => bool) public whitelistTokenWallets;

    function addTokensInWhitelist (address tokenWallet) public onlyOwner {
        require(tokenWallet != address(0));
        whitelistTokenWallets[tokenWallet] = true;
    }

    function tokenInWhiteList(address tokenWallet) public view returns (bool result) {
        return whitelistTokenWallets[tokenWallet];
    }

    function tokenBalanceOf(address tokenWallet, address who) public view returns (uint256 balance) {
        return tokenDeposits[tokenWallet][who].balance;
    }

    function tokenIsAuthorized(address tokenWallet, address who) public view returns (bool authorized) {
        return tokenDeposits[tokenWallet][who].authorized;
    }

    event TokenDeposit(address tokenWallet, address who, uint256 amount);
    event TokenWithdrawal(address tokenWallet, address who);
    event TokenAuthorized(address tokenWallet, address who);
    event TokenProcess(address tokenWallet, address who);
    event TokenRefund(address tokenWallet, address who);

    /* 9. Contract has method token deposit */
    /* This is how participant puts his funds in the queue for further processing. Participant can later withdraw his token unless they are processed by the conract owner (12.) */
    function tokenDeposit(address tokenWallet, uint amount) public {
        /* Contract checks that method invocation attaches non-zero value. */
        require(amount > 0);

        /* Contract checks that user in whitelist */
        require(whitelistUsers[msg.sender]);

        /* Contract checks that token in whitelist */
        require(whitelistTokenWallets[tokenWallet]);

        /* Contract checks that `DEADLINE` is not reached. */
        require(block.number <= deadline);

        /* msg.sender initiate transferFrom function from ERC20 contract */
        ERC20Interface ERC20Token = ERC20Interface(tokenWallet);
        require(ERC20Token.transferFrom(msg.sender, this, amount));

        /* Contract adds value sent to the corresponding mapping stored in token DEPOSIT using sender as a key */
        tokenDeposits[tokenWallet][msg.sender].balance = tokenDeposits[tokenWallet][msg.sender].balance.add(amount);
        TokenDeposit(tokenWallet, msg.sender, amount);
    }

    /* 10. Contract has method token withdraw without amount argument */
    /* Ability to withdraw funds for participant which he earlier had put in the contract using deposit function (9.) */
    function tokenWithdraw(address tokenWallet) public {
        /* Contract checks that balance of the sender in token DEPOSITS mapping is equal amount */
        Record storage record = tokenDeposits[tokenWallet][msg.sender];
        require(record.balance > 0);

        uint256 balance = record.balance;
        /* Contract sets the amount in corresponding record in DEPOSITS mapping to zero */
        record.balance = 0;

        /* Contract transfers amount to the sender from it's own balance */
        ERC20Interface ERC20Token = ERC20Interface(tokenWallet);
        require(ERC20Token.transfer(msg.sender, balance));

        TokenWithdrawal(tokenWallet, msg.sender);
    }

    /* 11. Contract has method token authorize with address argument */
    /* Manager authorizes particular participant - operation that allows to use participant tokens in Token Sale */
    function tokenAuthorize(address tokenWallet, address who) onlyManager public {
        require(who != address(0));

        Record storage record = tokenDeposits[tokenWallet][who];
        require(record.balance > 0);

        /* Contract updates corresponding value in token DEPOSITS mapping using address as the key and sets authorized = true */
        record.authorized = true;
        TokenAuthorized(tokenWallet, who);
    }

    /* 12. Contract has method token process */
    /* Sender does final confirmation that his tokens will be used in the Token Sale */
    function tokenProcess(address tokenWallet) public {
        Record storage record = tokenDeposits[tokenWallet][msg.sender];

        /* Contract checks if value of DEPOSITS with sender key has non-zero balance and authorized is set true */
        require(record.balance > 0);
        require(record.authorized);

        uint256 balance = record.balance;
        /* Contract sets balance of the sender entry to zero in the DEPOSITS */
        record.balance = 0;

        /* Contract transfers tokens to the WALLET */
        ERC20Interface ERC20Token = ERC20Interface(tokenWallet);
        require(ERC20Token.transfer(wallet, balance));

        TokenProcess(tokenWallet, msg.sender);
    }

    /* 13. Contract has method refund with address argument */
    /* Owner can force contract to return participant funds back to the participants when the DEADLINE is reached */
    function tokenRefund(address tokenWallet, address who) public onlyOwner {
        require(who != address(0));

        /* Contract checks if current timestamp is later than DEADLINE */
        require(block.number > deadline);

        /* Contract picks the record in token DEPOSIT mapping with key equal to address argument (RECORD) */
        Record storage record = tokenDeposits[tokenWallet][who];

        /* Contract checks if RECORD has non-zero balance */
        require(record.balance > 0);

        uint256 balance = record.balance;

        /* Contract sets balance of RECORD to zero */
        record.balance = 0;

        /* Contract transfers tokens to the WALLET */
        ERC20Interface ERC20Token = ERC20Interface(tokenWallet);
        require(ERC20Token.transfer(owner, balance));

        TokenRefund(tokenWallet, who);
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}
