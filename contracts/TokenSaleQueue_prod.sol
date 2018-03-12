pragma solidity 0.4.19;

contract ERC20Interface {
    function transfer(address to, uint256 value) public returns (bool);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function balanceOf(address who) public view returns (uint256);
}

/* 1. Contract is initiated by storing sender as OWNER and with three arguments:
 * deadline : block.number which is also stored as DEADLINE
 * manager : address which is also stored as MANAGER. */
/* Only MANAGER is eglible to perform core functions like authorizing participants as confirmed investors and withdrawing their money as Token sale funds. */
contract TokenSaleQueueTest {
    using SafeMath for uint256;

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    /* 2. Contract has internal mapping DEPOSITS : Address -> (balance: uint, authorized: bool) representing balance of everyone whoever used deposit method */
    /* This is where balances of all participants stored. Additional flag of whether the participant is authorized investor is stored. This flag determines if the participant funds can be further processed by the contract manager (see 5., 6.) */
    struct Record {
        uint256 balance;
        bool authorized;
    }

    mapping(address => Record) public deposits;
    address public manager;
    address public recipient;
    address public recipientContainer;
    uint public deadline; /* blocks */
    uint public extendedTime; /* blocks */
    uint public maxTime; /* blocks */
    uint public finalTime;

    // Amount of wei raised
    uint256 public weiRaised;

    function balanceOf(address who) public view returns (uint256 balance) {
        return deposits[who].balance;
    }

    function isAuthorized(address who) public view returns (bool authorized) {
        return deposits[who].authorized;
    }

    function getDeadline() public view returns (uint) {
        return deadline;
    }

    function getManager() public view returns (address) {
        return manager;
    }

    event Whitelist(address who);
    event Deposit(address who, uint256 amount);
    event Withdrawal(address who);
    event Authorized(address who);
    event Process(address who);
    event Refund(address who);

    function TokenSaleQueueTest(address _owner, address _manager,  address _recipient, address _recipientContainer, uint _deadline, uint _extendedTime, uint _maxTime) public {
        require(_owner != address(0));
        require(_manager != address(0));
        require(_recipient != address(0));
        require(_recipientContainer != address(0));

        owner = _owner;
        manager = _manager;
        recipient = _recipient;
        recipientContainer = _recipientContainer;
        deadline = _deadline;
        extendedTime = _extendedTime;
	      maxTime = _maxTime;
	      finalTime = deadline + extendedTime;
    }

    modifier onlyManager() {
        require(msg.sender == manager);
        _;
    }

    /* Contract has map whitelist with address argument */
    mapping(address => bool) whitelist;

    /* Manager adds user in white list - operation that allows to use deposit function */
    /* Contract checks if sender is equal to manager */
    function addAddressInWhitelist(address who) public onlyManager {
        require(who != address(0));
        whitelist[who] = true;
        Whitelist(who);
    }

    function isInWhiteList(address who) public view returns (bool result) {
        return whitelist[who];
    }

    /* 3. Contract has payable method deposit */
    /* This is how participant puts his funds in the queue for further processing. Participant can later withdraw his funds unless they are processed by the contract owner (6.) */
    function deposit() public payable {
        /* Contract checks that method invocation attaches non-zero value. */
        require(msg.value > 0);

        /* Contract checks that user in whitelist */
        require(whitelist[msg.sender]);

        /* Contract checks that `finalTime` is not reached. If it is reached, it returns all funds to `sender` */
        if (block.number <= finalTime) {
        /* Contract adds value sent to the corresponding mapping stored in DEPOSIT using sender as a key */
            deposits[msg.sender].balance = deposits[msg.sender].balance.add(msg.value);
            weiRaised = weiRaised.add(msg.value);
            Deposit(msg.sender, msg.value);
        } else {
            msg.sender.transfer(msg.value);
            if (weiRaised != 0) {
                uint256 sendToRecepient = weiRaised;
                weiRaised = 0;
                recipient.transfer(sendToRecepient);
            }
        }
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

        weiRaised = weiRaised.sub(balance);
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

        /* Contract updates corresponding value in DEPOSITS mapping using address as the key and sets authorized = true */
        record.authorized = true;
        Authorized(who);
    }

    /* 6. Contract has method process */
    /* Sender does final confirmation that his money will be used in the Token Sale */
    function process() public {
        Record storage record = deposits[msg.sender];

        /* Contract checks if value of DEPOSITS with sender key has non-zero balance and authorized is set true */
        require(record.authorized);
        require(record.balance > 0);

        uint256 balance = record.balance;
        /* Contract sets balance of the sender entry to zero in the DEPOSITS */
        record.balance = 0;

        weiRaised = weiRaised.sub(balance);

        /* Contract transfers balance to the owner */
        owner.transfer(balance);

        Process(msg.sender);
    }

    /* Contract has internal mapping token DEPOSITS : Address -> (balance: uint, authorized: bool) representing token balance of everyone whoever used deposit method */
    /* This is where token balances of all participants stored. Additional flag of whether the participant is authorized investor is stored. This flag determines if the participant tokens can be further processed by the contract manager (see 11, 12) */
    mapping(address => mapping(address => uint256)) public tokenDeposits;

    /* White list of tokens */
    mapping(address => bool) public tokenWalletsWhitelist;
    address[] tokenWallets;
    mapping(address => uint256) public tokenRaised;
    bool reclaimTokenLaunch = false;

    function addTokenWalletInWhitelist(address tokenWallet) public onlyManager {
        require(tokenWallet != address(0));
        require(!tokenWalletsWhitelist[tokenWallet]);
        tokenWalletsWhitelist[tokenWallet] = true;
        tokenWallets.push(tokenWallet);
        TokenWhitelist(tokenWallet);
    }

    function tokenInWhiteList(address tokenWallet) public view returns (bool result) {
        return tokenWalletsWhitelist[tokenWallet];
    }

    function tokenBalanceOf(address tokenWallet, address who) public view returns (uint256 balance) {
        return tokenDeposits[tokenWallet][who];
    }

    event TokenWhitelist(address tokenWallet);
    event TokenDeposit(address tokenWallet, address who, uint256 amount);
    event TokenWithdrawal(address tokenWallet, address who);
    event TokenProcess(address tokenWallet, address who);
    event TokenRefund(address tokenWallet, address who);

    /* 9. Contract has method token deposit */
    /* This is how participant puts his funds in the queue for further processing. Participant can later withdraw his token unless they are processed by the conract owner (12.) */
    function tokenDeposit(address tokenWallet, uint amount) public {
        /* Contract checks that method invocation attaches non-zero value. */
        require(amount > 0);

        /* Contract checks that token wallet in whitelist */
        require(tokenWalletsWhitelist[tokenWallet]);

        /* Contract checks that user in whitelist */
        require(whitelist[msg.sender]);

        /* msg.sender initiate transferFrom function from ERC20 contract */
        ERC20Interface ERC20Token = ERC20Interface(tokenWallet);

        /* Contract checks that `finalTime` is not reached. */
        if (block.number <= finalTime) {
            require(ERC20Token.transferFrom(msg.sender, this, amount));

            /* Contract adds value sent to the corresponding mapping stored in token DEPOSIT using sender as a key */
            tokenDeposits[tokenWallet][msg.sender] = tokenDeposits[tokenWallet][msg.sender].add(amount);
            tokenRaised[tokenWallet] = tokenRaised[tokenWallet].add(amount);
            TokenDeposit(tokenWallet, msg.sender, amount);
        } else {
            reclaimTokens(tokenWallets);
        }
    }

    /* 10. Contract has method token withdraw without amount argument */
    /* Ability to withdraw funds for participant which he earlier had put in the contract using deposit function (9.) */
    function tokenWithdraw(address tokenWallet) public {
        /* Contract checks that balance of the sender in token DEPOSITS mapping is equal amount */
        require(tokenDeposits[tokenWallet][msg.sender] > 0);

        uint256 balance = tokenDeposits[tokenWallet][msg.sender];
        /* Contract sets the amount in corresponding record in DEPOSITS mapping to zero */
        tokenDeposits[tokenWallet][msg.sender] = 0;
        tokenRaised[tokenWallet] = tokenRaised[tokenWallet].sub(balance);

        /* Contract transfers amount to the sender from it's own balance */
        ERC20Interface ERC20Token = ERC20Interface(tokenWallet);
        require(ERC20Token.transfer(msg.sender, balance));

        TokenWithdrawal(tokenWallet, msg.sender);
    }

    /* 12. Contract has method token process */
    /* Sender does final confirmation that his tokens will be used in the Token Sale */
    function tokenProcess(address tokenWallet) public {
        /* Contract checks if value of token DEPOSITS with sender key has non-zero balance and authorized is set true */
        require(deposits[msg.sender].authorized);
        require(tokenDeposits[tokenWallet][msg.sender] > 0);

        uint256 balance = tokenDeposits[tokenWallet][msg.sender];
        /* Contract sets balance of the sender entry to zero in the DEPOSITS */
        tokenDeposits[tokenWallet][msg.sender] = 0;
        tokenRaised[tokenWallet] = tokenRaised[tokenWallet].sub(balance);

        /* Contract transfers tokens to the owner */
        ERC20Interface ERC20Token = ERC20Interface(tokenWallet);
        require(ERC20Token.transfer(owner, balance));

        TokenProcess(tokenWallet, msg.sender);
    }

    function() public payable {
        deposit();
    }

    function reclaimTokens(address[] tokens) internal {
        require(!reclaimTokenLaunch);

        // Transfer tokens to recipient
        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20Interface token = ERC20Interface(tokens[i]);
            uint256 balance = tokenRaised[tokens[i]];
            tokenRaised[tokens[i]] = 0;
            token.transfer(recipient, balance);
        }

        reclaimTokenLaunch = true;
    }

   function destroy(address[] tokens) public {
        require(block.number > finalTime);
        require(msg.sender == recipientContainer);

        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20Interface token = ERC20Interface(tokens[i]);
            uint256 balance = token.balanceOf(this);
            token.transfer(recipientContainer, balance);
        }

        // Transfer Eth to recipient and terminate contract
        selfdestruct(recipientContainer);
    }

    function changeExtendedTime(uint _extendedTime) public onlyOwner {
        require((deadline + extendedTime) < maxTime);
        extendedTime = _extendedTime;
        finalTime = deadline + extendedTime;
    }

    //for test only
    function changeDeadline(uint _deadline) public onlyOwner {
        deadline = _deadline;
    }

    //for test only
    function changeMaxTime(uint _maxTime) public onlyOwner {
        maxTime = _maxTime;
        finalTime = deadline + extendedTime;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }
}
